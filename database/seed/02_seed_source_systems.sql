/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Seed Data - Sistemi sorgente, asset e entità dati di Athora Italia
================================================================================
*/

-- ============================================================================
-- SISTEMI SORGENTE
-- ============================================================================
INSERT INTO dcat.SourceSystem (SystemCode, SystemName, SystemType, Vendor, Description, ConnectionType)
VALUES
('PASS_RGI',     'PASS - Gestionale Polizze',        'GESTIONALE',        'RGI S.p.A.',
 'Sistema gestionale polizze vita principale. Gestisce emissione, portafoglio, premi, sinistri, soggetti e ruoli di polizza. Alimenta il DWH con flussi giornalieri e mensili.',
 'FILE_TRANSFER'),

('PASS_ODS',     'PASS ODS - Replica operativa',     'DATABASE',          'RGI S.p.A.',
 'Operational Data Store di PASS. Replica il gestionale in logica denormalizzata e incrementale. Aggiornamento notturno.',
 'DB_LINK'),

('SMARTHALL',    'Smarthall - Gestionale Polizze',   'GESTIONALE',        'Previnet S.p.A.',
 'Secondo sistema gestionale polizze vita. Flussi più articolati come modello. Alimenta il DWH con flussi strutturati.',
 'FILE_TRANSFER'),

('SAP_FI',       'SAP - Contabilità generale',       'ERP',               'SAP SE',
 'Sistema ERP per la contabilità generale. Alimentato dal DWH tramite file di prima nota.',
 'FILE_TRANSFER'),

('MGALFA',       'MGAlfa - Motore attuariale',       'MOTORE_ATTUARIALE', 'Milliman',
 'Motore attuariale per valutazioni Solvency II. I dati di input sono preparati dal gestionale e assemblati/omogeneizzati dal DWH. Produce BEL, Risk Margin, SCR e QRT.',
 'FILE_TRANSFER'),

('SOFIA',        'Sofia - Dati finanziari',          'DATABASE',          NULL,
 'Sistema per i dati finanziari e le valutazioni di portafoglio investimenti.',
 'FILE_TRANSFER'),

('DWH_ATHORA',   'Enterprise Data Warehouse',        'DWH',               'Athora Italia (custom)',
 'Data Warehouse aziendale su SQL Server. 4 layer: Staging, Level 0 (formattazione), Level 1 (armonizzazione/hub). ETL in T-SQL con job SQL Agent.',
 'DB_LINK'),

('FILE_NETWORK', 'File su rete condivisa',           'FILE',              NULL,
 'File Excel, CSV, Access condivisi su cartelle di rete non protette. Rischio shadow IT. Da censire e governare.',
 'MANUAL'),

('FILE_LOCAL',   'File su PC locali utenti',         'FILE',              NULL,
 'File Excel, CSV, Access su PC locali degli utenti. Rischio elevato di data loss. Da censire e migrare.',
 'MANUAL');
GO

-- ============================================================================
-- DATA ASSET - Database e aree principali
-- ============================================================================
INSERT INTO dcat.DataAsset (SourceSystemId, AssetCode, AssetName, AssetType, Description, DwhLayer, RefreshFrequency, ClassificationId, GdprRelevant, RegulatoryRelevant)
VALUES
-- PASS RGI - Flussi
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'PASS_RGI'),
 'PASS_FLUSSI_GG', 'Flussi giornalieri PASS', 'FILE_FLAT',
 'Flussi giornalieri dal gestionale PASS: snapshot polizze, movimenti, soggetti.',
 'STAGING', 'DAILY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 1, 1),

((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'PASS_RGI'),
 'PASS_FLUSSI_MM', 'Flussi mensili PASS', 'FILE_FLAT',
 'Flussi mensili dal gestionale PASS: contabile premi YTD (titoli e sottotitoli), snapshot completo portafoglio.',
 'STAGING', 'MONTHLY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 1, 1),

-- PASS ODS
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'PASS_ODS'),
 'PASS_ODS_DB', 'Database ODS PASS', 'DATABASE',
 'Replica denormalizzata e incrementale del gestionale PASS. Aggiornato ogni notte. Usato per riconciliazioni e controlli incrociati.',
 NULL, 'DAILY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 1, 0),

