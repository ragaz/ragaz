# Manuale Operativo — Governed Data Catalog

## Athora Italia S.p.A. — Team Data Warehouse

**Destinatari:** Le 5 persone del team DWH che utilizzeranno e popoleranno il catalogo.
**Prerequisiti:** Accesso al server SQL Server del DWH con credenziali Windows (AD).

---

# PARTE 1 — INSTALLAZIONE E PRIMO AVVIO

## 1.1 Creazione del database

Collegarsi al server SQL Server del DWH con SSMS (SQL Server Management Studio)
usando Windows Authentication. Eseguire gli script **nell'ordine indicato** — l'ordine
è tassativo perché gli script successivi dipendono dalle tabelle create dai precedenti.

### Passo 1: Creare il database

```sql
-- Eseguire come sysadmin o dbcreator
CREATE DATABASE DataCatalog
ON PRIMARY (
    NAME = N'DataCatalog',
    FILENAME = N'D:\SQLData\DataCatalog.mdf',   -- adattare il percorso
    SIZE = 256MB,
    FILEGROWTH = 64MB
)
LOG ON (
    NAME = N'DataCatalog_log',
    FILENAME = N'D:\SQLLog\DataCatalog_log.ldf', -- adattare il percorso
    SIZE = 64MB,
    FILEGROWTH = 32MB
);
GO

-- Impostare il recovery model (SIMPLE è sufficiente per un catalogo)
ALTER DATABASE DataCatalog SET RECOVERY SIMPLE;
GO
```

> **NOTA SUL PERCORSO:** Sostituire `D:\SQLData` e `D:\SQLLog` con i percorsi
> effettivi dei file dati e log del vostro server. Verificare i percorsi delle
> directory con: `EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData'`

### Passo 2: Eseguire gli script di schema

Aprire ogni file in SSMS, assicurarsi di essere connessi al database `DataCatalog`,
ed eseguire in questa sequenza:

| # | File | Cosa crea | Tempo stimato |
|---|---|---|---|
| 1 | `database/schema/01_core_tables.sql` | Schema `dcat`, tabelle SourceSystem, DataAsset, DataEntity, DataAttribute, BusinessGlossary | 5 secondi |
| 2 | `database/schema/02_classification_tables.sql` | ClassificationLevel, tabelle GDPR, RegulatoryReport, CriticalityAssessment + FK | 5 secondi |
| 3 | `database/schema/03_lineage_tables.sql` | EtlPipeline, EntityLineage, AttributeLineage, DataQualityRule/Result | 5 secondi |
| 4 | `database/schema/04_governance_workflow_tables.sql` | CatalogUser, GovernanceRole, Workflow*, AuditLog, Notification, Tag | 5 secondi |

### Passo 3: Creare le viste

| # | File | Cosa crea |
|---|---|---|
| 5 | `database/views/01_catalog_views.sql` | 7 viste: CatalogBrowse, LineageGraph, GdprRegistry, RegulatoryImpact, DataQualityDashboard, PendingWorkflows, ImpactAnalysis |

### Passo 4: Creare le stored procedure

| # | File | Cosa crea |
|---|---|---|
| 6 | `database/stored-procedures/01_catalog_procedures.sql` | 7 SP: SearchCatalog, GetUpstreamLineage, GetDownstreamLineage, StartWorkflow, WorkflowAction, GdprPersonalDataReport, DashboardStats |

### Passo 5: Caricare i dati di seed

| # | File | Cosa crea |
|---|---|---|
| 7 | `database/seed/01_seed_classification.sql` | 4 livelli classificazione, 8 basi giuridiche GDPR, 10 finalità, 8 categorie interessati, 7 ruoli governance, 4 workflow, 21 tag, 8 report regolamentari |
| 8 | `database/seed/02_seed_source_systems.sql` | 9 sistemi sorgente, 12 data asset, 8 entità hub Level 1 |

### Verifica dell'installazione

Dopo aver eseguito tutti gli script, verificare con:

```sql
USE DataCatalog;
GO

-- Deve restituire 30+ tabelle
SELECT COUNT(*) AS NumTabelle
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dcat';

-- Deve restituire 9 sistemi
SELECT SystemCode, SystemName FROM dcat.SourceSystem ORDER BY SystemCode;

-- Deve restituire 4 livelli
SELECT LevelCode, LevelName, Color FROM dcat.ClassificationLevel ORDER BY LevelOrder;

-- Deve restituire 7 ruoli
SELECT RoleCode, RoleName FROM dcat.GovernanceRole;
```

Se tutti e 4 i risultati sono corretti, l'installazione è completata.

---

## 1.2 Registrazione degli utenti del team

Prima di popolare il catalogo, registrare le 5 persone del team DWH come utenti.
Ogni persona deve essere censita con il proprio login di dominio Windows.

```sql
USE DataCatalog;
GO

-- Sostituire con i dati reali di ogni membro del team
INSERT INTO dcat.CatalogUser (Username, DisplayName, Email, Department, JobTitle)
VALUES
('ATHORA\mario.rossi',   'Mario Rossi',   'mario.rossi@athora.it',   'DWH', 'DWH Manager'),
('ATHORA\luca.bianchi',  'Luca Bianchi',  'luca.bianchi@athora.it',  'DWH', 'ETL Developer'),
('ATHORA\anna.verdi',    'Anna Verdi',    'anna.verdi@athora.it',    'DWH', 'Data Analyst'),
('ATHORA\paolo.neri',    'Paolo Neri',    'paolo.neri@athora.it',    'DWH', 'ETL Developer'),
('ATHORA\sara.russo',    'Sara Russo',    'sara.russo@athora.it',    'DWH', 'Data Analyst');
GO
```

