/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Viste per l'applicazione web e la reportistica
================================================================================
*/

-- ============================================================================
-- 1. VISTA CATALOGO COMPLETO (navigazione principale)
-- ============================================================================
CREATE OR ALTER VIEW dcat.vw_CatalogBrowse AS
SELECT
    e.DataEntityId,
    e.EntityCode,
    e.EntityName,
    e.EntityType,
    e.Description         AS EntityDescription,
    e.BusinessDescription,
    e.DwhLayer,
    e.LoadFrequency,
    e.LoadStrategy,
    e.CriticalityLevel,
    e.GovernanceStatus,
    e.ContainsPersonalData,
    e.ContainsSensitiveData,
    e.ContainsFinancialData,
    e.GdprRelevant,
    -- Asset
    a.DataAssetId,
    a.AssetCode,
    a.AssetName,
    a.AssetType,
    a.DwhLayer             AS AssetDwhLayer,
    a.RefreshFrequency,
    -- Sistema sorgente
    s.SourceSystemId,
    s.SystemCode,
    s.SystemName,
    s.SystemType,
    s.Vendor,
    -- Classificazione
    cl.LevelCode           AS ClassificationCode,
    cl.LevelName           AS ClassificationName,
    cl.LevelOrder          AS ClassificationOrder,
    cl.Color               AS ClassificationColor,
    -- Ownership
    do_user.DisplayName    AS DataOwnerName,
    do_user.Department     AS DataOwnerDepartment,
    ds_user.DisplayName    AS DataStewardName,
    -- Criticità calcolata
    ca.OverallScore        AS CriticalityScore,
    ca.RegulatoryImpact,
    ca.GdprImpact,
    ca.DataLossImpact
FROM dcat.DataEntity e
INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
LEFT JOIN dcat.ClassificationLevel cl ON COALESCE(e.ClassificationId, a.ClassificationId) = cl.ClassificationId
LEFT JOIN dcat.CatalogUser do_user ON e.DataOwnerId = do_user.UserId
LEFT JOIN dcat.CatalogUser ds_user ON e.DataStewardId = ds_user.UserId
LEFT JOIN dcat.CriticalityAssessment ca ON e.DataEntityId = ca.DataEntityId
WHERE e.IsActive = 1 AND a.IsActive = 1 AND s.IsActive = 1;
GO

-- ============================================================================
-- 2. VISTA LINEAGE (per grafo di lineage)
-- ============================================================================
CREATE OR ALTER VIEW dcat.vw_LineageGraph AS
SELECT
    el.LineageId,
    -- Sorgente
    el.SourceEntityId,
    se.EntityCode       AS SourceEntityCode,
    se.EntityName       AS SourceEntityName,
    se.EntityType       AS SourceEntityType,
    sa.AssetName        AS SourceAssetName,
    ss.SystemName       AS SourceSystemName,
    ss.SystemCode       AS SourceSystemCode,
    se.DwhLayer         AS SourceDwhLayer,
    -- Destinazione
    el.TargetEntityId,
    te.EntityCode       AS TargetEntityCode,
    te.EntityName       AS TargetEntityName,
    te.EntityType       AS TargetEntityType,
    ta.AssetName        AS TargetAssetName,
    ts.SystemName       AS TargetSystemName,
    ts.SystemCode       AS TargetSystemCode,
    te.DwhLayer         AS TargetDwhLayer,
    -- Pipeline
    el.PipelineId,
    p.PipelineCode,
    p.PipelineName,
    p.PipelineType,
    p.CriticalityLevel  AS PipelineCriticality,
    -- Lineage info
    el.LineageType,
    el.TransformationType,
    el.Description       AS LineageDescription
FROM dcat.EntityLineage el
INNER JOIN dcat.DataEntity se ON el.SourceEntityId = se.DataEntityId
INNER JOIN dcat.DataAsset sa ON se.DataAssetId = sa.DataAssetId
INNER JOIN dcat.SourceSystem ss ON sa.SourceSystemId = ss.SourceSystemId
INNER JOIN dcat.DataEntity te ON el.TargetEntityId = te.DataEntityId
INNER JOIN dcat.DataAsset ta ON te.DataAssetId = ta.DataAssetId
INNER JOIN dcat.SourceSystem ts ON ta.SourceSystemId = ts.SourceSystemId
LEFT JOIN dcat.EtlPipeline p ON el.PipelineId = p.PipelineId
WHERE el.IsActive = 1;
GO

