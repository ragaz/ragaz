/*
================================================================================
  ATHORA ITALIA - GOVERNED DATA CATALOG
  Seed Data - Framework di classificazione e dati di riferimento
================================================================================
*/

-- ============================================================================
-- LIVELLI DI CLASSIFICAZIONE (4 livelli DLP)
-- ============================================================================
INSERT INTO dcat.ClassificationLevel (LevelCode, LevelName, LevelOrder, Description, HandlingRules, StorageRules, TransmissionRules, DisposalRules, AccessControlRules, Color)
VALUES
('PUBLIC', 'Pubblico', 1,
 'Dati destinati alla divulgazione pubblica. Nessuna restrizione di accesso.',
 'Nessuna restrizione particolare nel trattamento.',
 'Nessuna restrizione di storage. Può risiedere su qualsiasi supporto.',
 'Può essere trasmesso via email, condiviso liberamente.',
 'Nessuna procedura speciale di distruzione richiesta.',
 'Accesso aperto a tutti i dipendenti e stakeholder esterni autorizzati.',
 '#28A745'),

('INTERNAL', 'Interno', 2,
 'Dati ad uso esclusivamente interno. La divulgazione esterna non è autorizzata senza approvazione.',
 'Utilizzo limitato al perimetro aziendale. Non condividere con soggetti esterni senza autorizzazione del Data Owner.',
 'Storage su sistemi aziendali (file server, SQL Server, SharePoint). Non su dispositivi personali non gestiti.',
 'Trasmissione interna libera. Trasmissione esterna solo tramite canali sicuri (VPN, email crittografata) previa autorizzazione.',
 'Cancellazione standard dei file. Per supporti fisici: distruzione documentata.',
 'Accesso a tutti i dipendenti con credenziali aziendali. ACL basata su appartenenza al dominio.',
 '#17A2B8'),

('CONFIDENTIAL', 'Riservato', 3,
 'Dati personali, finanziari, contrattuali. Include dati GDPR di base (identificativi, contatti, dati finanziari polizze). Accesso limitato a personale autorizzato.',
 'Trattamento solo da parte di personale autorizzato e formato. Applicare principio del minimo privilegio. Tracciare gli accessi.',
 'Storage esclusivamente su sistemi protetti con accesso controllato. Crittografia a riposo raccomandata. No file su cartelle di rete aperte.',
 'Trasmissione solo su canali crittografati. Email con allegati crittografati o portale sicuro. Mai via servizi cloud pubblici non approvati.',
 'Cancellazione sicura (sovrascrittura). Supporti fisici: distruzione certificata. Log di distruzione obbligatorio.',
 'Accesso basato su ruolo (RBAC). Richiesta autorizzazione esplicita dal Data Owner. Review periodica degli accessi (semestrale).',
 '#FFC107'),

('STRICTLY_CONFIDENTIAL', 'Strettamente Riservato', 4,
 'Dati sanitari (questionari medici, cause sinistro), dati giudiziari, segreti industriali, dati che se divulgati causerebbero danno grave. Include categorie particolari ex Art. 9 GDPR.',
 'Trattamento solo in ambienti controllati. Accesso strettamente need-to-know. Obbligo di NDA per soggetti esterni. Ogni accesso deve essere tracciato e giustificato.',
 'Storage su sistemi dedicati con crittografia obbligatoria (TDE su SQL Server). Accesso biometrico o MFA obbligatorio. Backup crittografati.',
 'Trasmissione solo su canali crittografati end-to-end con conferma di ricezione. Pseudonimizzazione obbligatoria dove possibile.',
 'Cancellazione sicura certificata (DoD 5220.22-M o equivalente). Audit trail di distruzione conservato per 10 anni.',
 'Accesso individuale nominativo approvato dal Data Owner e dal DPO. Review trimestrale degli accessi. Logging completo di ogni operazione.',
 '#DC3545');
GO