> **IMPORTANTE:** Il campo `Username` deve corrispondere esattamente al login Windows
> (dominio\username) perché l'applicazione web userà `SUSER_SNAME()` per identificare
> l'utente connesso.

### Assegnare i ruoli

```sql
-- Il responsabile DWH = ADMIN + DWH_TEAM
INSERT INTO dcat.UserRoleAssignment (UserId, RoleId, Scope)
SELECT u.UserId, r.RoleId, 'GLOBAL'
FROM dcat.CatalogUser u, dcat.GovernanceRole r
WHERE u.Username = 'ATHORA\mario.rossi'
  AND r.RoleCode IN ('ADMIN', 'DWH_TEAM');

-- Gli altri 4 membri = DWH_TEAM
INSERT INTO dcat.UserRoleAssignment (UserId, RoleId, Scope)
SELECT u.UserId, r.RoleId, 'GLOBAL'
FROM dcat.CatalogUser u, dcat.GovernanceRole r
WHERE u.Username IN ('ATHORA\luca.bianchi','ATHORA\anna.verdi','ATHORA\paolo.neri','ATHORA\sara.russo')
  AND r.RoleCode = 'DWH_TEAM';
GO
```

> In seguito, quando verranno nominati i Data Owner delle altre funzioni (Attuariato,
> Contabilità, Risk, Compliance), registrarli allo stesso modo e assegnare il ruolo
> `DATA_OWNER` con scope specifico.

---

## 1.3 Avvio dell'applicazione web

Dato che non avete un IIS disponibile, l'applicazione gira con Kestrel come servizio
Windows autonomo.

### Prerequisiti

1. **.NET 8.0 Runtime** — Scaricare e installare da:
   `https://dotnet.microsoft.com/download/dotnet/8.0` (sezione "ASP.NET Core Runtime",
   versione Windows x64 Hosting Bundle)

2. **Verificare l'installazione:**
   ```
   dotnet --list-runtimes
   ```
   Deve comparire `Microsoft.AspNetCore.App 8.0.x`

### Configurazione

Modificare il file `webapp/appsettings.json` con la connection string corretta:

```json
{
  "ConnectionStrings": {
    "DataCatalog": "Server=NOME_DEL_VOSTRO_SERVER;Database=DataCatalog;Trusted_Connection=True;TrustServerCertificate=True;"
  }
}
```

> **`Trusted_Connection=True`** significa che usa Windows Authentication.
> Non servono username/password SQL: l'identità dell'utente Windows connesso
> viene passata automaticamente.

### Compilazione e avvio

```
cd webapp
dotnet build
dotnet run --urls "http://0.0.0.0:5100"
```

L'applicazione sarà raggiungibile da qualsiasi PC in rete all'indirizzo:
`http://NOME_SERVER:5100`

### Registrare come servizio Windows (per avvio automatico)

Per fare in modo che l'applicazione si avvii automaticamente al riavvio del server:

```
dotnet publish -c Release -o C:\Services\DataCatalog

sc create "AthoraDataCatalog" ^
   binPath="C:\Services\DataCatalog\GovernedDataCatalog.exe --urls http://0.0.0.0:5100" ^
   start=auto ^
   DisplayName="Athora Governed Data Catalog"

sc start AthoraDataCatalog
```

### Verifica

Aprire un browser e navigare a `http://NOME_SERVER:5100`. Dovete vedere la Dashboard
con i conteggi dei sistemi, asset e entità caricati dal seed.

---

# PARTE 2 — POPOLAMENTO INIZIALE (CENSIMENTO)

Il popolamento si divide in 3 attività parallele che possono essere assegnate a
persone diverse del team:

| Attività | Chi la fa | Effort | Sezione |
|---|---|---|---|
| A. Discovery automatica metadati SQL Server | 1 persona | 2 giorni | 2.1 |
| B. Censimento pipeline ETL (job SQL Agent) | 1-2 persone | 5 giorni | 2.2 |
| C. Censimento file shadow IT | Tutto il team | 3 giorni | 2.3 |

---

## 2.1 Discovery automatica dei metadati SQL Server

Questo script estrae automaticamente tutte le tabelle e viste dei database del DWH
e le inserisce nel catalogo. **Eseguire questo script per primo** — farà il grosso
del lavoro di censimento.

### Passo 1: Identificare i database da censire

```sql
-- Elenco dei database presenti sul server (escludere quelli di sistema)
SELECT name FROM sys.databases
WHERE name NOT IN ('master','tempdb','model','msdb','DataCatalog')
  AND state_desc = 'ONLINE'
ORDER BY name;
```

Annotare i nomi dei database che fanno parte del DWH (staging, level 0, level 1,
eventuali datamart).

### Passo 2: Eseguire la discovery

Lo script seguente va eseguito **una volta per ogni database** da censire.
Modificare le variabili `@DatabaseName`, `@AssetCode` e `@DwhLayer` prima di ogni
esecuzione.

