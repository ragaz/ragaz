/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Core Tables - Entità fondamentali del catalogo

  Target: Microsoft SQL Server 2019+
  Schema: dcat (Data Catalog)
================================================================================
*/

-- Schema dedicato
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dcat')
    EXEC('CREATE SCHEMA dcat');
GO

-- ============================================================================
-- 1. SISTEMI SORGENTE (Source Systems)
-- ============================================================================
CREATE TABLE dcat.SourceSystem (
    SourceSystemId      INT IDENTITY(1,1) PRIMARY KEY,
    SystemCode          VARCHAR(30)   NOT NULL UNIQUE,
    SystemName          NVARCHAR(200) NOT NULL,
    SystemType          VARCHAR(50)   NOT NULL,  -- 'GESTIONALE','ERP','MOTORE_ATTUARIALE','DWH','FILE','DATABASE'
    Vendor              NVARCHAR(200) NULL,
    Description         NVARCHAR(MAX) NULL,
    ConnectionType      VARCHAR(50)   NULL,  -- 'DB_LINK','FILE_TRANSFER','API','ODS','MANUAL'
    Environment         VARCHAR(20)   NOT NULL DEFAULT 'PRODUCTION', -- 'PRODUCTION','TEST','DEV'
    IsActive            BIT           NOT NULL DEFAULT 1,
    DataOwnerUserId     INT           NULL,       -- FK a Users
    TechnicalOwnerUserId INT          NULL,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy           NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    ModifiedBy          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
);
GO

-- ============================================================================
-- 2. ASSET DI DATI (Database, File, Cartelle condivise)
-- ============================================================================
CREATE TABLE dcat.DataAsset (
    DataAssetId         INT IDENTITY(1,1) PRIMARY KEY,
    SourceSystemId      INT           NOT NULL REFERENCES dcat.SourceSystem(SourceSystemId),
    AssetCode           VARCHAR(60)   NOT NULL UNIQUE,
    AssetName           NVARCHAR(300) NOT NULL,
    AssetType           VARCHAR(50)   NOT NULL,  -- 'DATABASE','FILE_EXCEL','FILE_CSV','FILE_ACCESS','FILE_FLAT','SCHEMA','NETWORK_SHARE'
    PhysicalLocation    NVARCHAR(500) NULL,       -- Server\Instance\Database o percorso UNC
    ServerName          NVARCHAR(200) NULL,
    DatabaseName        NVARCHAR(200) NULL,
    SchemaName          NVARCHAR(200) NULL,
    FilePath            NVARCHAR(500) NULL,       -- Per file Excel/CSV/Access
    FilePattern         NVARCHAR(200) NULL,       -- Pattern per file ricorrenti (es. *.csv)
    Description         NVARCHAR(MAX) NULL,
    DwhLayer            VARCHAR(20)   NULL,       -- 'STAGING','LEVEL0','LEVEL1','DATAMART'
    RefreshFrequency    VARCHAR(30)   NULL,       -- 'DAILY','MONTHLY','REAL_TIME','ON_DEMAND','YEARLY'
    IsActive            BIT           NOT NULL DEFAULT 1,
    DataOwnerId         INT           NULL,
    TechnicalOwnerId    INT           NULL,
    -- Classificazione
    ClassificationId    INT           NULL,       -- FK a ClassificationLevel
    GdprRelevant        BIT           NOT NULL DEFAULT 0,
    RegulatoryRelevant  BIT           NOT NULL DEFAULT 0,
    -- Audit
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy           NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    ModifiedBy          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
);
GO

-- ============================================================================
-- 3. ENTITA' DI DATI (Tabelle, Viste, Fogli Excel, Tabelle Access)
-- ============================================================================
CREATE TABLE dcat.DataEntity (
    DataEntityId        INT IDENTITY(1,1) PRIMARY KEY,
    DataAssetId         INT           NOT NULL REFERENCES dcat.DataAsset(DataAssetId),
    EntityCode          VARCHAR(120)  NOT NULL,
    EntityName          NVARCHAR(300) NOT NULL,
    EntityType          VARCHAR(50)   NOT NULL,  -- 'TABLE','VIEW','STORED_PROCEDURE','EXCEL_SHEET','ACCESS_TABLE','CSV_FILE','FLAT_SECTION'
    SchemaName          NVARCHAR(128) NULL,
    PhysicalName        NVARCHAR(300) NULL,       -- Nome fisico nel DB
    Description         NVARCHAR(MAX) NULL,
    BusinessDescription NVARCHAR(MAX) NULL,       -- Descrizione business-friendly
    RecordCount         BIGINT        NULL,
    SizeInMB            DECIMAL(18,2) NULL,
    DwhLayer            VARCHAR(20)   NULL,
    -- Frequenza e finestra di caricamento
    LoadFrequency       VARCHAR(30)   NULL,       -- 'DAILY','MONTHLY','ON_DEMAND'
    LoadStrategy        VARCHAR(30)   NULL,       -- 'FULL','INCREMENTAL','SNAPSHOT','DELTA','YTD'
    LoadWindowStart     TIME          NULL,
    LoadWindowEnd       TIME          NULL,
    -- Classificazione
    ClassificationId    INT           NULL,
    GdprRelevant        BIT           NOT NULL DEFAULT 0,
    ContainsPersonalData BIT          NOT NULL DEFAULT 0,
    ContainsSensitiveData BIT         NOT NULL DEFAULT 0,  -- Dati sanitari, etc.
    ContainsFinancialData BIT         NOT NULL DEFAULT 0,
    -- Criticità
    CriticalityLevel    VARCHAR(20)   NULL,       -- 'CRITICAL','HIGH','MEDIUM','LOW'
    RegulatoryReportIds NVARCHAR(500) NULL,       -- Lista report regolamentari alimentati
    -- Ownership
    DataOwnerId         INT           NULL,
    DataStewardId       INT           NULL,
    -- Stato governance
    GovernanceStatus    VARCHAR(30)   NOT NULL DEFAULT 'DRAFT', -- 'DRAFT','IN_REVIEW','APPROVED','DEPRECATED'
    ApprovedDate        DATETIME2     NULL,
    ApprovedBy          NVARCHAR(128) NULL,
    -- Audit
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy           NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    ModifiedBy          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    CONSTRAINT UQ_DataEntity_Code UNIQUE (DataAssetId, EntityCode)
);
GO

