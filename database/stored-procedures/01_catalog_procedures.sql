/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Stored Procedures - Operazioni principali del catalogo
================================================================================
*/

-- ============================================================================
-- 1. RICERCA NEL CATALOGO (full-text like)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_SearchCatalog
    @SearchTerm     NVARCHAR(200),
    @EntityType     VARCHAR(50)   = NULL,
    @SystemCode     VARCHAR(30)   = NULL,
    @DwhLayer       VARCHAR(20)   = NULL,
    @Classification VARCHAR(30)   = NULL,
    @GdprOnly       BIT           = 0,
    @CriticalOnly   BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        cb.*
    FROM dcat.vw_CatalogBrowse cb
    WHERE (
        cb.EntityName       LIKE '%' + @SearchTerm + '%'
        OR cb.EntityCode    LIKE '%' + @SearchTerm + '%'
        OR cb.EntityDescription LIKE '%' + @SearchTerm + '%'
        OR cb.BusinessDescription LIKE '%' + @SearchTerm + '%'
        OR cb.AssetName     LIKE '%' + @SearchTerm + '%'
        OR cb.SystemName    LIKE '%' + @SearchTerm + '%'
    )
    AND (@EntityType IS NULL OR cb.EntityType = @EntityType)
    AND (@SystemCode IS NULL OR cb.SystemCode = @SystemCode)
    AND (@DwhLayer IS NULL OR cb.DwhLayer = @DwhLayer)
    AND (@Classification IS NULL OR cb.ClassificationCode = @Classification)
    AND (@GdprOnly = 0 OR cb.GdprRelevant = 1)
    AND (@CriticalOnly = 0 OR cb.CriticalityLevel IN ('CRITICAL', 'HIGH'))
    ORDER BY
        CASE cb.CriticalityLevel
            WHEN 'CRITICAL' THEN 1
            WHEN 'HIGH' THEN 2
            WHEN 'MEDIUM' THEN 3
            WHEN 'LOW' THEN 4
            ELSE 5
        END,
        cb.ClassificationOrder DESC,
        cb.EntityName;
END;
GO

-- ============================================================================
-- 2. LINEAGE UPSTREAM (da dove arriva un dato)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_GetUpstreamLineage
    @DataEntityId   INT,
    @MaxDepth       INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Upstream AS (
        SELECT
            el.TargetEntityId   AS EntityId,
            el.SourceEntityId   AS UpstreamEntityId,
            1                   AS Depth,
            el.PipelineId,
            el.LineageType,
            el.TransformationType
        FROM dcat.EntityLineage el
        WHERE el.TargetEntityId = @DataEntityId AND el.IsActive = 1

        UNION ALL

        SELECT
            u.UpstreamEntityId  AS EntityId,
            el2.SourceEntityId  AS UpstreamEntityId,
            u.Depth + 1,
            el2.PipelineId,
            el2.LineageType,
            el2.TransformationType
        FROM Upstream u
        INNER JOIN dcat.EntityLineage el2 ON u.UpstreamEntityId = el2.TargetEntityId
        WHERE el2.IsActive = 1 AND u.Depth < @MaxDepth
    )
    SELECT DISTINCT
        u.Depth,
        u.LineageType,
        u.TransformationType,
        e.DataEntityId,
        e.EntityCode,
        e.EntityName,
        e.EntityType,
        e.CriticalityLevel,
        a.AssetName,
        s.SystemCode,
        s.SystemName,
        p.PipelineCode,
        p.PipelineName
    FROM Upstream u
    INNER JOIN dcat.DataEntity e ON u.UpstreamEntityId = e.DataEntityId
    INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
    INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
    LEFT JOIN dcat.EtlPipeline p ON u.PipelineId = p.PipelineId
    ORDER BY u.Depth, s.SystemCode, e.EntityCode;
END;
GO

