/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Stored Procedure di Discovery Automatica

  Queste procedure estraggono automaticamente i metadati dai database del DWH
  e dai job SQL Agent, e li inseriscono nel catalogo.
================================================================================
*/

-- ============================================================================
-- 1. DISCOVERY ENTITA' (tabelle e viste da un database)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_DiscoverEntities
    @DatabaseName       NVARCHAR(128),
    @AssetCode          VARCHAR(60),
    @DwhLayer           VARCHAR(20),
    @SourceSystemCode   VARCHAR(30) = 'DWH_ATHORA',
    @DryRun             BIT = 1          -- 1 = mostra solo cosa verrebbe inserito, 0 = inserisce
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DataAssetId INT;
    SELECT @DataAssetId = DataAssetId FROM dcat.DataAsset WHERE AssetCode = @AssetCode;

    -- Se l'asset non esiste, crearlo
    IF @DataAssetId IS NULL AND @DryRun = 0
    BEGIN
        INSERT INTO dcat.DataAsset (SourceSystemId, AssetCode, AssetName, AssetType,
            DatabaseName, DwhLayer, Description)
        SELECT SourceSystemId, @AssetCode, @DatabaseName, 'DATABASE', @DatabaseName, @DwhLayer,
               'Censito automaticamente dalla discovery il ' + CONVERT(VARCHAR(10), GETDATE(), 105)
        FROM dcat.SourceSystem WHERE SystemCode = @SourceSystemCode;
        SET @DataAssetId = SCOPE_IDENTITY();
        PRINT 'Asset creato: ' + @AssetCode + ' (ID: ' + CAST(@DataAssetId AS VARCHAR) + ')';
    END
    ELSE IF @DataAssetId IS NULL AND @DryRun = 1
    BEGIN
        PRINT '[DRY RUN] Asset ' + @AssetCode + ' non esiste e verrebbe creato.';
        RETURN;
    END

    -- Tabella temporanea per i risultati
    CREATE TABLE #DiscoveredTables (
        TABLE_SCHEMA NVARCHAR(128),
        TABLE_NAME   NVARCHAR(128),
        TABLE_TYPE   NVARCHAR(20),
        RowCnt       BIGINT,
        SizeMB       DECIMAL(18,2),
        EntityCode   AS (@AssetCode + '.' + TABLE_SCHEMA + '.' + TABLE_NAME),
        AlreadyExists BIT DEFAULT 0
    );

    -- Query dinamica sul database target
    DECLARE @SQL NVARCHAR(MAX) = N'
        SELECT
            t.TABLE_SCHEMA,
            t.TABLE_NAME,
            t.TABLE_TYPE,
            ISNULL((SELECT SUM(p.rows)
             FROM [' + @DatabaseName + N'].sys.partitions p
             INNER JOIN [' + @DatabaseName + N'].sys.tables st ON p.object_id = st.object_id
             INNER JOIN [' + @DatabaseName + N'].sys.schemas ss ON st.schema_id = ss.schema_id
             WHERE ss.name = t.TABLE_SCHEMA AND st.name = t.TABLE_NAME AND p.index_id IN (0,1)
            ), 0) AS RowCnt,
            ISNULL((SELECT CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18,2))
             FROM [' + @DatabaseName + N'].sys.tables st2
             INNER JOIN [' + @DatabaseName + N'].sys.schemas ss2 ON st2.schema_id = ss2.schema_id
             INNER JOIN [' + @DatabaseName + N'].sys.indexes i ON st2.object_id = i.object_id
             INNER JOIN [' + @DatabaseName + N'].sys.allocation_units a ON i.hobt_id = a.container_id
             WHERE ss2.name = t.TABLE_SCHEMA AND st2.name = t.TABLE_NAME
            ), 0) AS SizeMB
        FROM [' + @DatabaseName + N'].INFORMATION_SCHEMA.TABLES t
        WHERE t.TABLE_TYPE IN (''BASE TABLE'', ''VIEW'')
        ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME';

    INSERT INTO #DiscoveredTables (TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, RowCnt, SizeMB)
    EXEC sp_executesql @SQL;

    -- Marcare quelle già censite
    UPDATE dt
    SET AlreadyExists = 1
    FROM #DiscoveredTables dt
    WHERE EXISTS (
        SELECT 1 FROM dcat.DataEntity e
        WHERE e.DataAssetId = @DataAssetId AND e.EntityCode = dt.EntityCode
    );

    IF @DryRun = 1
    BEGIN
        PRINT '=== DRY RUN — Nessun dato verrà inserito ===';
        PRINT '';
        PRINT 'Database: ' + @DatabaseName;
        PRINT 'Asset: ' + @AssetCode + ' (ID: ' + ISNULL(CAST(@DataAssetId AS VARCHAR),'NULL') + ')';
        PRINT 'Layer: ' + ISNULL(@DwhLayer, 'N/A');
        PRINT '';

        SELECT
            EntityCode,
            TABLE_SCHEMA AS [Schema],
            TABLE_NAME AS [Tabella],
            TABLE_TYPE AS [Tipo],
            RowCnt AS [Righe],
            SizeMB AS [MB],
            CASE AlreadyExists WHEN 1 THEN 'GIA'' CENSITA' ELSE 'NUOVA - DA INSERIRE' END AS [Stato]
        FROM #DiscoveredTables
        ORDER BY AlreadyExists, TABLE_SCHEMA, TABLE_NAME;

        SELECT
            COUNT(*) AS TotaleOggetti,
            SUM(CASE WHEN AlreadyExists = 0 THEN 1 ELSE 0 END) AS NuoviDaInserire,
            SUM(CASE WHEN AlreadyExists = 1 THEN 1 ELSE 0 END) AS GiaCensiti
        FROM #DiscoveredTables;
    END
    ELSE
    BEGIN
        INSERT INTO dcat.DataEntity (DataAssetId, EntityCode, EntityName, EntityType,
            SchemaName, PhysicalName, RecordCount, SizeInMB, DwhLayer, GovernanceStatus,
            Description)
        SELECT
            @DataAssetId,
            EntityCode,
            TABLE_NAME,
            CASE TABLE_TYPE WHEN 'BASE TABLE' THEN 'TABLE' ELSE 'VIEW' END,
            TABLE_SCHEMA,
            TABLE_NAME,
            RowCnt,
            SizeMB,
            @DwhLayer,
            'DRAFT',
            'Censita automaticamente dalla discovery il ' + CONVERT(VARCHAR(10), GETDATE(), 105)
             + '. Completare: descrizione business, classificazione GDPR, criticità.'
        FROM #DiscoveredTables
        WHERE AlreadyExists = 0;

        PRINT 'Entità inserite: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
    END

    DROP TABLE #DiscoveredTables;
