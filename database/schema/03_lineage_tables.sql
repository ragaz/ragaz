/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Data Lineage Tables - Tracciabilità completa dei flussi dati

  Il modello traccia:
  - Pipeline ETL (Job SQL Agent, SSIS Package, Stored Procedure)
  - Dipendenze tra entità (quale tabella alimenta quale)
  - Lineage a livello di attributo (colonna origine -> colonna destinazione)
  - Impatto a cascata (se un dato sorgente cambia, cosa viene impattato)
================================================================================
*/

-- ============================================================================
-- 1. PIPELINE ETL
-- ============================================================================
CREATE TABLE dcat.EtlPipeline (
    PipelineId          INT IDENTITY(1,1) PRIMARY KEY,
    PipelineCode        VARCHAR(60)   NOT NULL UNIQUE,
    PipelineName        NVARCHAR(300) NOT NULL,
    PipelineType        VARCHAR(50)   NOT NULL,   -- 'SQL_AGENT_JOB','SSIS_PACKAGE','STORED_PROCEDURE','MANUAL','SCRIPT'
    Description         NVARCHAR(MAX) NULL,
    -- Riferimenti fisici
    JobName             NVARCHAR(300) NULL,       -- Nome job SQL Agent
    PackageName         NVARCHAR(300) NULL,       -- Nome package SSIS
    ProcedureName       NVARCHAR(300) NULL,       -- Nome stored procedure
    ServerName          NVARCHAR(200) NULL,
    -- Schedule
    ScheduleDescription NVARCHAR(500) NULL,
    ScheduleCron        VARCHAR(100)  NULL,       -- Espressione cron-like
    ExecutionOrder      INT           NULL,       -- Ordine nella catena
    -- Criticità
    CriticalityLevel    VARCHAR(20)   NULL,
    MaxExecutionMinutes INT           NULL,       -- SLA di esecuzione
    AlertOnFailure      BIT           NOT NULL DEFAULT 1,
    AlertRecipients     NVARCHAR(500) NULL,
    -- Ownership
    OwnerId             INT           NULL,
    -- Stato
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy           NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    ModifiedBy          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
);
GO

-- ============================================================================
-- 2. STEP DI PIPELINE
-- ============================================================================
CREATE TABLE dcat.EtlPipelineStep (
    StepId              INT IDENTITY(1,1) PRIMARY KEY,
    PipelineId          INT           NOT NULL REFERENCES dcat.EtlPipeline(PipelineId),
    StepOrder           INT           NOT NULL,
    StepName            NVARCHAR(300) NOT NULL,
    StepType            VARCHAR(50)   NULL,       -- 'TRUNCATE','INSERT','MERGE','UPDATE','TRANSFORM','VALIDATE','EXPORT'
    SourceEntityId      INT           NULL REFERENCES dcat.DataEntity(DataEntityId),
    TargetEntityId      INT           NULL REFERENCES dcat.DataEntity(DataEntityId),
    TransformationLogic NVARCHAR(MAX) NULL,       -- Descrizione o SQL della trasformazione
    Description         NVARCHAR(MAX) NULL,
    IsActive            BIT           NOT NULL DEFAULT 1,
    CONSTRAINT UQ_PipelineStep UNIQUE (PipelineId, StepOrder)
);
GO

-- ============================================================================
-- 3. LINEAGE A LIVELLO DI ENTITA' (tabella -> tabella)
-- ============================================================================
CREATE TABLE dcat.EntityLineage (
    LineageId           INT IDENTITY(1,1) PRIMARY KEY,
    SourceEntityId      INT           NOT NULL REFERENCES dcat.DataEntity(DataEntityId),
    TargetEntityId      INT           NOT NULL REFERENCES dcat.DataEntity(DataEntityId),
    PipelineId          INT           NULL REFERENCES dcat.EtlPipeline(PipelineId),
    LineageType         VARCHAR(30)   NOT NULL,   -- 'ETL','MANUAL','REFERENCE','DERIVATION','COPY'
    TransformationType  VARCHAR(30)   NULL,       -- 'DIRECT','AGGREGATION','FILTER','JOIN','PIVOT','CALCULATION'
    Description         NVARCHAR(MAX) NULL,
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_EntityLineage UNIQUE (SourceEntityId, TargetEntityId, PipelineId)
);
GO