-- Smarthall
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'SMARTHALL'),
 'SH_FLUSSI', 'Flussi Smarthall', 'FILE_FLAT',
 'Flussi articolati dal gestionale Smarthall. Modello dati differente da PASS, richiede armonizzazione nel DWH.',
 'STAGING', 'DAILY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 1, 1),

-- DWH Layers
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'DWH_ATHORA'),
 'DWH_STAGING', 'DWH - Layer Staging', 'SCHEMA',
 'Primo layer del DWH. Importazione dei dati senza formattazione, fedele alla sorgente.',
 'STAGING', 'DAILY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 1, 0),

((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'DWH_ATHORA'),
 'DWH_LEVEL0', 'DWH - Level 0 (Formattazione)', 'SCHEMA',
 'Secondo layer del DWH. Applicazione di formati e struttura uniforme tra le diverse fonti.',
 'LEVEL0', 'DAILY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 1, 0),

((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'DWH_ATHORA'),
 'DWH_LEVEL1', 'DWH - Level 1 (Armonizzazione/Hub)', 'SCHEMA',
 'Terzo layer del DWH. Armonizzazione degli attributi tra PASS e Smarthall. Vista unificata dei dati (hub).',
 'LEVEL1', 'DAILY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 1, 1),

-- Output verso SAP
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'SAP_FI'),
 'SAP_PRIMA_NOTA', 'File prima nota per SAP', 'FILE_FLAT',
 'File di interfaccia DWH -> SAP per registrazioni contabili. Generati dal DWH, caricati in SAP FI.',
 NULL, 'DAILY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 0, 1),

-- Output verso MGAlfa
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'MGALFA'),
 'MGALFA_INPUT', 'Dati input per MGAlfa', 'FILE_FLAT',
 'Dati assembati e omogeneizzati dal DWH (unione PASS + Smarthall) per alimentare il motore attuariale. Controlli DQ di primo livello applicati.',
 NULL, 'MONTHLY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'STRICTLY_CONFIDENTIAL'), 1, 1),

-- Sofia
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'SOFIA'),
 'SOFIA_FIN', 'Dati finanziari Sofia', 'DATABASE',
 'Dati finanziari ricevuti da Sofia per valutazioni di portafoglio investimenti.',
 'STAGING', 'DAILY',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 0, 1),

-- File di rete (Shadow IT)
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'FILE_NETWORK'),
 'NET_EXCEL_SHARE', 'Cartelle condivise Excel/CSV', 'NETWORK_SHARE',
 'File Excel, CSV e Access su cartelle di rete non protette. Contengono potenzialmente dati personali e finanziari. RISCHIO ELEVATO: nessun controllo di accesso, nessun versionamento.',
 NULL, 'ON_DEMAND',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'CONFIDENTIAL'), 1, 0),

-- File locali
((SELECT SourceSystemId FROM dcat.SourceSystem WHERE SystemCode = 'FILE_LOCAL'),
 'LOCAL_FILES', 'File su PC locali utenti', 'FILE_EXCEL',
 'File Excel e Access su PC locali. Rischio massimo di data loss (nessun backup, nessun controllo). Da censire urgentemente.',
 NULL, 'ON_DEMAND',
 (SELECT ClassificationId FROM dcat.ClassificationLevel WHERE LevelCode = 'STRICTLY_CONFIDENTIAL'), 1, 0);
GO

-- ============================================================================
-- ENTITA' DATI ESEMPIO - Layer DWH Level 1 (Hub armonizzato)
-- ============================================================================
INSERT INTO dcat.DataEntity (DataAssetId, EntityCode, EntityName, EntityType, Description, BusinessDescription, DwhLayer, LoadFrequency, LoadStrategy, CriticalityLevel, ContainsPersonalData, ContainsFinancialData, GdprRelevant, GovernanceStatus)
VALUES
-- Hub Polizze
((SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'DWH_LEVEL1'),
 'HUB_POLIZZE', 'Hub Polizze Vita', 'TABLE',
 'Tabella armonizzata contenente tutte le polizze vita di entrambi i gestionali (PASS + Smarthall). Snapshot completo con stato aggiornato.',
 'Vista unificata di tutte le polizze vita mai emesse dalla compagnia, con dettaglio ramo/rischio e stato corrente.',
 'LEVEL1', 'DAILY', 'SNAPSHOT', 'CRITICAL', 1, 1, 1, 'DRAFT'),