END;
GO

-- ============================================================================
-- 2. DISCOVERY ATTRIBUTI (colonne di tutte le entità di un asset)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_DiscoverAttributes
    @DatabaseName       NVARCHAR(128),
    @AssetCode          VARCHAR(60),
    @DryRun             BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #DiscoveredCols (
        TABLE_SCHEMA NVARCHAR(128), TABLE_NAME NVARCHAR(128),
        COLUMN_NAME NVARCHAR(128), DATA_TYPE NVARCHAR(50),
        MAX_LENGTH INT, NUM_PRECISION INT, NUM_SCALE INT,
        IsNullable BIT, OrdinalPosition INT, IsPK BIT,
        EntityCode AS (@AssetCode + '.' + TABLE_SCHEMA + '.' + TABLE_NAME)
    );

    DECLARE @SQL NVARCHAR(MAX) = N'
        SELECT
            c.TABLE_SCHEMA, c.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE,
            c.CHARACTER_MAXIMUM_LENGTH,
            c.NUMERIC_PRECISION, c.NUMERIC_SCALE,
            CASE c.IS_NULLABLE WHEN ''YES'' THEN 1 ELSE 0 END,
            c.ORDINAL_POSITION,
            CASE WHEN kcu.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END
        FROM [' + @DatabaseName + N'].INFORMATION_SCHEMA.COLUMNS c
        LEFT JOIN [' + @DatabaseName + N'].INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
            ON kcu.TABLE_SCHEMA = c.TABLE_SCHEMA
            AND kcu.TABLE_NAME = c.TABLE_NAME
            AND kcu.COLUMN_NAME = c.COLUMN_NAME
            AND kcu.CONSTRAINT_NAME LIKE ''PK_%''
        ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION';

    INSERT INTO #DiscoveredCols (TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE,
        MAX_LENGTH, NUM_PRECISION, NUM_SCALE, IsNullable, OrdinalPosition, IsPK)
    EXEC sp_executesql @SQL;

    IF @DryRun = 1
    BEGIN
        PRINT '=== DRY RUN — Nessun dato verrà inserito ===';

        -- Mostra solo le colonne nuove (non già censite)
        SELECT
            c.EntityCode,
            c.COLUMN_NAME AS [Colonna],
            c.DATA_TYPE AS [Tipo],
            c.MAX_LENGTH AS [Lunghezza],
            CASE c.IsPK WHEN 1 THEN 'PK' ELSE '' END AS [PK],
            CASE WHEN a.DataAttributeId IS NOT NULL THEN 'GIA'' CENSITA' ELSE 'NUOVA' END AS [Stato]
        FROM #DiscoveredCols c
        INNER JOIN dcat.DataEntity e ON e.EntityCode = c.EntityCode
        LEFT JOIN dcat.DataAttribute a ON a.DataEntityId = e.DataEntityId AND a.AttributeCode = c.COLUMN_NAME
        WHERE a.DataAttributeId IS NULL
        ORDER BY c.EntityCode, c.OrdinalPosition;

        SELECT COUNT(*) AS ColonneNuoveDaInserire
        FROM #DiscoveredCols c
        INNER JOIN dcat.DataEntity e ON e.EntityCode = c.EntityCode
        LEFT JOIN dcat.DataAttribute a ON a.DataEntityId = e.DataEntityId AND a.AttributeCode = c.COLUMN_NAME
        WHERE a.DataAttributeId IS NULL;
    END
    ELSE
    BEGIN
        INSERT INTO dcat.DataAttribute (DataEntityId, AttributeCode, AttributeName,
            PhysicalName, DataType, MaxLength, Precision, Scale, IsNullable, IsPrimaryKey)
        SELECT
            e.DataEntityId,
            c.COLUMN_NAME,
            c.COLUMN_NAME,
            c.COLUMN_NAME,
            c.DATA_TYPE,
            c.MAX_LENGTH,
            c.NUM_PRECISION,
            c.NUM_SCALE,
            c.IsNullable,
            c.IsPK
        FROM #DiscoveredCols c
        INNER JOIN dcat.DataEntity e ON e.EntityCode = c.EntityCode
        WHERE NOT EXISTS (
            SELECT 1 FROM dcat.DataAttribute a
            WHERE a.DataEntityId = e.DataEntityId AND a.AttributeCode = c.COLUMN_NAME
        );

        PRINT 'Attributi inseriti: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
    END

    DROP TABLE #DiscoveredCols;
