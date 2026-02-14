/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Classification Tables - Framework di classificazione dati

  Modello a 4 livelli:
    PUBBLICO       -> Dati pubblicabili senza restrizioni
    INTERNO        -> Uso interno, nessuna restrizione specifica
    RISERVATO      -> Accesso limitato, dati personali/finanziari
    STRETT. RISERVATO -> Dati sanitari, giudiziari, segreti industriali
================================================================================
*/

-- ============================================================================
-- 1. LIVELLI DI CLASSIFICAZIONE
-- ============================================================================
CREATE TABLE dcat.ClassificationLevel (
    ClassificationId    INT IDENTITY(1,1) PRIMARY KEY,
    LevelCode           VARCHAR(30)   NOT NULL UNIQUE,
    LevelName           NVARCHAR(100) NOT NULL,
    LevelOrder          INT           NOT NULL,   -- 1=più basso, 4=più alto
    Description         NVARCHAR(MAX) NULL,
    HandlingRules       NVARCHAR(MAX) NULL,       -- Regole di trattamento
    StorageRules        NVARCHAR(MAX) NULL,       -- Regole di archiviazione
    TransmissionRules   NVARCHAR(MAX) NULL,       -- Regole di trasmissione
    DisposalRules       NVARCHAR(MAX) NULL,       -- Regole di distruzione
    AccessControlRules  NVARCHAR(MAX) NULL,       -- Regole di accesso
    Color               VARCHAR(7)    NULL,       -- Codice colore per UI (#RRGGBB)
    Icon                VARCHAR(50)   NULL,
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ============================================================================
-- 2. CATEGORIE GDPR - Basi giuridiche del trattamento
-- ============================================================================
CREATE TABLE dcat.GdprLegalBasis (
    LegalBasisId        INT IDENTITY(1,1) PRIMARY KEY,
    BasisCode           VARCHAR(30)   NOT NULL UNIQUE,
    BasisName           NVARCHAR(200) NOT NULL,
    GdprArticle         VARCHAR(20)   NULL,       -- Art. 6.1.a, 6.1.b, etc.
    Description         NVARCHAR(MAX) NULL,
    IsActive            BIT           NOT NULL DEFAULT 1
);
GO

-- ============================================================================
-- 3. FINALITA' DEL TRATTAMENTO GDPR
-- ============================================================================
CREATE TABLE dcat.GdprProcessingPurpose (
    PurposeId           INT IDENTITY(1,1) PRIMARY KEY,
    PurposeCode         VARCHAR(50)   NOT NULL UNIQUE,
    PurposeName         NVARCHAR(300) NOT NULL,
    Description         NVARCHAR(MAX) NULL,
    LegalBasisId        INT           NULL REFERENCES dcat.GdprLegalBasis(LegalBasisId),
    RetentionPeriodMonths INT         NULL,
    IsActive            BIT           NOT NULL DEFAULT 1
);
GO

-- ============================================================================
-- 4. CATEGORIE DI INTERESSATI GDPR
-- ============================================================================
CREATE TABLE dcat.GdprDataSubjectCategory (
    SubjectCategoryId   INT IDENTITY(1,1) PRIMARY KEY,
    CategoryCode        VARCHAR(30)   NOT NULL UNIQUE,
    CategoryName        NVARCHAR(200) NOT NULL,
    Description         NVARCHAR(MAX) NULL,
    EstimatedCount      INT           NULL,       -- Numero stimato di interessati
    IsActive            BIT           NOT NULL DEFAULT 1
);
GO

-- ============================================================================
-- 5. REGISTRO DEI TRATTAMENTI (Art. 30 GDPR)
-- ============================================================================
CREATE TABLE dcat.GdprProcessingActivity (
    ActivityId          INT IDENTITY(1,1) PRIMARY KEY,
    ActivityCode        VARCHAR(60)   NOT NULL UNIQUE,
    ActivityName        NVARCHAR(300) NOT NULL,
    Description         NVARCHAR(MAX) NULL,
    -- Titolare / Responsabile
    DataControllerId    INT           NULL,       -- FK a Organization o Users
    DataProcessorId     INT           NULL,
    JointControllerId   INT           NULL,
    -- Basi giuridiche e finalità
    LegalBasisId        INT           NULL REFERENCES dcat.GdprLegalBasis(LegalBasisId),
    PurposeId           INT           NULL REFERENCES dcat.GdprProcessingPurpose(PurposeId),
    -- Categorie di dati
    PersonalDataCategories NVARCHAR(MAX) NULL,    -- Identificativi, finanziari, sanitari
    SensitiveDataCategories NVARCHAR(MAX) NULL,
    -- Trasferimenti
    TransferOutsideEEA BIT           NOT NULL DEFAULT 0,
    TransferSafeguards  NVARCHAR(MAX) NULL,       -- Clausole contrattuali tipo, etc.
    -- Sicurezza
    SecurityMeasures    NVARCHAR(MAX) NULL,
    -- Retention
    RetentionPeriodMonths INT         NULL,
    RetentionJustification NVARCHAR(MAX) NULL,
    -- DPIA
    DpiaRequired        BIT           NOT NULL DEFAULT 0,
    DpiaStatus          VARCHAR(30)   NULL,       -- 'NOT_STARTED','IN_PROGRESS','COMPLETED'
    DpiaDate            DATE          NULL,
    -- Stato
    Status              VARCHAR(30)   NOT NULL DEFAULT 'DRAFT',
    ApprovedBy          NVARCHAR(128) NULL,
    ApprovedDate        DATETIME2     NULL,
    LastReviewDate      DATE          NULL,
    NextReviewDate      DATE          NULL,
    -- Audit
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy           NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    ModifiedBy          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
);
GO

-- ============================================================================
-- 6. MAPPING: Trattamento <-> Categorie di interessati
-- ============================================================================
CREATE TABLE dcat.GdprActivitySubjectMap (
    ActivityId          INT NOT NULL REFERENCES dcat.GdprProcessingActivity(ActivityId),
    SubjectCategoryId   INT NOT NULL REFERENCES dcat.GdprDataSubjectCategory(SubjectCategoryId),
    PRIMARY KEY (ActivityId, SubjectCategoryId)
);
GO

-- ============================================================================
-- 7. MAPPING: Trattamento <-> Data Entity
-- ============================================================================
CREATE TABLE dcat.GdprActivityEntityMap (
    ActivityId          INT NOT NULL REFERENCES dcat.GdprProcessingActivity(ActivityId),
    DataEntityId        INT NOT NULL REFERENCES dcat.DataEntity(DataEntityId),
    ProcessingRole      VARCHAR(30)   NULL,       -- 'INPUT','OUTPUT','STORAGE','TRANSIT'
    PRIMARY KEY (ActivityId, DataEntityId)
);
GO

-- ============================================================================
-- 8. REPORT REGOLAMENTARI
-- ============================================================================
CREATE TABLE dcat.RegulatoryReport (
    ReportId            INT IDENTITY(1,1) PRIMARY KEY,
    ReportCode          VARCHAR(30)   NOT NULL UNIQUE,
    ReportName          NVARCHAR(300) NOT NULL,
    RegulatoryBody      VARCHAR(50)   NOT NULL,   -- 'IVASS','BANCA_ITALIA','EIOPA','CONSOB','AGENZIA_ENTRATE'
    Regulation          NVARCHAR(200) NULL,       -- 'SOLVENCY_II','ANTIRICICLAGGIO','FATCA_CRS','LOCAL_GAAP'
    Frequency           VARCHAR(30)   NULL,       -- 'QUARTERLY','ANNUAL','MONTHLY','ON_DEMAND'
    Deadline            NVARCHAR(200) NULL,       -- Descrizione scadenza
    CriticalityLevel    VARCHAR(20)   NOT NULL DEFAULT 'HIGH',
    Description         NVARCHAR(MAX) NULL,
    ResponsibleTeam     NVARCHAR(200) NULL,
    IsActive            BIT           NOT NULL DEFAULT 1,
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ============================================================================
-- 9. MAPPING: Report <-> Data Entity (quali tabelle alimentano quali report)
-- ============================================================================
CREATE TABLE dcat.ReportEntityMap (
    ReportId            INT NOT NULL REFERENCES dcat.RegulatoryReport(ReportId),
    DataEntityId        INT NOT NULL REFERENCES dcat.DataEntity(DataEntityId),
    ContributionType    VARCHAR(30)   NULL,       -- 'PRIMARY_SOURCE','SECONDARY_SOURCE','VALIDATION','RECONCILIATION'
    Description         NVARCHAR(500) NULL,
    PRIMARY KEY (ReportId, DataEntityId)
);
GO

-- ============================================================================
-- 10. CRITICITA' - Matrice di impatto
-- ============================================================================
CREATE TABLE dcat.CriticalityAssessment (
    AssessmentId        INT IDENTITY(1,1) PRIMARY KEY,
    DataEntityId        INT           NOT NULL REFERENCES dcat.DataEntity(DataEntityId),
    -- Dimensioni di criticità (scala 1-5)
    RegulatoryImpact    INT           NOT NULL CHECK (RegulatoryImpact BETWEEN 1 AND 5),
    OperationalImpact   INT           NOT NULL CHECK (OperationalImpact BETWEEN 1 AND 5),
    FinancialImpact     INT           NOT NULL CHECK (FinancialImpact BETWEEN 1 AND 5),
    ReputationalImpact  INT           NOT NULL CHECK (ReputationalImpact BETWEEN 1 AND 5),
    GdprImpact          INT           NOT NULL CHECK (GdprImpact BETWEEN 1 AND 5),
    DataLossImpact      INT           NOT NULL CHECK (DataLossImpact BETWEEN 1 AND 5),
    -- Calcolato
    OverallScore        AS (RegulatoryImpact + OperationalImpact + FinancialImpact
                           + ReputationalImpact + GdprImpact + DataLossImpact),
    OverallLevel        AS (CASE
        WHEN (RegulatoryImpact + OperationalImpact + FinancialImpact
              + ReputationalImpact + GdprImpact + DataLossImpact) >= 24 THEN 'CRITICAL'
        WHEN (RegulatoryImpact + OperationalImpact + FinancialImpact
              + ReputationalImpact + GdprImpact + DataLossImpact) >= 18 THEN 'HIGH'
        WHEN (RegulatoryImpact + OperationalImpact + FinancialImpact
              + ReputationalImpact + GdprImpact + DataLossImpact) >= 12 THEN 'MEDIUM'
        ELSE 'LOW'
    END),
    -- Note
    Justification       NVARCHAR(MAX) NULL,
    AssessedBy          NVARCHAR(128) NOT NULL,
    AssessedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    NextReviewDate      DATE          NULL,
    -- Audit
    CreatedDate         DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDate        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- FK alle tabelle core
ALTER TABLE dcat.DataAsset
    ADD CONSTRAINT FK_DataAsset_Classification
    FOREIGN KEY (ClassificationId) REFERENCES dcat.ClassificationLevel(ClassificationId);
GO

ALTER TABLE dcat.DataEntity
    ADD CONSTRAINT FK_DataEntity_Classification
    FOREIGN KEY (ClassificationId) REFERENCES dcat.ClassificationLevel(ClassificationId);
GO