-- ============================================================================
-- 4. ATTRIBUTI (Colonne, Campi)
-- ============================================================================
CREATE TABLE dcat.DataAttribute (
    DataAttributeId     INT IDENTITY(1,1) PRIMARY KEY,
    DataEntityId        INT           NOT NULL REFERENCES dcat.DataEntity(DataEntityId),
    AttributeCode       VARCHAR(200)  NOT NULL,
    AttributeName       NVARCHAR(300) NOT NULL,
    PhysicalName        NVARCHAR(300) NULL,
    DataType            VARCHAR(50)   NULL,       -- 'VARCHAR','INT','DECIMAL','DATE','DATETIME','BIT',...
    MaxLength           INT           NULL,
    Precision           INT           NULL,
    Scale               INT           NULL,
    IsNullable          BIT           NOT NULL DEFAULT 1,
    IsPrimaryKey        BIT           NOT NULL DEFAULT 0,
    IsForeignKey        BIT           NOT NULL DEFAULT 0,
    DefaultValue        NVARCHAR(500) NULL,
    Description         NVARCHAR(MAX) NULL,
    BusinessDescription NVARCHAR(MAX) NULL,
    BusinessGlossaryTermId INT        NULL,       -- FK a glossario
    -- Classificazione GDPR
    GdprCategory        VARCHAR(50)   NULL,       -- 'IDENTIFICATIVO','CONTATTO','FINANZIARIO','SANITARIO','GIUDIZIARIO','BIOMETRICO',NULL
    IsPersonalData      BIT           NOT NULL DEFAULT 0,
    IsSensitiveData     BIT           NOT NULL DEFAULT 0,
    IsDirectIdentifier  BIT           NOT NULL DEFAULT 0,  -- Codice fiscale, nome, ecc.
    IsIndirectIdentifier BIT          NOT NULL DEFAULT 0,  -- Data nascita + CAP, ecc.
    PseudonymizationRequired BIT      NOT NULL DEFAULT 0,
    RetentionPeriodMonths INT         NULL,
    -- Classificazione DLP
    DlpClassification   VARCHAR(30)   NULL,       -- 'PUBLIC','INTERNAL','CONFIDENTIAL','STRICTLY_CONFIDENTIAL'
    -- Data Quality
    QualityCheckRule    NVARCHAR(MAX) NULL,
    NullPercentage      DECIMAL(5,2)  NULL,
    DistinctCount       BIGINT        NULL,
    SampleValues        NVARCHAR(500) NULL,
    -- Audit
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy           NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    ModifiedBy          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    CONSTRAINT UQ_DataAttribute_Code UNIQUE (DataEntityId, AttributeCode)
);
GO

-- ============================================================================
-- 5. GLOSSARIO BUSINESS
-- ============================================================================
CREATE TABLE dcat.BusinessGlossary (
    TermId              INT IDENTITY(1,1) PRIMARY KEY,
    TermCode            VARCHAR(60)   NOT NULL UNIQUE,
    TermName            NVARCHAR(300) NOT NULL,
    Definition          NVARCHAR(MAX) NOT NULL,
    DomainArea          VARCHAR(50)   NULL,       -- 'POLIZZE','PREMI','SINISTRI','RISERVE','CONTABILITA','SOLVENCY','INVESTIMENTI'
    Synonyms            NVARCHAR(500) NULL,
    RelatedTerms        NVARCHAR(500) NULL,
    DataOwnerId         INT           NULL,
    GovernanceStatus    VARCHAR(30)   NOT NULL DEFAULT 'DRAFT',
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy           NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    ModifiedBy          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
);
GO

ALTER TABLE dcat.DataAttribute
    ADD CONSTRAINT FK_DataAttribute_Glossary
    FOREIGN KEY (BusinessGlossaryTermId) REFERENCES dcat.BusinessGlossary(TermId);
GO