```sql
USE DataCatalog;
GO

-- ============================================================
-- CONFIGURARE QUESTE VARIABILI PER OGNI DATABASE DA CENSIRE
-- ============================================================
DECLARE @DatabaseName   NVARCHAR(128) = N'NomeDelDatabase';  -- es. 'DWH_Staging'
DECLARE @AssetCode      VARCHAR(60)   = 'DWH_STAGING';       -- deve corrispondere a un AssetCode esistente in dcat.DataAsset
DECLARE @DwhLayer       VARCHAR(20)   = 'STAGING';           -- 'STAGING','LEVEL0','LEVEL1','DATAMART'
DECLARE @SourceSystemCode VARCHAR(30) = 'DWH_ATHORA';        -- il sistema sorgente
-- ============================================================

DECLARE @DataAssetId INT;
SELECT @DataAssetId = DataAssetId FROM dcat.DataAsset WHERE AssetCode = @AssetCode;

-- Se l'asset non esiste ancora, crearlo
IF @DataAssetId IS NULL
BEGIN
    INSERT INTO dcat.DataAsset (SourceSystemId, AssetCode, AssetName, AssetType, DatabaseName, DwhLayer, Description)
    SELECT SourceSystemId, @AssetCode, @DatabaseName, 'DATABASE', @DatabaseName, @DwhLayer,
           'Database censito automaticamente dalla discovery.'
    FROM dcat.SourceSystem WHERE SystemCode = @SourceSystemCode;

    SET @DataAssetId = SCOPE_IDENTITY();
END

-- Estrarre tabelle e viste via query dinamica su INFORMATION_SCHEMA
DECLARE @SQL NVARCHAR(MAX) = N'
    SELECT
        t.TABLE_SCHEMA,
        t.TABLE_NAME,
        t.TABLE_TYPE,
        (SELECT SUM(p.rows) FROM [' + @DatabaseName + N'].sys.partitions p
         INNER JOIN [' + @DatabaseName + N'].sys.tables st ON p.object_id = st.object_id
         INNER JOIN [' + @DatabaseName + N'].sys.schemas ss ON st.schema_id = ss.schema_id
         WHERE ss.name = t.TABLE_SCHEMA AND st.name = t.TABLE_NAME AND p.index_id IN (0,1)
        ) AS RowCount
    FROM [' + @DatabaseName + N'].INFORMATION_SCHEMA.TABLES t
    WHERE t.TABLE_TYPE IN (''BASE TABLE'', ''VIEW'')
    ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME';

CREATE TABLE #TempTables (
    TABLE_SCHEMA NVARCHAR(128),
    TABLE_NAME NVARCHAR(128),
    TABLE_TYPE NVARCHAR(20),
    RowCount BIGINT
);
INSERT INTO #TempTables EXEC sp_executesql @SQL;

-- Inserire le entità nel catalogo (solo quelle non già presenti)
INSERT INTO dcat.DataEntity (DataAssetId, EntityCode, EntityName, EntityType, SchemaName,
    PhysicalName, RecordCount, DwhLayer, GovernanceStatus)
SELECT
    @DataAssetId,
    @AssetCode + '.' + t.TABLE_SCHEMA + '.' + t.TABLE_NAME,
    t.TABLE_NAME,
    CASE t.TABLE_TYPE WHEN 'BASE TABLE' THEN 'TABLE' ELSE 'VIEW' END,
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    t.RowCount,
    @DwhLayer,
    'DRAFT'
FROM #TempTables t
WHERE NOT EXISTS (
    SELECT 1 FROM dcat.DataEntity e
    WHERE e.DataAssetId = @DataAssetId
      AND e.EntityCode = @AssetCode + '.' + t.TABLE_SCHEMA + '.' + t.TABLE_NAME
);

PRINT 'Entità inserite: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DROP TABLE #TempTables;
GO
```

### Passo 3: Estrarre gli attributi (colonne) per ogni entità

```sql
USE DataCatalog;
GO

DECLARE @DatabaseName NVARCHAR(128) = N'NomeDelDatabase';
DECLARE @AssetCode    VARCHAR(60)   = 'DWH_STAGING';

DECLARE @SQL NVARCHAR(MAX) = N'
    SELECT
        c.TABLE_SCHEMA,
        c.TABLE_NAME,
        c.COLUMN_NAME,
        c.DATA_TYPE,
        c.CHARACTER_MAXIMUM_LENGTH,
        c.NUMERIC_PRECISION,
        c.NUMERIC_SCALE,
        CASE c.IS_NULLABLE WHEN ''YES'' THEN 1 ELSE 0 END AS IsNullable,
        c.ORDINAL_POSITION,
        CASE WHEN kcu.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END AS IsPK
    FROM [' + @DatabaseName + N'].INFORMATION_SCHEMA.COLUMNS c
    LEFT JOIN [' + @DatabaseName + N'].INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
        ON kcu.TABLE_SCHEMA = c.TABLE_SCHEMA
        AND kcu.TABLE_NAME = c.TABLE_NAME
        AND kcu.COLUMN_NAME = c.COLUMN_NAME
        AND kcu.CONSTRAINT_NAME LIKE ''PK_%''
    ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION';

CREATE TABLE #TempCols (
    TABLE_SCHEMA NVARCHAR(128), TABLE_NAME NVARCHAR(128),
    COLUMN_NAME NVARCHAR(128), DATA_TYPE NVARCHAR(50),
    MAX_LENGTH INT, PRECISION INT, SCALE INT,
    IsNullable BIT, OrdinalPosition INT, IsPK BIT
);
INSERT INTO #TempCols EXEC sp_executesql @SQL;

-- Inserire attributi per le entità già censite
INSERT INTO dcat.DataAttribute (DataEntityId, AttributeCode, AttributeName, PhysicalName,
    DataType, MaxLength, Precision, Scale, IsNullable, IsPrimaryKey)
SELECT
    e.DataEntityId,
    c.COLUMN_NAME,
    c.COLUMN_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.MAX_LENGTH,
    c.PRECISION,
    c.SCALE,
    c.IsNullable,
    c.IsPK
FROM #TempCols c
INNER JOIN dcat.DataEntity e
    ON e.EntityCode = @AssetCode + '.' + c.TABLE_SCHEMA + '.' + c.TABLE_NAME
WHERE NOT EXISTS (
    SELECT 1 FROM dcat.DataAttribute a
    WHERE a.DataEntityId = e.DataEntityId
      AND a.AttributeCode = c.COLUMN_NAME
);

PRINT 'Attributi inseriti: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DROP TABLE #TempCols;
GO
```