END;
GO

-- ============================================================================
-- 3. DISCOVERY PIPELINE (job SQL Agent)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_DiscoverPipelines
    @DryRun BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @DryRun = 1
    BEGIN
        PRINT '=== DRY RUN — Nessun dato verrà inserito ===';

        SELECT
            j.name AS JobName,
            CASE j.enabled WHEN 1 THEN 'Attivo' ELSE 'Disattivo' END AS Stato,
            CASE
                WHEN s.freq_type = 4 THEN 'Giornaliero'
                WHEN s.freq_type = 8 THEN 'Settimanale'
                WHEN s.freq_type = 16 THEN 'Mensile'
                ELSE 'Altro/Non schedulato'
            END AS Frequenza,
            (SELECT COUNT(*) FROM msdb.dbo.sysjobsteps js WHERE js.job_id = j.job_id) AS NumStep,
            CASE WHEN p.PipelineId IS NOT NULL THEN 'GIA'' CENSITO' ELSE 'NUOVO' END AS StatoCatalogo
        FROM msdb.dbo.sysjobs j
        LEFT JOIN msdb.dbo.sysjobschedules jsch ON j.job_id = jsch.job_id
        LEFT JOIN msdb.dbo.sysschedules s ON jsch.schedule_id = s.schedule_id
        LEFT JOIN dcat.EtlPipeline p ON p.JobName = j.name
        ORDER BY CASE WHEN p.PipelineId IS NULL THEN 0 ELSE 1 END, j.name;

        SELECT
            COUNT(*) AS TotaleJob,
            SUM(CASE WHEN p.PipelineId IS NULL THEN 1 ELSE 0 END) AS NuoviDaInserire,
            SUM(CASE WHEN p.PipelineId IS NOT NULL THEN 1 ELSE 0 END) AS GiaCensiti
        FROM msdb.dbo.sysjobs j
        LEFT JOIN dcat.EtlPipeline p ON p.JobName = j.name;
    END
    ELSE
    BEGIN
        -- Inserire job
        INSERT INTO dcat.EtlPipeline (PipelineCode, PipelineName, PipelineType, JobName,
            ScheduleDescription, IsActive, Description)
        SELECT
            'JOB_' + REPLACE(REPLACE(REPLACE(j.name, ' ', '_'), '.', '_'), '-', '_'),
            j.name,
            'SQL_AGENT_JOB',
            j.name,
            CASE
                WHEN s.freq_type = 1 THEN 'Una tantum'
                WHEN s.freq_type = 4 THEN 'Giornaliero ogni ' + CAST(s.freq_interval AS VARCHAR) + ' gg'
                WHEN s.freq_type = 8 THEN 'Settimanale'
                WHEN s.freq_type = 16 THEN 'Mensile giorno ' + CAST(s.freq_interval AS VARCHAR)
                WHEN s.freq_type = 32 THEN 'Mensile relativo'
                WHEN s.freq_type = 64 THEN 'All''avvio SQL Agent'
                ELSE 'Non schedulato'
            END,
            j.enabled,
            'Censito automaticamente. COMPLETARE: descrizione, criticità, owner.'
        FROM msdb.dbo.sysjobs j
        LEFT JOIN msdb.dbo.sysjobschedules jsch ON j.job_id = jsch.job_id
        LEFT JOIN msdb.dbo.sysschedules s ON jsch.schedule_id = s.schedule_id
        WHERE NOT EXISTS (SELECT 1 FROM dcat.EtlPipeline p WHERE p.JobName = j.name);

        DECLARE @JobCount INT = @@ROWCOUNT;
        PRINT 'Pipeline inserite: ' + CAST(@JobCount AS VARCHAR);

        -- Inserire step
        INSERT INTO dcat.EtlPipelineStep (PipelineId, StepOrder, StepName, StepType, Description)
        SELECT
            p.PipelineId,
            js.step_id,
            js.step_name,
            CASE js.subsystem WHEN 'TSQL' THEN 'TRANSFORM' WHEN 'SSIS' THEN 'TRANSFORM'
                              WHEN 'CmdExec' THEN 'EXPORT' ELSE js.subsystem END,
            LEFT(js.command, 500)
        FROM msdb.dbo.sysjobsteps js
        INNER JOIN msdb.dbo.sysjobs j ON js.job_id = j.job_id
        INNER JOIN dcat.EtlPipeline p ON p.JobName = j.name
        WHERE NOT EXISTS (
            SELECT 1 FROM dcat.EtlPipelineStep s
            WHERE s.PipelineId = p.PipelineId AND s.StepOrder = js.step_id
        );

        PRINT 'Step inseriti: ' + CAST(@@ROWCOUNT AS VARCHAR);
    END