-- ============================================================================
-- 4. LINEAGE A LIVELLO DI ATTRIBUTO (colonna -> colonna)
-- ============================================================================
CREATE TABLE dcat.AttributeLineage (
    AttributeLineageId  INT IDENTITY(1,1) PRIMARY KEY,
    EntityLineageId     INT           NOT NULL REFERENCES dcat.EntityLineage(LineageId),
    SourceAttributeId   INT           NOT NULL REFERENCES dcat.DataAttribute(DataAttributeId),
    TargetAttributeId   INT           NOT NULL REFERENCES dcat.DataAttribute(DataAttributeId),
    TransformationRule  NVARCHAR(MAX) NULL,       -- Es. "CAST(x AS DATE)", "ISNULL(x, 0)", "x + y"
    Description         NVARCHAR(MAX) NULL,
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ============================================================================
-- 5. DIPENDENZE TRA PIPELINE
-- ============================================================================
CREATE TABLE dcat.PipelineDependency (
    DependencyId        INT IDENTITY(1,1) PRIMARY KEY,
    PipelineId          INT           NOT NULL REFERENCES dcat.EtlPipeline(PipelineId),
    DependsOnPipelineId INT           NOT NULL REFERENCES dcat.EtlPipeline(PipelineId),
    DependencyType      VARCHAR(30)   NOT NULL DEFAULT 'SEQUENTIAL', -- 'SEQUENTIAL','CONDITIONAL','OPTIONAL'
    Description         NVARCHAR(500) NULL,
    CONSTRAINT UQ_PipelineDep UNIQUE (PipelineId, DependsOnPipelineId),
    CONSTRAINT CK_NoCyclicSelf CHECK (PipelineId <> DependsOnPipelineId)
);
GO

-- ============================================================================
-- 6. ESECUZIONI ETL (Log per tracciare lo storico)
-- ============================================================================
CREATE TABLE dcat.EtlExecution (
    ExecutionId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    PipelineId          INT           NOT NULL REFERENCES dcat.EtlPipeline(PipelineId),
    StartTime           DATETIME2     NOT NULL,
    EndTime             DATETIME2     NULL,
    Status              VARCHAR(20)   NOT NULL,   -- 'RUNNING','SUCCESS','FAILED','WARNING','CANCELLED'
    RowsRead            BIGINT        NULL,
    RowsWritten         BIGINT        NULL,
    RowsRejected        BIGINT        NULL,
    ErrorMessage        NVARCHAR(MAX) NULL,
    ExecutedBy          NVARCHAR(128) NULL,
    DurationSeconds     AS DATEDIFF(SECOND, StartTime, EndTime)
);
GO

-- Indice per query di monitoraggio
CREATE NONCLUSTERED INDEX IX_EtlExecution_Pipeline_Date
    ON dcat.EtlExecution (PipelineId, StartTime DESC)
    INCLUDE (Status, DurationSeconds);
GO

-- ============================================================================
-- 7. DATA QUALITY CHECKS collegati al lineage
-- ============================================================================
CREATE TABLE dcat.DataQualityRule (
    RuleId              INT IDENTITY(1,1) PRIMARY KEY,
    RuleCode            VARCHAR(60)   NOT NULL UNIQUE,
    RuleName            NVARCHAR(300) NOT NULL,
    RuleType            VARCHAR(50)   NOT NULL,   -- 'COMPLETENESS','ACCURACY','CONSISTENCY','TIMELINESS','UNIQUENESS','VALIDITY'
    DataEntityId        INT           NULL REFERENCES dcat.DataEntity(DataEntityId),
    DataAttributeId     INT           NULL REFERENCES dcat.DataAttribute(DataAttributeId),
    PipelineId          INT           NULL REFERENCES dcat.EtlPipeline(PipelineId),
    -- Definizione regola
    RuleExpression      NVARCHAR(MAX) NULL,       -- SQL o pseudocodice della regola
    ExpectedResult      NVARCHAR(500) NULL,
    Threshold           DECIMAL(5,2)  NULL,       -- Soglia di accettabilità (%)
    Severity            VARCHAR(20)   NOT NULL DEFAULT 'WARNING', -- 'BLOCKER','CRITICAL','WARNING','INFO'
    -- Azione
    ActionOnFailure     VARCHAR(30)   NULL,       -- 'STOP_PIPELINE','LOG_WARNING','NOTIFY','QUARANTINE'
    NotifyRecipients    NVARCHAR(500) NULL,
    -- Stato
    IsActive            BIT           NOT NULL DEFAULT 1,
    Description         NVARCHAR(MAX) NULL,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ============================================================================
-- 8. RISULTATI DATA QUALITY
-- ============================================================================
CREATE TABLE dcat.DataQualityResult (
    ResultId            BIGINT IDENTITY(1,1) PRIMARY KEY,
    RuleId              INT           NOT NULL REFERENCES dcat.DataQualityRule(RuleId),
    ExecutionId         BIGINT        NULL REFERENCES dcat.EtlExecution(ExecutionId),
    CheckDate           DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    Passed              BIT           NOT NULL,
    ActualResult        NVARCHAR(500) NULL,
    ExpectedResult      NVARCHAR(500) NULL,
    AffectedRows        BIGINT        NULL,
    Details             NVARCHAR(MAX) NULL
);
GO

CREATE NONCLUSTERED INDEX IX_DQResult_Rule_Date
    ON dcat.DataQualityResult (RuleId, CheckDate DESC)
    INCLUDE (Passed);
GO