-- ============================================================================
-- 3. LINEAGE DOWNSTREAM (chi usa questo dato)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_GetDownstreamLineage
    @DataEntityId   INT,
    @MaxDepth       INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Downstream AS (
        SELECT
            el.SourceEntityId   AS EntityId,
            el.TargetEntityId   AS DownstreamEntityId,
            1                   AS Depth,
            el.PipelineId,
            el.LineageType,
            el.TransformationType
        FROM dcat.EntityLineage el
        WHERE el.SourceEntityId = @DataEntityId AND el.IsActive = 1

        UNION ALL

        SELECT
            d.DownstreamEntityId AS EntityId,
            el2.TargetEntityId   AS DownstreamEntityId,
            d.Depth + 1,
            el2.PipelineId,
            el2.LineageType,
            el2.TransformationType
        FROM Downstream d
        INNER JOIN dcat.EntityLineage el2 ON d.DownstreamEntityId = el2.SourceEntityId
        WHERE el2.IsActive = 1 AND d.Depth < @MaxDepth
    )
    SELECT DISTINCT
        d.Depth,
        d.LineageType,
        d.TransformationType,
        e.DataEntityId,
        e.EntityCode,
        e.EntityName,
        e.EntityType,
        e.CriticalityLevel,
        a.AssetName,
        s.SystemCode,
        s.SystemName,
        p.PipelineCode,
        p.PipelineName,
        -- Report regolamentari impattati
        STUFF((
            SELECT ', ' + rr.ReportCode
            FROM dcat.ReportEntityMap rem
            INNER JOIN dcat.RegulatoryReport rr ON rem.ReportId = rr.ReportId
            WHERE rem.DataEntityId = e.DataEntityId
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS ImpactedReports
    FROM Downstream d
    INNER JOIN dcat.DataEntity e ON d.DownstreamEntityId = e.DataEntityId
    INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
    INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
    LEFT JOIN dcat.EtlPipeline p ON d.PipelineId = p.PipelineId
    ORDER BY d.Depth, s.SystemCode, e.EntityCode;
END;
GO

-- ============================================================================
-- 4. AVVIO WORKFLOW APPROVATIVO
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_StartWorkflow
    @WorkflowCode       VARCHAR(50),
    @TargetEntityType   VARCHAR(50),
    @TargetEntityId     INT,
    @RequestedByUserId  INT,
    @RequestNotes       NVARCHAR(MAX) = NULL,
    @ChangeDescription  NVARCHAR(MAX) = NULL,
    @NewValues          NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @WorkflowId INT, @FirstStepId INT, @InstanceId INT;

        SELECT @WorkflowId = WorkflowId
        FROM dcat.WorkflowDefinition
        WHERE WorkflowCode = @WorkflowCode AND IsActive = 1;

        IF @WorkflowId IS NULL
            THROW 50001, 'Workflow non trovato o non attivo.', 1;

        SELECT TOP 1 @FirstStepId = WorkflowStepId
        FROM dcat.WorkflowStep
        WHERE WorkflowId = @WorkflowId AND IsActive = 1
        ORDER BY StepOrder;

        -- Crea istanza
        INSERT INTO dcat.WorkflowInstance (WorkflowId, TargetEntityType, TargetEntityId,
            CurrentStepId, Status, RequestedBy, RequestNotes, ChangeDescription, NewValues)
        VALUES (@WorkflowId, @TargetEntityType, @TargetEntityId,
            @FirstStepId, 'PENDING', @RequestedByUserId, @RequestNotes, @ChangeDescription, @NewValues);

        SET @InstanceId = SCOPE_IDENTITY();

        -- Notifica approvatore del primo step
        DECLARE @ApproverRoleId INT, @ApproverUserId INT, @StepName NVARCHAR(200);
        SELECT @ApproverRoleId = ApproverRoleId, @ApproverUserId = ApproverUserId, @StepName = StepName
        FROM dcat.WorkflowStep WHERE WorkflowStepId = @FirstStepId;

        -- Se approvatore specifico
        IF @ApproverUserId IS NOT NULL
        BEGIN
            INSERT INTO dcat.Notification (UserId, Title, Message, NotificationType, RelatedEntityType, RelatedEntityId)
            VALUES (@ApproverUserId,
                    N'Approvazione richiesta: ' + @StepName,
                    @ChangeDescription,
                    'WORKFLOW', @TargetEntityType, @InstanceId);
        END
        -- Se ruolo, notifica tutti gli utenti con quel ruolo
        ELSE IF @ApproverRoleId IS NOT NULL
        BEGIN
            INSERT INTO dcat.Notification (UserId, Title, Message, NotificationType, RelatedEntityType, RelatedEntityId)
            SELECT ura.UserId,
                   N'Approvazione richiesta: ' + @StepName,
                   @ChangeDescription,
                   'WORKFLOW', @TargetEntityType, @InstanceId
            FROM dcat.UserRoleAssignment ura
            WHERE ura.RoleId = @ApproverRoleId AND ura.IsActive = 1;
        END

        -- Audit log
        INSERT INTO dcat.AuditLog (ActionType, EntityType, EntityId, UserId, NewValues, Notes)
        VALUES ('INSERT', 'WorkflowInstance', @InstanceId, @RequestedByUserId, @NewValues,
                'Workflow avviato: ' + @WorkflowCode);

        COMMIT TRANSACTION;
        SELECT @InstanceId AS InstanceId, 'PENDING' AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- 5. AZIONE SU WORKFLOW (approva/rigetta)
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_WorkflowAction
    @InstanceId     INT,
    @ActionByUserId INT,
    @ActionType     VARCHAR(20),  -- 'APPROVE','REJECT'
    @Notes          NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStepId INT, @WorkflowId INT, @Status VARCHAR(30);
        DECLARE @NextStepId INT, @TargetEntityType VARCHAR(50), @TargetEntityId INT;

        SELECT @CurrentStepId = CurrentStepId, @WorkflowId = WorkflowId,
               @Status = Status, @TargetEntityType = TargetEntityType,
               @TargetEntityId = TargetEntityId
        FROM dcat.WorkflowInstance
        WHERE InstanceId = @InstanceId;

        IF @Status NOT IN ('PENDING', 'IN_PROGRESS')
            THROW 50002, 'Il workflow non è in stato modificabile.', 1;

        -- Registra azione
        INSERT INTO dcat.WorkflowAction (InstanceId, WorkflowStepId, ActionType, ActionBy, Notes)
        VALUES (@InstanceId, @CurrentStepId, @ActionType, @ActionByUserId, @Notes);

        IF @ActionType = 'REJECT'
        BEGIN
            UPDATE dcat.WorkflowInstance
            SET Status = 'REJECTED', ResolvedDate = SYSUTCDATETIME(),
                ResolvedBy = @ActionByUserId, ResolutionNotes = @Notes
            WHERE InstanceId = @InstanceId;
        END
        ELSE IF @ActionType = 'APPROVE'
        BEGIN
            -- Cerca lo step successivo
            DECLARE @CurrentOrder INT;
            SELECT @CurrentOrder = StepOrder FROM dcat.WorkflowStep WHERE WorkflowStepId = @CurrentStepId;

            SELECT TOP 1 @NextStepId = WorkflowStepId
            FROM dcat.WorkflowStep
            WHERE WorkflowId = @WorkflowId AND StepOrder > @CurrentOrder AND IsActive = 1
            ORDER BY StepOrder;

            IF @NextStepId IS NULL
            BEGIN
                -- Ultimo step -> workflow completato
                UPDATE dcat.WorkflowInstance
                SET Status = 'APPROVED', CurrentStepId = NULL,
                    ResolvedDate = SYSUTCDATETIME(), ResolvedBy = @ActionByUserId,
                    ResolutionNotes = @Notes
                WHERE InstanceId = @InstanceId;

                -- Aggiorna lo stato di governance dell'entità target
                IF @TargetEntityType = 'DATA_ENTITY'
                    UPDATE dcat.DataEntity
                    SET GovernanceStatus = 'APPROVED',
                        ApprovedDate = SYSUTCDATETIME(),
                        ApprovedBy = (SELECT Username FROM dcat.CatalogUser WHERE UserId = @ActionByUserId)
                    WHERE DataEntityId = @TargetEntityId;
            END
            ELSE
            BEGIN
                -- Avanza al prossimo step
                UPDATE dcat.WorkflowInstance
                SET CurrentStepId = @NextStepId, Status = 'IN_PROGRESS'
                WHERE InstanceId = @InstanceId;

                -- Notifica prossimo approvatore
                DECLARE @NextApproverRoleId INT, @NextApproverUserId INT, @NextStepName NVARCHAR(200);
                SELECT @NextApproverRoleId = ApproverRoleId, @NextApproverUserId = ApproverUserId,
                       @NextStepName = StepName
                FROM dcat.WorkflowStep WHERE WorkflowStepId = @NextStepId;

                IF @NextApproverUserId IS NOT NULL
                    INSERT INTO dcat.Notification (UserId, Title, Message, NotificationType, RelatedEntityType, RelatedEntityId)
                    VALUES (@NextApproverUserId, N'Approvazione richiesta: ' + @NextStepName, @Notes, 'WORKFLOW', @TargetEntityType, @InstanceId);
                ELSE IF @NextApproverRoleId IS NOT NULL
                    INSERT INTO dcat.Notification (UserId, Title, Message, NotificationType, RelatedEntityType, RelatedEntityId)
                    SELECT ura.UserId, N'Approvazione richiesta: ' + @NextStepName, @Notes, 'WORKFLOW', @TargetEntityType, @InstanceId
                    FROM dcat.UserRoleAssignment ura
                    WHERE ura.RoleId = @NextApproverRoleId AND ura.IsActive = 1;
            END
        END

        -- Audit log
        INSERT INTO dcat.AuditLog (ActionType, EntityType, EntityId, UserId, Notes)
        VALUES (@ActionType, 'WorkflowInstance', @InstanceId, @ActionByUserId,
                'Workflow action: ' + @ActionType + ISNULL(' - ' + @Notes, ''));

        COMMIT TRANSACTION;

        SELECT @InstanceId AS InstanceId,
               (SELECT Status FROM dcat.WorkflowInstance WHERE InstanceId = @InstanceId) AS Status;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- 6. REPORT GDPR - Dati personali per entità
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_GdprPersonalDataReport
    @SourceSystemCode VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SystemCode,
        s.SystemName,
        a.AssetName,
        e.EntityCode,
        e.EntityName,
        e.CriticalityLevel,
        attr.AttributeName,
        attr.GdprCategory,
        attr.IsPersonalData,
        attr.IsSensitiveData,
        attr.IsDirectIdentifier,
        attr.IsIndirectIdentifier,
        attr.PseudonymizationRequired,
        attr.RetentionPeriodMonths,
        attr.DlpClassification,
        cl.LevelName AS ClassificationName
    FROM dcat.DataAttribute attr
    INNER JOIN dcat.DataEntity e ON attr.DataEntityId = e.DataEntityId
    INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
    INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
    LEFT JOIN dcat.ClassificationLevel cl ON attr.DataEntityId = e.DataEntityId
        AND e.ClassificationId = cl.ClassificationId
    WHERE attr.IsPersonalData = 1
      AND attr.IsActive = 1
      AND e.IsActive = 1
      AND (@SourceSystemCode IS NULL OR s.SystemCode = @SourceSystemCode)
    ORDER BY
        s.SystemCode,
        e.EntityCode,
        CASE WHEN attr.IsSensitiveData = 1 THEN 0 ELSE 1 END,
        CASE WHEN attr.IsDirectIdentifier = 1 THEN 0 ELSE 1 END,
        attr.AttributeName;
END;
GO

-- ============================================================================
-- 7. DASHBOARD STATISTICS
-- ============================================================================
CREATE OR ALTER PROCEDURE dcat.sp_DashboardStats
AS
BEGIN
    SET NOCOUNT ON;

    -- Conteggi generali
    SELECT
        (SELECT COUNT(*) FROM dcat.SourceSystem WHERE IsActive = 1) AS TotalSystems,
        (SELECT COUNT(*) FROM dcat.DataAsset WHERE IsActive = 1) AS TotalAssets,
        (SELECT COUNT(*) FROM dcat.DataEntity WHERE IsActive = 1) AS TotalEntities,
        (SELECT COUNT(*) FROM dcat.DataAttribute WHERE IsActive = 1) AS TotalAttributes,
        (SELECT COUNT(*) FROM dcat.EtlPipeline WHERE IsActive = 1) AS TotalPipelines,
        (SELECT COUNT(*) FROM dcat.BusinessGlossary WHERE IsActive = 1) AS TotalGlossaryTerms;

    -- Per stato governance
    SELECT GovernanceStatus, COUNT(*) AS EntityCount
    FROM dcat.DataEntity WHERE IsActive = 1
    GROUP BY GovernanceStatus;

    -- Per classificazione
    SELECT cl.LevelCode, cl.LevelName, cl.Color, COUNT(e.DataEntityId) AS EntityCount
    FROM dcat.ClassificationLevel cl
    LEFT JOIN dcat.DataEntity e ON e.ClassificationId = cl.ClassificationId AND e.IsActive = 1
    GROUP BY cl.LevelCode, cl.LevelName, cl.Color, cl.LevelOrder
    ORDER BY cl.LevelOrder;

    -- Per criticità
    SELECT CriticalityLevel, COUNT(*) AS EntityCount
    FROM dcat.DataEntity WHERE IsActive = 1 AND CriticalityLevel IS NOT NULL
    GROUP BY CriticalityLevel;

    -- GDPR
    SELECT
        SUM(CASE WHEN ContainsPersonalData = 1 THEN 1 ELSE 0 END) AS WithPersonalData,
        SUM(CASE WHEN ContainsSensitiveData = 1 THEN 1 ELSE 0 END) AS WithSensitiveData,
        SUM(CASE WHEN GdprRelevant = 1 THEN 1 ELSE 0 END) AS GdprRelevant
    FROM dcat.DataEntity WHERE IsActive = 1;

    -- Workflow pendenti
    SELECT COUNT(*) AS PendingWorkflows
    FROM dcat.WorkflowInstance
    WHERE Status IN ('PENDING', 'IN_PROGRESS');
END;
GO