END;
GO

-- ============================================================================
-- 4. AUTO-CLASSIFICAZIONE GDPR (pattern matching sui nomi colonna)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_AutoClassifyGdpr
    @DryRun BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- Tabella temporanea con i risultati della classificazione
    CREATE TABLE #GdprClassification (
        DataAttributeId INT,
        AttributeCode   VARCHAR(200),
        EntityName      NVARCHAR(300),
        ProposedCategory VARCHAR(50),
        IsDirectId      BIT,
        IsSensitive     BIT,
        DlpLevel        VARCHAR(30),
        MatchRule       VARCHAR(100)
    );

    -- Regola 1: Codice fiscale / Partita IVA
    INSERT INTO #GdprClassification
    SELECT a.DataAttributeId, a.AttributeCode, e.EntityName,
           'IDENTIFICATIVO', 1, 0, 'CONFIDENTIAL', 'Pattern: CF/PARTITA_IVA'
    FROM dcat.DataAttribute a
    INNER JOIN dcat.DataEntity e ON a.DataEntityId = e.DataEntityId
    WHERE a.IsPersonalData = 0
      AND (a.AttributeCode LIKE '%COD%FISC%' OR a.AttributeCode LIKE '%CODICE_FISCALE%'
           OR a.AttributeCode LIKE '%PARTITA%IVA%' OR a.AttributeCode LIKE '%P_IVA%'
           OR a.AttributeCode LIKE '%CF' OR a.AttributeCode LIKE 'CF_%');

    -- Regola 2: Nome/Cognome
    INSERT INTO #GdprClassification
    SELECT a.DataAttributeId, a.AttributeCode, e.EntityName,
           'IDENTIFICATIVO', 1, 0, 'CONFIDENTIAL', 'Pattern: NOME/COGNOME'
    FROM dcat.DataAttribute a
    INNER JOIN dcat.DataEntity e ON a.DataEntityId = e.DataEntityId
    WHERE a.IsPersonalData = 0
      AND (a.AttributeCode LIKE '%COGNOME%' OR a.AttributeCode LIKE '%SURNAME%'
           OR (a.AttributeCode LIKE '%NOME%' AND a.AttributeCode NOT LIKE '%NOME_TAB%'
               AND a.AttributeCode NOT LIKE '%NOME_CAMP%' AND a.AttributeCode NOT LIKE '%NOME_COL%'
               AND a.AttributeCode NOT LIKE '%NOME_FILE%' AND a.AttributeCode NOT LIKE '%NOME_PROC%'))
      AND a.DataAttributeId NOT IN (SELECT DataAttributeId FROM #GdprClassification);

    -- Regola 3: Contatti
    INSERT INTO #GdprClassification
    SELECT a.DataAttributeId, a.AttributeCode, e.EntityName,
           'CONTATTO', 0, 0, 'CONFIDENTIAL', 'Pattern: INDIRIZZO/TEL/EMAIL'
    FROM dcat.DataAttribute a
    INNER JOIN dcat.DataEntity e ON a.DataEntityId = e.DataEntityId
    WHERE a.IsPersonalData = 0
      AND (a.AttributeCode LIKE '%INDIRIZZO%' OR a.AttributeCode LIKE '%ADDRESS%'
           OR a.AttributeCode LIKE '%TELEFON%' OR a.AttributeCode LIKE '%PHONE%'
           OR a.AttributeCode LIKE '%EMAIL%' OR a.AttributeCode LIKE '%E_MAIL%'
           OR a.AttributeCode LIKE '%PEC%' OR a.AttributeCode LIKE '%CAP%'
           OR a.AttributeCode LIKE '%CITTA%' OR a.AttributeCode LIKE '%LOCALITA%')
      AND a.DataAttributeId NOT IN (SELECT DataAttributeId FROM #GdprClassification);

    -- Regola 4: Dati bancari
    INSERT INTO #GdprClassification
    SELECT a.DataAttributeId, a.AttributeCode, e.EntityName,
           'FINANZIARIO', 1, 0, 'CONFIDENTIAL', 'Pattern: IBAN/CONTO'
    FROM dcat.DataAttribute a
    INNER JOIN dcat.DataEntity e ON a.DataEntityId = e.DataEntityId
    WHERE a.IsPersonalData = 0
      AND (a.AttributeCode LIKE '%IBAN%' OR a.AttributeCode LIKE '%CONTO%CORR%'
           OR a.AttributeCode LIKE '%BIC%' OR a.AttributeCode LIKE '%SWIFT%'
           OR a.AttributeCode LIKE '%ABI%' OR a.AttributeCode LIKE '%CAB%')
      AND a.DataAttributeId NOT IN (SELECT DataAttributeId FROM #GdprClassification);

    -- Regola 5: Dati sanitari — STRETTAMENTE RISERVATO
    INSERT INTO #GdprClassification
    SELECT a.DataAttributeId, a.AttributeCode, e.EntityName,
           'SANITARIO', 0, 1, 'STRICTLY_CONFIDENTIAL', 'Pattern: SANITARIO/MEDICO'
    FROM dcat.DataAttribute a
    INNER JOIN dcat.DataEntity e ON a.DataEntityId = e.DataEntityId
    WHERE a.IsPersonalData = 0
      AND (a.AttributeCode LIKE '%CAUSA_MORTE%' OR a.AttributeCode LIKE '%CAUSA_DECESSO%'
           OR a.AttributeCode LIKE '%PATOLOG%' OR a.AttributeCode LIKE '%DIAGNOS%'
           OR a.AttributeCode LIKE '%MEDIC%' OR a.AttributeCode LIKE '%SANITARI%'
           OR a.AttributeCode LIKE '%ICD%' OR a.AttributeCode LIKE '%QUESTION%MEDIC%'
           OR a.AttributeCode LIKE '%STATO_SALUTE%')
      AND a.DataAttributeId NOT IN (SELECT DataAttributeId FROM #GdprClassification);

    -- Regola 6: Data di nascita (identificatore indiretto)
    INSERT INTO #GdprClassification
    SELECT a.DataAttributeId, a.AttributeCode, e.EntityName,
           'IDENTIFICATIVO', 0, 0, 'CONFIDENTIAL', 'Pattern: DATA_NASCITA (indiretto)'
    FROM dcat.DataAttribute a
    INNER JOIN dcat.DataEntity e ON a.DataEntityId = e.DataEntityId
    WHERE a.IsPersonalData = 0
      AND (a.AttributeCode LIKE '%DATA%NASC%' OR a.AttributeCode LIKE '%DT%NASC%'
           OR a.AttributeCode LIKE '%BIRTH%DATE%' OR a.AttributeCode LIKE '%LUOGO%NASC%')
      AND a.DataAttributeId NOT IN (SELECT DataAttributeId FROM #GdprClassification);

    IF @DryRun = 1
    BEGIN
        PRINT '=== DRY RUN — Nessun dato verrà modificato ===';
        PRINT 'Verifica i risultati e poi riesegui con @DryRun = 0 per applicare.';
        PRINT '';

        SELECT * FROM #GdprClassification ORDER BY IsSensitive DESC, IsDirectId DESC, EntityName;

        SELECT
            ProposedCategory,
            COUNT(*) AS NumAttributi,
            MatchRule
        FROM #GdprClassification
        GROUP BY ProposedCategory, MatchRule
        ORDER BY COUNT(*) DESC;
    END
    ELSE
    BEGIN
        UPDATE a
        SET a.IsPersonalData = 1,
            a.GdprCategory = gc.ProposedCategory,
            a.IsDirectIdentifier = gc.IsDirectId,
            a.IsIndirectIdentifier = CASE WHEN gc.IsDirectId = 0 THEN 1 ELSE 0 END,
            a.IsSensitiveData = gc.IsSensitive,
            a.DlpClassification = gc.DlpLevel,
            a.ModifiedDate = SYSUTCDATETIME(),
            a.ModifiedBy = SUSER_SNAME()
        FROM dcat.DataAttribute a
        INNER JOIN #GdprClassification gc ON a.DataAttributeId = gc.DataAttributeId;

        PRINT 'Attributi classificati: ' + CAST(@@ROWCOUNT AS VARCHAR);

        -- Aggiornare i flag sulle entità che contengono dati personali
        UPDATE e
        SET e.ContainsPersonalData = 1,
            e.GdprRelevant = 1,
            e.ModifiedDate = SYSUTCDATETIME()
        FROM dcat.DataEntity e
        WHERE EXISTS (
            SELECT 1 FROM dcat.DataAttribute a
            WHERE a.DataEntityId = e.DataEntityId AND a.IsPersonalData = 1
        ) AND e.ContainsPersonalData = 0;

        -- Aggiornare le entità con dati sensibili
        UPDATE e
        SET e.ContainsSensitiveData = 1,
            e.ModifiedDate = SYSUTCDATETIME()
        FROM dcat.DataEntity e
        WHERE EXISTS (
            SELECT 1 FROM dcat.DataAttribute a
            WHERE a.DataEntityId = e.DataEntityId AND a.IsSensitiveData = 1
        ) AND e.ContainsSensitiveData = 0;

        PRINT 'Flag entità aggiornati.';
    END

    DROP TABLE #GdprClassification;
END;
GO

-- ============================================================================
-- 5. DRIFT DETECTION (tabelle non censite)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_DetectDrift
    @DatabaseName   NVARCHAR(128),
    @AssetCode      VARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DataAssetId INT;
    SELECT @DataAssetId = DataAssetId FROM dcat.DataAsset WHERE AssetCode = @AssetCode;

    IF @DataAssetId IS NULL
    BEGIN
        PRINT 'Asset ' + @AssetCode + ' non trovato nel catalogo.';
        RETURN;
    END

    -- Tabelle nel DB ma non nel catalogo
    DECLARE @SQL NVARCHAR(MAX) = N'
        SELECT t.TABLE_SCHEMA, t.TABLE_NAME, t.TABLE_TYPE, ''NON CENSITA'' AS Problema
        FROM [' + @DatabaseName + N'].INFORMATION_SCHEMA.TABLES t
        WHERE t.TABLE_TYPE IN (''BASE TABLE'',''VIEW'')
        AND NOT EXISTS (
            SELECT 1 FROM DataCatalog.dcat.DataEntity e
            WHERE e.DataAssetId = ' + CAST(@DataAssetId AS NVARCHAR) + N'
              AND e.EntityCode = ''' + @AssetCode + N'.'' + t.TABLE_SCHEMA + ''.'' + t.TABLE_NAME
        )
        UNION ALL
        -- Tabelle nel catalogo ma non più nel DB
        SELECT e.SchemaName, e.PhysicalName, ''CATALOGATA'' AS TABLE_TYPE, ''NON ESISTE PIU'' NEL DB'' AS Problema
        FROM DataCatalog.dcat.DataEntity e
        WHERE e.DataAssetId = ' + CAST(@DataAssetId AS NVARCHAR) + N'
          AND e.IsActive = 1
          AND e.EntityType IN (''TABLE'',''VIEW'')
          AND NOT EXISTS (
              SELECT 1 FROM [' + @DatabaseName + N'].INFORMATION_SCHEMA.TABLES t
              WHERE ''' + @AssetCode + N'.'' + t.TABLE_SCHEMA + ''.'' + t.TABLE_NAME = e.EntityCode
          )
        ORDER BY Problema, TABLE_SCHEMA, TABLE_NAME';

    EXEC sp_executesql @SQL;
END;
GO
