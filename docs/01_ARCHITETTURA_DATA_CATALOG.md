# Athora Italia - Governed Data Catalog

## Architettura del Sistema

### Panoramica

Il Governed Data Catalog è il registro centralizzato e governato di tutto il patrimonio dati
di Athora Italia. Mappa, classifica e traccia ogni dato dalla sorgente al consumo finale,
con focus su:

- **Compliance GDPR** - Registro trattamenti Art. 30, classificazione dati personali
- **Reportistica regolamentare** - Tracciabilità dati per IVASS, Banca d'Italia, Solvency II
- **Data Loss Prevention** - Classificazione a 4 livelli con regole operative
- **Data Lineage** - Tracciabilità completa sorgente-destinazione
- **Governance operativa** - Workflow approvativi, ownership, audit trail

### Stack Tecnologico

| Componente | Tecnologia |
|---|---|
| Database | Microsoft SQL Server 2019+ |
| Schema | `dcat` (Data Catalog) |
| Backend | ASP.NET Core 8.0 |
| ORM/DAL | Dapper (micro-ORM) |
| Frontend | Bootstrap 5 + Razor Views |
| Lineage Rendering | SVG nativo (estendibile con D3.js) |

### Modello Dati

```
SourceSystem (1) ──> (N) DataAsset (1) ──> (N) DataEntity (1) ──> (N) DataAttribute
                                                    │
                                    ┌───────────────┼───────────────┐
                                    │               │               │
                             EntityLineage    CriticalityAssessment  GdprActivityEntityMap
                                    │                                       │
                             EtlPipeline                          GdprProcessingActivity
                                    │                                       │
                          EtlPipelineStep                          GdprLegalBasis
                                    │                              GdprProcessingPurpose
                          EtlExecution                             GdprDataSubjectCategory
                                    │
                          DataQualityRule ──> DataQualityResult
```

### Layer del Data Warehouse mappati

| Layer | Descrizione | Contenuto |
|---|---|---|
| **STAGING** | Importazione grezza | Dati da PASS, Smarthall, Sofia senza trasformazioni |
| **LEVEL0** | Formattazione | Formati e strutture uniformi tra le fonti |
| **LEVEL1** | Armonizzazione (Hub) | Attributi armonizzati, vista unificata PASS + Smarthall |

### Sistemi mappati

| Sistema | Tipo | Ruolo |
|---|---|---|
| PASS (RGI) | Gestionale polizze | Fonte primaria - flussi giornalieri/mensili + ODS |
| Smarthall (Previnet) | Gestionale polizze | Fonte primaria - flussi strutturati |
| SAP FI | ERP contabilità | Destinazione - prima nota |
| MGAlfa (Milliman) | Motore attuariale | Destinazione - input Solvency II |
| Sofia | Dati finanziari | Fonte - dati finanziari portafoglio |
| File rete/locali | Shadow IT | Fonte/Destinazione - file non governati |

### Flussi critici identificati

1. **DWH → MGAlfa** (Solvency II): assemblaggio dati PASS + Smarthall → controlli DQ → export MGAlfa
2. **DWH → SAP** (Prima nota): registrazioni contabili giornaliere
3. **DWH → IVASS** (Modelli 34-41): reportistica regolamentare annuale
4. **DWH → Banca d'Italia**: segnalazione residenti esteri mensile
5. **ODS PASS ↔ DWH**: riconciliazione per data quality

---

## Deployment

### Prerequisiti
- SQL Server 2019 o superiore
- .NET 8.0 Runtime
- IIS o Kestrel per hosting

### Installazione Database

Eseguire gli script nell'ordine:

```sql
-- 1. Schema e tabelle core
database/schema/01_core_tables.sql
database/schema/02_classification_tables.sql
database/schema/03_lineage_tables.sql
database/schema/04_governance_workflow_tables.sql

-- 2. Viste
database/views/01_catalog_views.sql

-- 3. Stored Procedures
database/stored-procedures/01_catalog_procedures.sql

-- 4. Dati di seed
database/seed/01_seed_classification.sql
database/seed/02_seed_source_systems.sql
```

### Configurazione Web App

1. Modificare `webapp/appsettings.json` con la connection string corretta
2. `dotnet build` per compilare
3. `dotnet run` per avviare in sviluppo
4. Per produzione: `dotnet publish -c Release` e configurare IIS