-- Hub Soggetti
((SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'DWH_LEVEL1'),
 'HUB_SOGGETTI', 'Hub Soggetti', 'TABLE',
 'Anagrafica unificata dei soggetti da entrambi i gestionali. Include contraenti, assicurati, beneficiari e relativi ruoli di polizza.',
 'Tutti i soggetti coinvolti nei contratti assicurativi con i rispettivi ruoli (contraente, assicurato, beneficiario, percipiente).',
 'LEVEL1', 'DAILY', 'INCREMENTAL', 'CRITICAL', 1, 0, 1, 'DRAFT'),

-- Hub Premi
((SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'DWH_LEVEL1'),
 'HUB_PREMI', 'Hub Contabile Premi', 'TABLE',
 'Dati contabili dei premi armonizzati. Titoli e sottotitoli in logica YTD da entrambi i gestionali.',
 'Raccolta premi vita consolidata per tutti i canali, con dettaglio titoli e sottotitoli contabili. Logica year-to-date.',
 'LEVEL1', 'MONTHLY', 'YTD', 'CRITICAL', 0, 1, 0, 'DRAFT'),

-- Hub Sinistri/Liquidazioni
((SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'DWH_LEVEL1'),
 'HUB_LIQUIDAZIONI', 'Hub Liquidazioni e Sinistri', 'TABLE',
 'Liquidazioni vita armonizzate con dati percipienti da entrambi i gestionali.',
 'Tutte le liquidazioni vita (scadenze, riscatti, sinistri) con identificazione dei percipienti.',
 'LEVEL1', 'DAILY', 'INCREMENTAL', 'CRITICAL', 1, 1, 1, 'DRAFT'),

-- Hub Movimenti
((SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'DWH_LEVEL1'),
 'HUB_MOVIMENTI', 'Hub Movimenti', 'TABLE',
 'Movimenti di polizza armonizzati (emissioni, appendici, variazioni, cessazioni).',
 'Storico di tutti i movimenti contrattuali sulle polizze vita.',
 'LEVEL1', 'DAILY', 'INCREMENTAL', 'HIGH', 0, 1, 0, 'DRAFT'),

-- Hub Ruoli di Polizza
((SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'DWH_LEVEL1'),
 'HUB_RUOLI_POLIZZA', 'Hub Ruoli di Polizza', 'TABLE',
 'Associazione soggetti-polizze con ruoli specifici (contraente, assicurato, beneficiario, referente). Armonizzato tra i due gestionali.',
 'Chi ricopre quale ruolo su quale polizza, con storicizzazione delle variazioni.',
 'LEVEL1', 'DAILY', 'INCREMENTAL', 'CRITICAL', 1, 0, 1, 'DRAFT'),

-- Dati per MGAlfa
((SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'MGALFA_INPUT'),
 'MGALFA_POLIZZE_INPUT', 'Input MGAlfa - Polizze assemblate', 'FILE_FLAT',
 'File di input per MGAlfa contenente i dati polizze assemblati dai due gestionali, con controlli DQ di primo livello superati.',
 'Dati polizze consolidati e validati per il calcolo delle riserve tecniche Solvency II.',
 NULL, 'MONTHLY', 'FULL', 'CRITICAL', 1, 1, 1, 'DRAFT'),

-- Output Prima Nota SAP
((SELECT DataAssetId FROM dcat.DataAsset WHERE AssetCode = 'SAP_PRIMA_NOTA'),
 'SAP_PN_FILE', 'File Prima Nota SAP', 'FILE_FLAT',
 'File di interfaccia per SAP FI con le registrazioni contabili generate dal DWH.',
 'Movimenti contabili da registrare nella contabilità generale SAP.',
 NULL, 'DAILY', 'INCREMENTAL', 'HIGH', 0, 1, 0, 'DRAFT');
GO