-- ============================================================================
-- BASI GIURIDICHE GDPR (Art. 6 e Art. 9)
-- ============================================================================
INSERT INTO dcat.GdprLegalBasis (BasisCode, BasisName, GdprArticle, Description)
VALUES
('CONSENT',           'Consenso dell''interessato',         'Art. 6.1.a', 'L''interessato ha espresso il consenso al trattamento per una o più finalità specifiche.'),
('CONTRACT',          'Esecuzione di un contratto',         'Art. 6.1.b', 'Il trattamento è necessario per l''esecuzione di un contratto di cui l''interessato è parte (polizza assicurativa).'),
('LEGAL_OBLIGATION',  'Obbligo legale',                     'Art. 6.1.c', 'Il trattamento è necessario per adempiere un obbligo legale (segnalazioni IVASS, Banca d''Italia, normativa antiriciclaggio).'),
('VITAL_INTEREST',    'Interessi vitali',                   'Art. 6.1.d', 'Il trattamento è necessario per la salvaguardia degli interessi vitali dell''interessato.'),
('PUBLIC_INTEREST',   'Interesse pubblico',                 'Art. 6.1.e', 'Il trattamento è necessario per l''esecuzione di un compito di interesse pubblico.'),
('LEGITIMATE_INTEREST','Legittimo interesse',                'Art. 6.1.f', 'Il trattamento è necessario per il perseguimento del legittimo interesse del titolare (analisi attuariali, risk management).'),
('HEALTH_INSURANCE',  'Finalità assicurative sanitarie',    'Art. 9.2.h', 'Trattamento necessario per finalità di medicina preventiva, diagnosi, assistenza sanitaria nel contesto assicurativo.'),
('SUBSTANTIAL_PUBLIC','Interesse pubblico rilevante',        'Art. 9.2.g', 'Trattamento di categorie particolari per motivi di interesse pubblico rilevante (es. antiriciclaggio).');
GO

