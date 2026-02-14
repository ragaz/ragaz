/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Governance & Workflow Tables - Utenti, ruoli, workflow approvativo
================================================================================
*/

-- ============================================================================
-- 1. UTENTI DEL CATALOGO
-- ============================================================================
CREATE TABLE dcat.CatalogUser (
    UserId              INT IDENTITY(1,1) PRIMARY KEY,
    Username            NVARCHAR(128) NOT NULL UNIQUE,
    DisplayName         NVARCHAR(200) NOT NULL,
    Email               NVARCHAR(200) NOT NULL,
    Department          NVARCHAR(100) NULL,       -- 'DWH','ATTUARIATO','RISK','COMPLIANCE','CONTABILITA','IT','DIREZIONE'
    JobTitle            NVARCHAR(200) NULL,
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ============================================================================
-- 2. RUOLI DI GOVERNANCE
-- ============================================================================
CREATE TABLE dcat.GovernanceRole (
    RoleId              INT IDENTITY(1,1) PRIMARY KEY,
    RoleCode            VARCHAR(30)   NOT NULL UNIQUE,
    RoleName            NVARCHAR(100) NOT NULL,
    Description         NVARCHAR(MAX) NULL,
    Permissions         NVARCHAR(MAX) NULL        -- JSON con i permessi
);
GO

-- ============================================================================
-- 3. ASSEGNAZIONE RUOLI
-- ============================================================================
CREATE TABLE dcat.UserRoleAssignment (
    AssignmentId        INT IDENTITY(1,1) PRIMARY KEY,
    UserId              INT           NOT NULL REFERENCES dcat.CatalogUser(UserId),
    RoleId              INT           NOT NULL REFERENCES dcat.GovernanceRole(RoleId),
    Scope               VARCHAR(50)   NULL,       -- 'GLOBAL','SOURCE_SYSTEM','DATA_ASSET','DATA_ENTITY'
    ScopeEntityId       INT           NULL,       -- ID dell'entità a cui si applica il ruolo
    IsActive            BIT           NOT NULL DEFAULT 1,
    AssignedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    AssignedBy          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    CONSTRAINT UQ_UserRole UNIQUE (UserId, RoleId, Scope, ScopeEntityId)
);
GO

-- ============================================================================
-- 4. WORKFLOW APPROVATIVO
-- ============================================================================
CREATE TABLE dcat.WorkflowDefinition (
    WorkflowId          INT IDENTITY(1,1) PRIMARY KEY,
    WorkflowCode        VARCHAR(50)   NOT NULL UNIQUE,
    WorkflowName        NVARCHAR(200) NOT NULL,
    EntityType          VARCHAR(50)   NOT NULL,   -- 'DATA_ENTITY','DATA_ATTRIBUTE','CLASSIFICATION','GDPR_ACTIVITY','GLOSSARY_TERM'
    Description         NVARCHAR(MAX) NULL,
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ============================================================================
-- 5. STEP DEL WORKFLOW
-- ============================================================================
CREATE TABLE dcat.WorkflowStep (
    WorkflowStepId      INT IDENTITY(1,1) PRIMARY KEY,
    WorkflowId          INT           NOT NULL REFERENCES dcat.WorkflowDefinition(WorkflowId),
    StepOrder           INT           NOT NULL,
    StepName            NVARCHAR(200) NOT NULL,
    StepType            VARCHAR(30)   NOT NULL,   -- 'APPROVAL','REVIEW','NOTIFICATION','AUTO_CHECK'
    ApproverRoleId      INT           NULL REFERENCES dcat.GovernanceRole(RoleId),
    ApproverUserId      INT           NULL REFERENCES dcat.CatalogUser(UserId),
    Description         NVARCHAR(MAX) NULL,
    IsActive            BIT           NOT NULL DEFAULT 1,
    CONSTRAINT UQ_WorkflowStep UNIQUE (WorkflowId, StepOrder)
);
GO

-- ============================================================================
-- 6. ISTANZE DI WORKFLOW (richieste in corso)
-- ============================================================================
CREATE TABLE dcat.WorkflowInstance (
    InstanceId          INT IDENTITY(1,1) PRIMARY KEY,
    WorkflowId          INT           NOT NULL REFERENCES dcat.WorkflowDefinition(WorkflowId),
    -- Entità oggetto del workflow
    TargetEntityType    VARCHAR(50)   NOT NULL,
    TargetEntityId      INT           NOT NULL,
    -- Stato
    CurrentStepId       INT           NULL REFERENCES dcat.WorkflowStep(WorkflowStepId),
    Status              VARCHAR(30)   NOT NULL DEFAULT 'PENDING', -- 'PENDING','IN_PROGRESS','APPROVED','REJECTED','CANCELLED'
    -- Richiedente
    RequestedBy         INT           NOT NULL REFERENCES dcat.CatalogUser(UserId),
    RequestDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    RequestNotes        NVARCHAR(MAX) NULL,
    -- Risoluzione
    ResolvedDate        DATETIME2     NULL,
    ResolvedBy          INT           NULL REFERENCES dcat.CatalogUser(UserId),
    ResolutionNotes     NVARCHAR(MAX) NULL,
    -- Change tracking
    ChangeDescription   NVARCHAR(MAX) NULL,       -- Cosa cambia con questa approvazione
    PreviousValues      NVARCHAR(MAX) NULL,       -- JSON snapshot prima della modifica
    NewValues           NVARCHAR(MAX) NULL         -- JSON snapshot dopo la modifica
);
GO

-- ============================================================================
-- 7. AZIONI DI WORKFLOW (storico approvazioni/rigetti)
-- ============================================================================
CREATE TABLE dcat.WorkflowAction (
    ActionId            INT IDENTITY(1,1) PRIMARY KEY,
    InstanceId          INT           NOT NULL REFERENCES dcat.WorkflowInstance(InstanceId),
    WorkflowStepId      INT           NOT NULL REFERENCES dcat.WorkflowStep(WorkflowStepId),
    ActionType          VARCHAR(20)   NOT NULL,   -- 'APPROVE','REJECT','DELEGATE','COMMENT','ESCALATE'
    ActionBy            INT           NOT NULL REFERENCES dcat.CatalogUser(UserId),
    ActionDate          DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    Notes               NVARCHAR(MAX) NULL,
    -- Per deleghe
    DelegatedTo         INT           NULL REFERENCES dcat.CatalogUser(UserId)
);
GO

-- ============================================================================
-- 8. AUDIT LOG COMPLETO
-- ============================================================================
CREATE TABLE dcat.AuditLog (
    AuditId             BIGINT IDENTITY(1,1) PRIMARY KEY,
    ActionTimestamp     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ActionType          VARCHAR(20)   NOT NULL,   -- 'INSERT','UPDATE','DELETE','VIEW','EXPORT','APPROVE','REJECT'
    EntityType          VARCHAR(50)   NOT NULL,   -- Nome tabella / tipo entità
    EntityId            INT           NULL,
    UserId              INT           NULL REFERENCES dcat.CatalogUser(UserId),
    Username            NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    OldValues           NVARCHAR(MAX) NULL,       -- JSON
    NewValues           NVARCHAR(MAX) NULL,       -- JSON
    IpAddress           VARCHAR(45)   NULL,
    UserAgent           NVARCHAR(500) NULL,
    Notes               NVARCHAR(MAX) NULL
);
GO

CREATE NONCLUSTERED INDEX IX_AuditLog_Entity
    ON dcat.AuditLog (EntityType, EntityId, ActionTimestamp DESC);
GO

CREATE NONCLUSTERED INDEX IX_AuditLog_User
    ON dcat.AuditLog (UserId, ActionTimestamp DESC);
GO

-- ============================================================================
-- 9. NOTIFICHE
-- ============================================================================
CREATE TABLE dcat.Notification (
    NotificationId      INT IDENTITY(1,1) PRIMARY KEY,
    UserId              INT           NOT NULL REFERENCES dcat.CatalogUser(UserId),
    Title               NVARCHAR(300) NOT NULL,
    Message             NVARCHAR(MAX) NULL,
    NotificationType    VARCHAR(30)   NOT NULL,   -- 'WORKFLOW','DATA_QUALITY','SYSTEM','REVIEW_DUE','EXPIRY'
    RelatedEntityType   VARCHAR(50)   NULL,
    RelatedEntityId     INT           NULL,
    IsRead              BIT           NOT NULL DEFAULT 0,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ReadDate            DATETIME2     NULL
);
GO

-- ============================================================================
-- 10. TAG E ANNOTAZIONI (flessibilità per classificazioni custom)
-- ============================================================================
CREATE TABLE dcat.Tag (
    TagId               INT IDENTITY(1,1) PRIMARY KEY,
    TagName             NVARCHAR(100) NOT NULL UNIQUE,
    TagCategory         VARCHAR(50)   NULL,       -- 'DOMAIN','REGULATION','PROJECT','TEAM','CUSTOM'
    Color               VARCHAR(7)    NULL,
    IsActive            BIT           NOT NULL DEFAULT 1
);
GO

CREATE TABLE dcat.EntityTag (
    EntityTagId         INT IDENTITY(1,1) PRIMARY KEY,
    TagId               INT           NOT NULL REFERENCES dcat.Tag(TagId),
    TargetEntityType    VARCHAR(50)   NOT NULL,   -- 'SOURCE_SYSTEM','DATA_ASSET','DATA_ENTITY','DATA_ATTRIBUTE'
    TargetEntityId      INT           NOT NULL,
    AddedBy             NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    AddedDate           DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_EntityTag UNIQUE (TagId, TargetEntityType, TargetEntityId)
);
GO

-- FK aggiuntive per ownership su tabelle core
ALTER TABLE dcat.SourceSystem ADD CONSTRAINT FK_SourceSystem_DataOwner
    FOREIGN KEY (DataOwnerUserId) REFERENCES dcat.CatalogUser(UserId);
ALTER TABLE dcat.SourceSystem ADD CONSTRAINT FK_SourceSystem_TechOwner
    FOREIGN KEY (TechnicalOwnerUserId) REFERENCES dcat.CatalogUser(UserId);
ALTER TABLE dcat.DataAsset ADD CONSTRAINT FK_DataAsset_DataOwner
    FOREIGN KEY (DataOwnerId) REFERENCES dcat.CatalogUser(UserId);
ALTER TABLE dcat.DataAsset ADD CONSTRAINT FK_DataAsset_TechOwner
    FOREIGN KEY (TechnicalOwnerId) REFERENCES dcat.CatalogUser(UserId);
ALTER TABLE dcat.DataEntity ADD CONSTRAINT FK_DataEntity_DataOwner
    FOREIGN KEY (DataOwnerId) REFERENCES dcat.CatalogUser(UserId);
ALTER TABLE dcat.DataEntity ADD CONSTRAINT FK_DataEntity_DataSteward
    FOREIGN KEY (DataStewardId) REFERENCES dcat.CatalogUser(UserId);
ALTER TABLE dcat.EtlPipeline ADD CONSTRAINT FK_EtlPipeline_Owner
    FOREIGN KEY (OwnerId) REFERENCES dcat.CatalogUser(UserId);
ALTER TABLE dcat.BusinessGlossary ADD CONSTRAINT FK_Glossary_DataOwner
    FOREIGN KEY (DataOwnerId) REFERENCES dcat.CatalogUser(UserId);
GO