-- ============================================================================
-- 3. VISTA GDPR - Registro trattamenti con dettaglio
-- ============================================================================
CREATE OR ALTER VIEW dcat.vw_GdprRegistry AS
SELECT
    pa.ActivityId,
    pa.ActivityCode,
    pa.ActivityName,
    pa.Description,
    pa.Status,
    -- Base giuridica
    lb.BasisCode,
    lb.BasisName,
    lb.GdprArticle,
    -- Finalità
    pp.PurposeCode,
    pp.PurposeName,
    pp.RetentionPeriodMonths,
    -- Categorie dati
    pa.PersonalDataCategories,
    pa.SensitiveDataCategories,
    -- Trasferimenti
    pa.TransferOutsideEEA,
    pa.TransferSafeguards,
    -- DPIA
    pa.DpiaRequired,
    pa.DpiaStatus,
    pa.DpiaDate,
    -- Sicurezza
    pa.SecurityMeasures,
    -- Retention
    pa.RetentionJustification,
    -- Review
    pa.LastReviewDate,
    pa.NextReviewDate,
    pa.ApprovedBy,
    pa.ApprovedDate
FROM dcat.GdprProcessingActivity pa
LEFT JOIN dcat.GdprLegalBasis lb ON pa.LegalBasisId = lb.LegalBasisId
LEFT JOIN dcat.GdprProcessingPurpose pp ON pa.PurposeId = pp.PurposeId;
GO

-- ============================================================================
-- 4. VISTA IMPATTO REGOLAMENTARE (quali dati alimentano quali report)
-- ============================================================================
CREATE OR ALTER VIEW dcat.vw_RegulatoryImpact AS
SELECT
    rr.ReportId,
    rr.ReportCode,
    rr.ReportName,
    rr.RegulatoryBody,
    rr.Regulation,
    rr.Frequency,
    rr.Deadline,
    rr.CriticalityLevel  AS ReportCriticality,
    rr.ResponsibleTeam,
    -- Entità che alimentano il report
    rem.ContributionType,
    e.DataEntityId,
    e.EntityCode,
    e.EntityName,
    e.CriticalityLevel   AS EntityCriticality,
    e.GovernanceStatus,
    -- Sistema sorgente originario
    s.SystemCode,
    s.SystemName,
    -- Classificazione
    cl.LevelCode          AS ClassificationCode,
    cl.LevelName          AS ClassificationName
FROM dcat.RegulatoryReport rr
INNER JOIN dcat.ReportEntityMap rem ON rr.ReportId = rem.ReportId
INNER JOIN dcat.DataEntity e ON rem.DataEntityId = e.DataEntityId
INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
LEFT JOIN dcat.ClassificationLevel cl ON e.ClassificationId = cl.ClassificationId
WHERE rr.IsActive = 1 AND e.IsActive = 1;
GO

-- ============================================================================
-- 5. VISTA DATA QUALITY DASHBOARD
-- ============================================================================
CREATE OR ALTER VIEW dcat.vw_DataQualityDashboard AS
SELECT
    r.RuleId,
    r.RuleCode,
    r.RuleName,
    r.RuleType,
    r.Severity,
    -- Entità associata
    e.DataEntityId,
    e.EntityCode,
    e.EntityName,
    e.CriticalityLevel,
    -- Pipeline associata
    p.PipelineCode,
    p.PipelineName,
    -- Ultimo risultato
    latest.CheckDate      AS LastCheckDate,
    latest.Passed         AS LastCheckPassed,
    latest.ActualResult   AS LastActualResult,
    latest.AffectedRows   AS LastAffectedRows,
    -- Statistiche ultimi 30 giorni
    stats.TotalChecks,
    stats.PassedChecks,
    stats.FailedChecks,
    CASE WHEN stats.TotalChecks > 0
         THEN CAST(stats.PassedChecks AS DECIMAL(5,2)) / stats.TotalChecks * 100
         ELSE NULL END    AS PassRate30Days
FROM dcat.DataQualityRule r
LEFT JOIN dcat.DataEntity e ON r.DataEntityId = e.DataEntityId
LEFT JOIN dcat.EtlPipeline p ON r.PipelineId = p.PipelineId
OUTER APPLY (
    SELECT TOP 1 dqr.CheckDate, dqr.Passed, dqr.ActualResult, dqr.AffectedRows
    FROM dcat.DataQualityResult dqr
    WHERE dqr.RuleId = r.RuleId
    ORDER BY dqr.CheckDate DESC
) latest
OUTER APPLY (
    SELECT
        COUNT(*)           AS TotalChecks,
        SUM(CASE WHEN dqr2.Passed = 1 THEN 1 ELSE 0 END) AS PassedChecks,
        SUM(CASE WHEN dqr2.Passed = 0 THEN 1 ELSE 0 END) AS FailedChecks
    FROM dcat.DataQualityResult dqr2
    WHERE dqr2.RuleId = r.RuleId
      AND dqr2.CheckDate >= DATEADD(DAY, -30, SYSUTCDATETIME())
) stats
WHERE r.IsActive = 1;
GO