### Passo 4: Verifica della discovery

```sql
-- Riepilogo di cosa è stato censito
SELECT
    a.AssetCode,
    a.DwhLayer,
    COUNT(DISTINCT e.DataEntityId) AS Entita,
    COUNT(DISTINCT attr.DataAttributeId) AS Attributi
FROM dcat.DataAsset a
LEFT JOIN dcat.DataEntity e ON a.DataAssetId = e.DataAssetId
LEFT JOIN dcat.DataAttribute attr ON e.DataEntityId = attr.DataEntityId
GROUP BY a.AssetCode, a.DwhLayer
ORDER BY a.AssetCode;
```

### Ripetere per ogni database

Eseguire i passi 2 e 3 modificando le variabili per ogni database del DWH:

| Esecuzione | @DatabaseName | @AssetCode | @DwhLayer |
|---|---|---|---|
| 1 | *nome_db_staging* | DWH_STAGING | STAGING |
| 2 | *nome_db_level0* | DWH_LEVEL0 | LEVEL0 |
| 3 | *nome_db_level1* | DWH_LEVEL1 | LEVEL1 |
| 4 | *eventuali datamart* | DM_xxx | DATAMART |

---

## 2.2 Censimento pipeline ETL (job SQL Agent)

Questo script estrae automaticamente tutti i job SQL Agent e li inserisce nel catalogo
come pipeline ETL.

```sql
USE DataCatalog;
GO

-- Estrarre i job da msdb
INSERT INTO dcat.EtlPipeline (PipelineCode, PipelineName, PipelineType, JobName,
    ScheduleDescription, Description, IsActive)
SELECT
    'JOB_' + REPLACE(REPLACE(j.name, ' ', '_'), '.', '_'),
    j.name,
    'SQL_AGENT_JOB',
    j.name,
    CASE
        WHEN s.freq_type = 1 THEN 'Una tantum'
        WHEN s.freq_type = 4 THEN 'Giornaliero ogni ' + CAST(s.freq_interval AS VARCHAR) + ' giorno/i'
        WHEN s.freq_type = 8 THEN 'Settimanale'
        WHEN s.freq_type = 16 THEN 'Mensile il giorno ' + CAST(s.freq_interval AS VARCHAR)
        WHEN s.freq_type = 32 THEN 'Mensile relativo'
        WHEN s.freq_type = 64 THEN 'All''avvio di SQL Agent'
        WHEN s.freq_type = 128 THEN 'Quando il server è idle'
        ELSE 'Non schedulato'
    END,
    'Job censito automaticamente. Verificare descrizione e classificare la criticità.',
    j.enabled
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE NOT EXISTS (
    SELECT 1 FROM dcat.EtlPipeline p WHERE p.JobName = j.name
);

PRINT 'Pipeline inserite: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO
```

### Aggiungere gli step dei job

```sql
USE DataCatalog;
GO

INSERT INTO dcat.EtlPipelineStep (PipelineId, StepOrder, StepName, StepType, Description)
SELECT
    p.PipelineId,
    js.step_id,
    js.step_name,
    CASE js.subsystem
        WHEN 'TSQL' THEN 'TRANSFORM'
        WHEN 'SSIS' THEN 'TRANSFORM'
        WHEN 'CmdExec' THEN 'EXPORT'
        ELSE js.subsystem
    END,
    LEFT(js.command, 500)   -- primi 500 caratteri del comando T-SQL
FROM msdb.dbo.sysjobsteps js
INNER JOIN msdb.dbo.sysjobs j ON js.job_id = j.job_id
INNER JOIN dcat.EtlPipeline p ON p.JobName = j.name
WHERE NOT EXISTS (
    SELECT 1 FROM dcat.EtlPipelineStep s
    WHERE s.PipelineId = p.PipelineId AND s.StepOrder = js.step_id
);

PRINT 'Step inseriti: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO
```

### Dopo la discovery: lavoro manuale richiesto

La discovery automatica crea lo scheletro. Ora ogni membro del team deve completare
le informazioni **per i job di propria competenza**:

```sql
-- Esempio: aggiornare la criticità e la descrizione di un job
UPDATE dcat.EtlPipeline
SET CriticalityLevel = 'CRITICAL',
    Description = 'Assembla i dati polizze PASS + Smarthall e genera il file di input per MGAlfa.
                   Esegue controlli DQ di primo livello. Se fallisce, bloccare l''invio a MGAlfa.',
    MaxExecutionMinutes = 120,
    AlertOnFailure = 1,
    AlertRecipients = 'team-dwh@athora.it',
    OwnerId = (SELECT UserId FROM dcat.CatalogUser WHERE Username = 'ATHORA\mario.rossi')
WHERE PipelineCode = 'JOB_xxx_MGALFA_INPUT';
```

**Regola:** Ogni persona del team aggiorna le pipeline di cui è responsabile. La
suddivisione dei job va fatta nella prima riunione di kick-off.

---

## 2.3 Censimento file shadow IT

Questa è l'attività più delicata e va fatta manualmente con il coinvolgimento di
tutto il team. L'obiettivo è censire **tutti** i file Excel, CSV e Access che:

- Risiedono su cartelle di rete condivise
- Risiedono su PC locali degli utenti
- Alimentano direttamente il DWH o processi critici
- Contengono dati personali o finanziari