-- ============================================================================
-- FINALITA' DEL TRATTAMENTO
-- ============================================================================
INSERT INTO dcat.GdprProcessingPurpose (PurposeCode, PurposeName, Description, LegalBasisId, RetentionPeriodMonths)
VALUES
('POLICY_MGMT',      'Gestione contratto di polizza',
 'Emissione, gestione, modifica e cessazione delle polizze vita. Include calcolo premi, gestione titoli e sottotitoli.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'CONTRACT'), 120),

('CLAIMS_MGMT',      'Gestione sinistri e liquidazioni',
 'Apertura, istruttoria, liquidazione e chiusura dei sinistri vita. Include gestione percipienti.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'CONTRACT'), 120),

('ACCOUNTING',        'Contabilità e prima nota',
 'Registrazioni contabili, prima nota, trasferimento dati a SAP. Adempimenti fiscali.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'LEGAL_OBLIGATION'), 120),

('SOLVENCY',          'Valutazione solvibilità (Solvency II)',
 'Alimentazione MGAlfa per calcolo BEL, Risk Margin, SCR. Produzione QRT.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'LEGAL_OBLIGATION'), 120),

('REGULATORY_IVASS',  'Segnalazioni IVASS',
 'Produzione modelli statistici IVASS (34, 35, 39, 40, 41). Reportistica regolamentare.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'LEGAL_OBLIGATION'), 120),

('REGULATORY_BDI',    'Segnalazioni Banca d''Italia',
 'Segnalazione polizze e movimentazioni residenti esteri.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'LEGAL_OBLIGATION'), 120),

('AML',               'Antiriciclaggio',
 'Autovalutazione del rischio antiriciclaggio. Adeguata verifica della clientela. Segnalazioni operazioni sospette.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'LEGAL_OBLIGATION'), 120),

('RISK_MGMT',         'Risk management e ORSA',
 'Valutazione rischi, analisi attuariali, stress testing, report ORSA (prodotto da Risk).',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'LEGITIMATE_INTEREST'), 120),

('DWH_ANALYTICS',     'Data warehousing e analisi',
 'Consolidamento dati da fonti diverse, ETL, data quality, reportistica direzionale.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'LEGITIMATE_INTEREST'), 120),

('FINANCIAL_DATA',    'Dati finanziari - Sofia',
 'Ricezione e gestione dei dati finanziari dal sistema Sofia per le valutazioni di portafoglio.',
 (SELECT LegalBasisId FROM dcat.GdprLegalBasis WHERE BasisCode = 'LEGAL_OBLIGATION'), 120);
GO

-- ============================================================================
-- CATEGORIE DI INTERESSATI
-- ============================================================================
INSERT INTO dcat.GdprDataSubjectCategory (CategoryCode, CategoryName, Description)
VALUES
('POLICYHOLDER',   'Contraenti',           'Soggetti titolari del contratto di polizza vita.'),
('INSURED',        'Assicurati',           'Soggetti la cui vita è oggetto della copertura assicurativa.'),
('BENEFICIARY',    'Beneficiari',          'Soggetti designati come beneficiari delle prestazioni.'),
('CLAIMANT',       'Percipienti/Richiedenti','Soggetti che percepiscono le liquidazioni dei sinistri.'),
('AGENT',          'Agenti e intermediari','Rete di distribuzione: agenti, broker, intermediari.'),
('EMPLOYEE',       'Dipendenti',           'Personale dipendente di Athora Italia.'),
('SUPPLIER',       'Fornitori',            'Fornitori di servizi (periti, medici legali, consulenti).'),
('FOREIGN_RESIDENT','Residenti esteri',    'Soggetti residenti all''estero oggetto di segnalazione Banca d''Italia.');
GO

-- ============================================================================
-- RUOLI DI GOVERNANCE
-- ============================================================================
INSERT INTO dcat.GovernanceRole (RoleCode, RoleName, Description, Permissions)
VALUES
('ADMIN',          'Amministratore Catalogo',
 'Accesso completo a tutte le funzionalità del catalogo. Gestione utenti e configurazione.',
 '{"read":true,"write":true,"approve":true,"admin":true,"export":true,"delete":true}'),

('DATA_OWNER',     'Data Owner',
 'Responsabile di un dominio dati. Approva classificazioni, modifiche al catalogo e accessi ai dati del proprio dominio.',
 '{"read":true,"write":true,"approve":true,"admin":false,"export":true,"delete":false}'),

('DATA_STEWARD',   'Data Steward',
 'Responsabile operativo della qualità e documentazione dei dati. Propone classificazioni e modifiche.',
 '{"read":true,"write":true,"approve":false,"admin":false,"export":true,"delete":false}'),

('DPO',            'Data Protection Officer',
 'Supervisiona la conformità GDPR. Approva trattamenti con dati sensibili e DPIA.',
 '{"read":true,"write":true,"approve":true,"admin":false,"export":true,"delete":false}'),

('COMPLIANCE',     'Compliance Officer',
 'Verifica conformità regolamentare. Valida mapping tra dati e report regolamentari.',
 '{"read":true,"write":true,"approve":true,"admin":false,"export":true,"delete":false}'),

('BUSINESS_USER',  'Utente Business',
 'Consultazione del catalogo. Può cercare dati, visualizzare lineage e richiedere accessi.',
 '{"read":true,"write":false,"approve":false,"admin":false,"export":false,"delete":false}'),

('DWH_TEAM',       'Team Data Warehouse',
 'Team tecnico DWH. Gestisce pipeline ETL, data quality, documentazione tecnica.',
 '{"read":true,"write":true,"approve":false,"admin":false,"export":true,"delete":false}');
GO

-- ============================================================================
-- WORKFLOW APPROVATIVI
-- ============================================================================
-- Workflow 1: Approvazione classificazione dati
INSERT INTO dcat.WorkflowDefinition (WorkflowCode, WorkflowName, EntityType, Description)
VALUES ('WF_CLASSIFICATION', 'Approvazione Classificazione Dati', 'DATA_ENTITY',
        'Workflow per approvare la classificazione di sicurezza e GDPR di un''entità dati. Richiede approvazione del Data Steward, Data Owner e, per dati sensibili, del DPO.');

INSERT INTO dcat.WorkflowStep (WorkflowId, StepOrder, StepName, StepType, ApproverRoleId)
VALUES
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_CLASSIFICATION'), 1,
 'Review tecnico Data Steward', 'REVIEW',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DATA_STEWARD')),
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_CLASSIFICATION'), 2,
 'Approvazione Data Owner', 'APPROVAL',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DATA_OWNER')),
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_CLASSIFICATION'), 3,
 'Approvazione DPO (se dati sensibili)', 'APPROVAL',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DPO'));

-- Workflow 2: Approvazione nuova entità nel catalogo
INSERT INTO dcat.WorkflowDefinition (WorkflowCode, WorkflowName, EntityType, Description)
VALUES ('WF_NEW_ENTITY', 'Registrazione Nuova Entità Dati', 'DATA_ENTITY',
        'Workflow per registrare e approvare una nuova entità nel catalogo governato.');

INSERT INTO dcat.WorkflowStep (WorkflowId, StepOrder, StepName, StepType, ApproverRoleId)
VALUES
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_NEW_ENTITY'), 1,
 'Documentazione tecnica (DWH Team)', 'REVIEW',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DWH_TEAM')),
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_NEW_ENTITY'), 2,
 'Classificazione e ownership', 'APPROVAL',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DATA_OWNER')),
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_NEW_ENTITY'), 3,
 'Validazione compliance', 'APPROVAL',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'COMPLIANCE'));

-- Workflow 3: Modifica trattamento GDPR
INSERT INTO dcat.WorkflowDefinition (WorkflowCode, WorkflowName, EntityType, Description)
VALUES ('WF_GDPR_ACTIVITY', 'Approvazione Trattamento GDPR', 'GDPR_ACTIVITY',
        'Workflow per approvare o modificare un trattamento nel registro ex Art. 30. Obbligatorio per trattamenti con dati sanitari.');

INSERT INTO dcat.WorkflowStep (WorkflowId, StepOrder, StepName, StepType, ApproverRoleId)
VALUES
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_GDPR_ACTIVITY'), 1,
 'Review Data Steward', 'REVIEW',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DATA_STEWARD')),
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_GDPR_ACTIVITY'), 2,
 'Approvazione DPO', 'APPROVAL',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DPO')),
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_GDPR_ACTIVITY'), 3,
 'Validazione Compliance', 'APPROVAL',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'COMPLIANCE'));

-- Workflow 4: Approvazione termine glossario
INSERT INTO dcat.WorkflowDefinition (WorkflowCode, WorkflowName, EntityType, Description)
VALUES ('WF_GLOSSARY', 'Approvazione Termine Glossario', 'GLOSSARY_TERM',
        'Workflow per approvare nuovi termini o modifiche al glossario business.');

INSERT INTO dcat.WorkflowStep (WorkflowId, StepOrder, StepName, StepType, ApproverRoleId)
VALUES
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_GLOSSARY'), 1,
 'Review tecnico', 'REVIEW',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DATA_STEWARD')),
((SELECT WorkflowId FROM dcat.WorkflowDefinition WHERE WorkflowCode = 'WF_GLOSSARY'), 2,
 'Approvazione Data Owner di dominio', 'APPROVAL',
 (SELECT RoleId FROM dcat.GovernanceRole WHERE RoleCode = 'DATA_OWNER'));
GO

-- ============================================================================
-- TAG PREDEFINITI
-- ============================================================================
INSERT INTO dcat.Tag (TagName, TagCategory, Color)
VALUES
('Solvency II',       'REGULATION',  '#6F42C1'),
('IVASS',             'REGULATION',  '#6F42C1'),
('Banca d''Italia',   'REGULATION',  '#6F42C1'),
('Antiriciclaggio',   'REGULATION',  '#6F42C1'),
('GDPR',              'REGULATION',  '#E83E8C'),
('IFRS 17',           'REGULATION',  '#6F42C1'),
('Polizze',           'DOMAIN',      '#007BFF'),
('Premi',             'DOMAIN',      '#007BFF'),
('Sinistri',          'DOMAIN',      '#007BFF'),
('Riserve',           'DOMAIN',      '#007BFF'),
('Contabilità',       'DOMAIN',      '#007BFF'),
('Soggetti',          'DOMAIN',      '#007BFF'),
('Investimenti',      'DOMAIN',      '#007BFF'),
('PASS-RGI',          'PROJECT',     '#FD7E14'),
('Smarthall-Previnet','PROJECT',     '#FD7E14'),
('MGAlfa',            'PROJECT',     '#FD7E14'),
('SAP',               'PROJECT',     '#FD7E14'),
('Sofia',             'PROJECT',     '#FD7E14'),
('Flusso Critico',    'CUSTOM',      '#DC3545'),
('Da Documentare',    'CUSTOM',      '#FFC107'),
('Shadow IT',         'CUSTOM',      '#DC3545');
GO

-- ============================================================================
-- REPORT REGOLAMENTARI
-- ============================================================================
INSERT INTO dcat.RegulatoryReport (ReportCode, ReportName, RegulatoryBody, Regulation, Frequency, Deadline, CriticalityLevel, Description, ResponsibleTeam)
VALUES
('IVASS_34',  'Modello 34 - Portafoglio polizze vita',      'IVASS', 'Regolamento IVASS 13/2015', 'ANNUAL',    'Entro 120 gg dalla chiusura esercizio',        'CRITICAL', 'Dati di portafoglio polizze vita individuali e collettive a fine esercizio.', 'DWH / Attuariato'),
('IVASS_35',  'Modello 35 - Premi vita',                    'IVASS', 'Regolamento IVASS 13/2015', 'ANNUAL',    'Entro 120 gg dalla chiusura esercizio',        'CRITICAL', 'Raccolta premi vita per ramo, canale distributivo e tipologia.', 'DWH / Contabilità'),
('IVASS_39',  'Modello 39 - Riserve tecniche vita',         'IVASS', 'Regolamento IVASS 13/2015', 'ANNUAL',    'Entro 120 gg dalla chiusura esercizio',        'CRITICAL', 'Riserve matematiche e altre riserve tecniche vita.', 'DWH / Attuariato'),
('IVASS_40',  'Modello 40 - Sinistri vita',                 'IVASS', 'Regolamento IVASS 13/2015', 'ANNUAL',    'Entro 120 gg dalla chiusura esercizio',        'CRITICAL', 'Sinistri vita pagati e riservati per tipologia.', 'DWH / Sinistri'),
('IVASS_41',  'Modello 41 - Conto tecnico vita',            'IVASS', 'Regolamento IVASS 13/2015', 'ANNUAL',    'Entro 120 gg dalla chiusura esercizio',        'CRITICAL', 'Conto tecnico del ramo vita.', 'DWH / Contabilità'),
('BDI_ESTERI','Segnalazione residenti esteri',               'BANCA_ITALIA', 'Normativa valutaria', 'MONTHLY', 'Entro il 25 del mese successivo',              'HIGH',     'Polizze e movimentazioni relative a residenti esteri.', 'DWH / Compliance'),
('AML_RISK',  'Autovalutazione rischio antiriciclaggio',     'BANCA_ITALIA', 'D.Lgs. 231/2007',    'ANNUAL',  'Entro chiusura esercizio',                     'HIGH',     'Autovalutazione del rischio di riciclaggio e finanziamento del terrorismo.', 'Compliance / DWH'),
('SOLV_QRT',  'QRT Solvency II',                             'IVASS',        'Solvency II',        'QUARTERLY','Trimestrale: 8 settimane; Annuale: 14 settimane','CRITICAL','Quantitative Reporting Templates per vigilanza prudenziale. Prodotti da MGAlfa.', 'Attuariato / Risk');
GO