-- ============================================================================
-- 6. VISTA WORKFLOW PENDENTI
-- ============================================================================
CREATE OR ALTER VIEW dcat.vw_PendingWorkflows AS
SELECT
    wi.InstanceId,
    wd.WorkflowCode,
    wd.WorkflowName,
    wi.TargetEntityType,
    wi.TargetEntityId,
    wi.Status,
    wi.RequestDate,
    wi.RequestNotes,
    wi.ChangeDescription,
    -- Step corrente
    ws.StepOrder          AS CurrentStepOrder,
    ws.StepName           AS CurrentStepName,
    ws.StepType           AS CurrentStepType,
    -- Ruolo approvatore
    gr.RoleCode           AS ApproverRoleCode,
    gr.RoleName           AS ApproverRoleName,
    -- Approvatore specifico
    au.DisplayName        AS ApproverUserName,
    -- Richiedente
    ru.DisplayName        AS RequestedByName,
    ru.Department         AS RequestedByDepartment,
    -- Calcolo giorni in attesa
    DATEDIFF(DAY, wi.RequestDate, SYSUTCDATETIME()) AS DaysPending
FROM dcat.WorkflowInstance wi
INNER JOIN dcat.WorkflowDefinition wd ON wi.WorkflowId = wd.WorkflowId
LEFT JOIN dcat.WorkflowStep ws ON wi.CurrentStepId = ws.WorkflowStepId
LEFT JOIN dcat.GovernanceRole gr ON ws.ApproverRoleId = gr.RoleId
LEFT JOIN dcat.CatalogUser au ON ws.ApproverUserId = au.UserId
INNER JOIN dcat.CatalogUser ru ON wi.RequestedBy = ru.UserId
WHERE wi.Status IN ('PENDING', 'IN_PROGRESS');
GO

-- ============================================================================
-- 7. VISTA IMPACT ANALYSIS (cosa succede se un'entità ha problemi)
-- ============================================================================
CREATE OR ALTER VIEW dcat.vw_ImpactAnalysis AS
WITH RECURSIVE_Lineage AS (
    -- Base: entità direttamente dipendenti
    SELECT
        el.SourceEntityId   AS RootEntityId,
        el.TargetEntityId   AS ImpactedEntityId,
        1                   AS HopCount,
        CAST(CAST(el.SourceEntityId AS VARCHAR(10)) + ' -> ' + CAST(el.TargetEntityId AS VARCHAR(10)) AS VARCHAR(MAX)) AS Path
    FROM dcat.EntityLineage el
    WHERE el.IsActive = 1

    UNION ALL

    -- Ricorsione: dipendenze transitive
    SELECT
        rl.RootEntityId,
        el2.TargetEntityId,
        rl.HopCount + 1,
        rl.Path + ' -> ' + CAST(el2.TargetEntityId AS VARCHAR(10))
    FROM RECURSIVE_Lineage rl
    INNER JOIN dcat.EntityLineage el2 ON rl.ImpactedEntityId = el2.SourceEntityId
    WHERE el2.IsActive = 1
      AND rl.HopCount < 10  -- Limite di profondità
      AND CHARINDEX(CAST(el2.TargetEntityId AS VARCHAR(10)), rl.Path) = 0  -- Anti-ciclo
)
SELECT
    rl.RootEntityId,
    root_e.EntityCode     AS RootEntityCode,
    root_e.EntityName     AS RootEntityName,
    root_s.SystemCode     AS RootSystemCode,
    rl.ImpactedEntityId,
    imp_e.EntityCode      AS ImpactedEntityCode,
    imp_e.EntityName      AS ImpactedEntityName,
    imp_e.CriticalityLevel AS ImpactedCriticality,
    imp_s.SystemCode      AS ImpactedSystemCode,
    rl.HopCount,
    rl.Path
FROM RECURSIVE_Lineage rl
INNER JOIN dcat.DataEntity root_e ON rl.RootEntityId = root_e.DataEntityId
INNER JOIN dcat.DataAsset root_a ON root_e.DataAssetId = root_a.DataAssetId
INNER JOIN dcat.SourceSystem root_s ON root_a.SourceSystemId = root_s.SourceSystemId
INNER JOIN dcat.DataEntity imp_e ON rl.ImpactedEntityId = imp_e.DataEntityId
INNER JOIN dcat.DataAsset imp_a ON imp_e.DataAssetId = imp_a.DataAssetId
INNER JOIN dcat.SourceSystem imp_s ON imp_a.SourceSystemId = imp_s.SourceSystemId;
GO