### Passo 1: Scansione cartelle di rete

Chiedere all'IT Infrastruttura l'elenco delle cartelle di rete utilizzate dal
team DWH e dalle funzioni business (Attuariato, Contabilità, Risk).

Per ogni cartella condivisa, eseguire dal prompt dei comandi del server:

```
dir "\\server\share\cartella" /S /B *.xls* *.csv *.mdb *.accdb > C:\temp\file_censimento.txt
```

### Passo 2: Registrare ogni file critico nel catalogo

Per ogni file identificato che è rilevante (alimenta processi, contiene dati personali),
inserirlo nel catalogo:

```sql
USE DataCatalog;
GO

-- Esempio: file Excel critico che alimenta il DWH
INSERT INTO dcat.DataEntity (
    DataAssetId, EntityCode, EntityName, EntityType,
    Description, BusinessDescription,
    LoadFrequency, CriticalityLevel,
    ContainsPersonalData, ContainsFinancialData, GdprRelevant,
    GovernanceStatus
)
VALUES (
    (SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'NET_EXCEL_SHARE'),
    'FILE_RETE_nome_del_file',
    'Nome descrittivo del file',
    'FILE_EXCEL',  -- oppure 'FILE_CSV', 'ACCESS_TABLE'
    'Percorso: \\server\share\cartella\nome_file.xlsx. Creato da [Nome persona]. Aggiornato [frequenza].',
    'Descrizione business: a cosa serve questo file, chi lo usa, cosa contiene.',
    'MONTHLY',    -- o 'DAILY', 'ON_DEMAND'
    'HIGH',       -- classificare la criticità
    1,            -- 1 se contiene dati personali, 0 altrimenti
    1,            -- 1 se contiene dati finanziari, 0 altrimenti
    1,            -- 1 se GDPR rilevante
    'DRAFT'
);
```

### Passo 3: Lista di controllo per ogni file censito

Per ogni file Excel/CSV/Access, compilare questa checklist:

| Domanda | Risposta da inserire nel catalogo |
|---|---|
| Dove si trova? (percorso completo) | Campo `Description` |
| Chi lo crea/aggiorna? | Assegnare come `DataOwnerId` |
| Con che frequenza viene aggiornato? | Campo `LoadFrequency` |
| Chi lo legge/usa? | Campo `BusinessDescription` |
| Alimenta direttamente il DWH? | Se sì → registrare nel lineage |
| Contiene codici fiscali, nomi, indirizzi? | `ContainsPersonalData = 1` |
| Contiene dati sanitari? | `ContainsSensitiveData = 1` → classificazione STRETT. RISERVATO |
| Contiene importi, premi, liquidazioni? | `ContainsFinancialData = 1` |
| Esiste un backup? | Se NO → segnalare come criticità massima |
| È su un PC locale? | Se sì → priorità di migrazione |

### Passo 4: Piano di rientro per i file critici

Dopo il censimento, ogni file viene classificato in una delle 3 categorie di azione:

| Categoria | Azione | Tempistica |
|---|---|---|
| **A — Critico senza backup** | Migrazione immediata su area protetta con backup | Entro 1 settimana |
| **B — Alimenta il DWH** | Migrazione su area protetta + integrazione nel lineage | Entro 1 mese |
| **C — Solo consultazione** | Migrazione su area protetta alla prima occasione | Entro 3 mesi |

---

# PARTE 3 — OPERATIVITÀ QUOTIDIANA

## 3.1 Arricchimento delle entità: descrizioni business

Una volta completata la discovery automatica, il catalogo contiene centinaia di entità
con solo il nome tecnico (es. `dbo.TBL_POLIZZE_PASS_STG`). L'obiettivo è aggiungere
a ogni entità una **descrizione business comprensibile anche da chi non conosce il DWH**.

### Come scrivere una buona descrizione business

| Cattiva | Buona |
|---|---|
| "Tabella delle polizze" | "Tutte le polizze vita emesse dal gestionale PASS, con dettaglio ramo/rischio e stato corrente. Aggiornata quotidianamente con snapshot completo." |
| "Premi" | "Raccolta premi vita consolidata da PASS e Smarthall, con dettaglio per titolo e sottotitolo contabile. Logica year-to-date, aggiornata mensilmente." |
| "Soggetti" | "Anagrafica unificata di tutti i soggetti coinvolti nei contratti vita: contraenti, assicurati, beneficiari, percipienti. Include codice fiscale, nome, cognome, data nascita, indirizzo." |

### Template SQL per aggiornamento massivo

```sql
-- Aggiornare una entità alla volta
UPDATE dcat.DataEntity
SET BusinessDescription = N'[Scrivere qui la descrizione business]',
    Description = N'[Scrivere qui la descrizione tecnica se mancante]',
    CriticalityLevel = 'HIGH',           -- CRITICAL, HIGH, MEDIUM, LOW
    ContainsPersonalData = 1,            -- 0 o 1
    ContainsSensitiveData = 0,           -- 0 o 1
    ContainsFinancialData = 1,           -- 0 o 1
    GdprRelevant = 1,                    -- 0 o 1
    LoadFrequency = 'DAILY',             -- DAILY, MONTHLY, ON_DEMAND
    LoadStrategy = 'INCREMENTAL',        -- FULL, INCREMENTAL, SNAPSHOT, DELTA, YTD
    ModifiedDate = SYSUTCDATETIME(),
    ModifiedBy = SUSER_SNAME()
WHERE EntityCode = 'xxx';
```

### Suddivisione del lavoro nel team

Suddividere le entità tra i 5 membri in base alla conoscenza dei flussi:

| Persona | Responsabilità | Entità da documentare |
|---|---|---|
| Persona 1 (Resp.) | Flussi MGAlfa, architettura generale | Entità Level 1 hub, output MGAlfa |
| Persona 2 | Flussi PASS | Staging e Level 0 da PASS, ODS |
| Persona 3 | Flussi Smarthall | Staging e Level 0 da Smarthall |
| Persona 4 | Flussi SAP, contabilità | Output SAP, premi, contabile |
| Persona 5 | Flussi regolamentari, BdI, IVASS | Entità per modelli IVASS, segnalazioni |

**Obiettivo: completare le descrizioni business entro 4 settimane** (circa 10-15 entità
a persona a settimana).

---

## 3.2 Classificazione GDPR degli attributi

Dopo aver documentato le entità, il passo successivo è classificare gli attributi
(colonne) che contengono dati personali.

### Attributi da cercare e come classificarli

| Nome colonna tipico | GdprCategory | IsPersonalData | IsDirectIdentifier | IsSensitiveData | DlpClassification |
|---|---|---|---|---|---|
| CODICE_FISCALE, CF, COD_FISC | IDENTIFICATIVO | 1 | 1 | 0 | CONFIDENTIAL |
| NOME, COGNOME, DENOMINAZIONE | IDENTIFICATIVO | 1 | 1 | 0 | CONFIDENTIAL |
| DATA_NASCITA, DT_NASCITA | IDENTIFICATIVO | 1 | 0 (indiretto) | 0 | CONFIDENTIAL |
| INDIRIZZO, VIA, CAP, CITTA | CONTATTO | 1 | 0 | 0 | CONFIDENTIAL |
| TELEFONO, EMAIL, PEC | CONTATTO | 1 | 0 | 0 | CONFIDENTIAL |
| IBAN, CONTO_CORRENTE | FINANZIARIO | 1 | 1 | 0 | CONFIDENTIAL |
| IMPORTO_PREMIO, IMPORTO_LIQUIDATO | FINANZIARIO | 0 | 0 | 0 | INTERNAL |
| CAUSA_MORTE, PATOLOGIA, COD_ICD | SANITARIO | 1 | 0 | **1** | **STRICTLY_CONFIDENTIAL** |
| QUESTIONARIO_MEDICO | SANITARIO | 1 | 0 | **1** | **STRICTLY_CONFIDENTIAL** |

### Script per classificazione massiva

```sql
-- Classificare tutti gli attributi il cui nome contiene pattern noti
-- ESEGUIRE CON ATTENZIONE: verificare i risultati prima di committare

-- Identificativi diretti
UPDATE dcat.DataAttribute
SET IsPersonalData = 1, IsDirectIdentifier = 1,
    GdprCategory = 'IDENTIFICATIVO', DlpClassification = 'CONFIDENTIAL'
WHERE (AttributeCode LIKE '%CODICE_FISCALE%' OR AttributeCode LIKE '%COD_FISC%'
       OR AttributeCode LIKE '%CF_%' OR AttributeCode LIKE '%PARTITA_IVA%')
  AND IsPersonalData = 0;

-- Nomi
UPDATE dcat.DataAttribute
SET IsPersonalData = 1, IsDirectIdentifier = 1,
    GdprCategory = 'IDENTIFICATIVO', DlpClassification = 'CONFIDENTIAL'
WHERE (AttributeCode LIKE '%COGNOME%' OR AttributeCode LIKE '%NOME%'
       OR AttributeCode LIKE '%DENOMINAZIONE%' OR AttributeCode LIKE '%RAGIONE_SOC%')
  AND AttributeCode NOT LIKE '%NOME_TABELLA%'    -- escludere falsi positivi
  AND AttributeCode NOT LIKE '%NOME_CAMPO%'
  AND IsPersonalData = 0;

-- Dati sanitari — STRETTAMENTE RISERVATO
UPDATE dcat.DataAttribute
SET IsPersonalData = 1, IsSensitiveData = 1,
    GdprCategory = 'SANITARIO', DlpClassification = 'STRICTLY_CONFIDENTIAL'
WHERE (AttributeCode LIKE '%CAUSA_MORTE%' OR AttributeCode LIKE '%PATOLOG%'
       OR AttributeCode LIKE '%DIAGNOS%' OR AttributeCode LIKE '%MEDIC%'
       OR AttributeCode LIKE '%SANITARI%' OR AttributeCode LIKE '%ICD%')
  AND IsPersonalData = 0;

-- Verificare i risultati
SELECT e.EntityName, a.AttributeCode, a.GdprCategory, a.DlpClassification,
       a.IsDirectIdentifier, a.IsSensitiveData
FROM dcat.DataAttribute a
INNER JOIN dcat.DataEntity e ON a.DataEntityId = e.DataEntityId
WHERE a.IsPersonalData = 1
ORDER BY a.IsSensitiveData DESC, a.IsDirectIdentifier DESC, e.EntityName;
```

> **ATTENZIONE:** La classificazione automatica per pattern è un punto di partenza.
> Ogni risultato va **verificato manualmente** perché i nomi delle colonne nel DWH
> non seguono una convenzione uniforme. Ci saranno falsi positivi e falsi negativi.

---

## 3.3 Documentazione del lineage

Il lineage risponde alla domanda: **da dove arriva questo dato e dove va?**

### Come registrare un flusso di lineage

Per ogni pipeline ETL che sposta dati da una tabella all'altra, creare un record
di lineage:

```sql
-- Esempio: dati polizze da Staging PASS → Level 0
INSERT INTO dcat.EntityLineage (SourceEntityId, TargetEntityId, PipelineId,
    LineageType, TransformationType, Description)
VALUES (
    (SELECT DataEntityId FROM dcat.DataEntity WHERE EntityCode = 'DWH_STAGING.dbo.STG_POLIZZE_PASS'),
    (SELECT DataEntityId FROM dcat.DataEntity WHERE EntityCode = 'DWH_LEVEL0.dbo.L0_POLIZZE_PASS'),
    (SELECT PipelineId FROM dcat.EtlPipeline WHERE PipelineCode = 'JOB_ETL_L0_POLIZZE_PASS'),
    'ETL',
    'DIRECT',       -- DIRECT, AGGREGATION, FILTER, JOIN, PIVOT, CALCULATION
    'Copia da staging a Level 0 con applicazione formati date e numerici.'
);
```

### Flussi prioritari da documentare (in ordine di criticità)

| # | Flusso | Da | A | Perché è prioritario |
|---|---|---|---|---|
| 1 | Input MGAlfa | Hub Polizze L1 + Hub Soggetti L1 | File input MGAlfa | Solvency II, audit IVASS |
| 2 | Modelli IVASS | Hub Polizze/Premi/Sinistri L1 | File IVASS 34/35/39/40/41 | Reporting regolamentare |
| 3 | Prima nota SAP | Hub Contabile L1 | File SAP | Contabilità, bilancio |
| 4 | Segnalazione BdI | Hub Soggetti + Movimenti L1 | File BdI esteri | Obbligo Banca d'Italia |
| 5 | PASS → Staging | Flussi PASS | Staging | Fondamentale per tutto il DWH |
| 6 | Smarthall → Staging | Flussi Smarthall | Staging | Fondamentale per tutto il DWH |
| 7 | Staging → Level 0 | Staging | Level 0 | Formattazione |
| 8 | Level 0 → Level 1 | Level 0 | Level 1 (Hub) | Armonizzazione, il più complesso |

### Visualizzare il lineage

Dopo aver inserito i record, il lineage è visibile:

- **Via web:** Aprire un'entità nel catalogo → cliccare "Visualizza Lineage"
- **Via SQL:**
  ```sql
  -- Upstream: da dove arrivano i dati per MGAlfa?
  EXEC dcat.sp_GetUpstreamLineage
      @DataEntityId = (SELECT DataEntityId FROM dcat.DataEntity WHERE EntityCode = 'MGALFA_POLIZZE_INPUT');

  -- Downstream: se cambio Hub Polizze, cosa si rompe?
  EXEC dcat.sp_GetDownstreamLineage
      @DataEntityId = (SELECT DataEntityId FROM dcat.DataEntity WHERE EntityCode = 'HUB_POLIZZE');
  ```

---

## 3.4 Compilazione della matrice di criticità

Per ogni entità del livello Level 1 (Hub) e per ogni output critico, compilare
la valutazione di criticità:

```sql
INSERT INTO dcat.CriticalityAssessment (DataEntityId,
    RegulatoryImpact, OperationalImpact, FinancialImpact,
    ReputationalImpact, GdprImpact, DataLossImpact,
    AssessedBy, Justification)
VALUES (
    (SELECT DataEntityId FROM dcat.DataEntity WHERE EntityCode = 'HUB_POLIZZE'),
    5,  -- Regolamentare: alimenta IVASS e Solvency
    5,  -- Operativo: senza polizze si ferma tutto
    4,  -- Finanziario: errore nei premi = errore di bilancio
    4,  -- Reputazionale: dato visibile a IVASS
    4,  -- GDPR: contiene dati personali di tutti i contraenti
    3,  -- Data Loss: ricostruibile da PASS+Smarthall ma con effort
    'Mario Rossi',
    'Hub principale polizze, alimenta tutti i report regolamentari e il motore attuariale.'
);
```

> Usare come riferimento la tabella nella documentazione `04_MATRICE_CRITICITA.md`.
> In caso di dubbio sulla valutazione, **scegliere sempre il valore più alto** (principio
> di prudenza).

---

## 3.5 Collegare entità ai report regolamentari

Per ogni modello IVASS e report regolamentare, indicare quali entità lo alimentano:

```sql
-- Esempio: Hub Polizze alimenta il Modello IVASS 34
INSERT INTO dcat.ReportEntityMap (ReportId, DataEntityId, ContributionType)
VALUES (
    (SELECT ReportId FROM dcat.RegulatoryReport WHERE ReportCode = 'IVASS_34'),
    (SELECT DataEntityId FROM dcat.DataEntity WHERE EntityCode = 'HUB_POLIZZE'),
    'PRIMARY_SOURCE'
);
```

Ripetere per ogni coppia report-entità. Questo è fondamentale per l'audit IVASS:
permette di rispondere in tempo reale alla domanda **"da quali dati sorgente viene
prodotto il Modello 34?"**.

---

# PARTE 4 — MANUTENZIONE E PROCESSI RICORRENTI

## 4.1 Quando si aggiunge una nuova tabella al DWH

Ogni volta che viene creata una nuova tabella o vista nel DWH:

1. Registrare l'entità nel catalogo (`INSERT INTO dcat.DataEntity`)
2. Estrarre gli attributi (usare lo script di discovery del punto 2.1, passo 3)
3. Scrivere la descrizione business
4. Classificare gli attributi GDPR
5. Registrare il lineage (da dove arriva, dove va)
6. Avviare il workflow approvativo:
   ```sql
   EXEC dcat.sp_StartWorkflow
       @WorkflowCode = 'WF_NEW_ENTITY',
       @TargetEntityType = 'DATA_ENTITY',
       @TargetEntityId = <id della nuova entità>,
       @RequestedByUserId = <il tuo UserId>,
       @ChangeDescription = 'Nuova tabella xxx per il flusso yyy';
   ```

## 4.2 Quando si modifica una pipeline ETL

1. Aggiornare la descrizione della pipeline nel catalogo
2. Verificare se cambia il lineage e aggiornarlo
3. Se si aggiungono/rimuovono tabelle, aggiornare le entità
4. Aggiornare i controlli di data quality censiti

## 4.3 Review periodiche

| Attività | Frequenza | Chi |
|---|---|---|
| Verifica che nuove tabelle siano censite | Mensile | Team DWH |
| Review classificazione DLP | Semestrale | Data Owner + DPO |
| Review registro trattamenti GDPR | Annuale | DPO + Compliance |
| Aggiornamento conteggio record | Trimestrale (automatizzabile) | Script SQL |
| Verifica workflow pendenti non evasi | Settimanale | Responsabile DWH |

### Script per aggiornamento automatico conteggio record

```sql
-- Eseguire trimestralmente o schedulare come job SQL Agent
DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql = @sql +
    'UPDATE dcat.DataEntity SET RecordCount = (SELECT COUNT(*) FROM ' +
    QUOTENAME(a.DatabaseName) + '.' + QUOTENAME(e.SchemaName) + '.' + QUOTENAME(e.PhysicalName) +
    '), ModifiedDate = SYSUTCDATETIME() WHERE DataEntityId = ' + CAST(e.DataEntityId AS VARCHAR) + ';' + CHAR(13)
FROM dcat.DataEntity e
INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
WHERE e.EntityType IN ('TABLE','VIEW')
  AND e.IsActive = 1
  AND a.DatabaseName IS NOT NULL
  AND e.SchemaName IS NOT NULL
  AND e.PhysicalName IS NOT NULL;

EXEC sp_executesql @sql;
PRINT 'Conteggi aggiornati.';
GO
```

## 4.4 Identificare tabelle non censite (drift detection)

Schedulare mensilmente questo controllo per verificare che non ci siano nuove tabelle
nel DWH non ancora registrate nel catalogo:

```sql
-- Trovare tabelle nel DWH che non sono nel catalogo
-- Adattare @DatabaseName per ogni database del DWH

DECLARE @DatabaseName NVARCHAR(128) = N'NomeDelDatabase';
DECLARE @AssetCode    VARCHAR(60)   = 'DWH_LEVEL1';

DECLARE @SQL NVARCHAR(MAX) = N'
    SELECT t.TABLE_SCHEMA, t.TABLE_NAME, t.TABLE_TYPE
    FROM [' + @DatabaseName + N'].INFORMATION_SCHEMA.TABLES t
    WHERE t.TABLE_TYPE IN (''BASE TABLE'',''VIEW'')
    AND NOT EXISTS (
        SELECT 1 FROM DataCatalog.dcat.DataEntity e
        WHERE e.EntityCode = ''' + @AssetCode + N'.'' + t.TABLE_SCHEMA + ''.'' + t.TABLE_NAME
    )
    ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME';

EXEC sp_executesql @SQL;
```

Se il risultato non è vuoto, ci sono tabelle da censire.

---

# PARTE 5 — RIFERIMENTO RAPIDO

## 5.1 Query più utilizzate

```sql
-- Cercare nel catalogo
EXEC dcat.sp_SearchCatalog @SearchTerm = 'polizze';

-- Cercare solo entità GDPR critiche
EXEC dcat.sp_SearchCatalog @SearchTerm = '', @GdprOnly = 1, @CriticalOnly = 1;

-- Lineage upstream (da dove arriva un dato)
EXEC dcat.sp_GetUpstreamLineage @DataEntityId = 1;

-- Lineage downstream (chi usa questo dato)
EXEC dcat.sp_GetDownstreamLineage @DataEntityId = 1;

-- Report dati personali per sistema
EXEC dcat.sp_GdprPersonalDataReport @SourceSystemCode = 'PASS_RGI';

-- Dashboard statistiche
EXEC dcat.sp_DashboardStats;

-- Workflow in attesa di approvazione
SELECT * FROM dcat.vw_PendingWorkflows;

-- Impact analysis: se Hub Polizze ha problemi, cosa è impattato?
SELECT * FROM dcat.vw_ImpactAnalysis WHERE RootEntityCode = 'HUB_POLIZZE';
```

## 5.2 Codici di riferimento

### Livelli di classificazione (DLP)
| Codice | Uso |
|---|---|
| `PUBLIC` | Dati pubblicabili |
| `INTERNAL` | Solo uso interno |
| `CONFIDENTIAL` | Dati personali/finanziari |
| `STRICTLY_CONFIDENTIAL` | Dati sanitari/giudiziari |

### Criticità
| Codice | Score | Significato |
|---|---|---|
| `CRITICAL` | >= 24/30 | Monitoraggio continuo |
| `HIGH` | >= 18/30 | Controlli bloccanti |
| `MEDIUM` | >= 12/30 | Controlli standard |
| `LOW` | < 12/30 | Controlli base |

### Layer DWH
| Codice | Significato |
|---|---|
| `STAGING` | Importazione grezza |
| `LEVEL0` | Formattazione uniforme |
| `LEVEL1` | Armonizzazione (Hub) |
| `DATAMART` | Aggregazioni per report |

### Stati governance
| Codice | Significato |
|---|---|
| `DRAFT` | Appena censito, da completare |
| `IN_REVIEW` | In approvazione |
| `APPROVED` | Approvato e governato |
| `DEPRECATED` | Dismesso |

---

*Fine del manuale operativo. Per domande o problemi: team-dwh@athora.it*
