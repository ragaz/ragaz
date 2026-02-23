# Athora Italia – Governed Data Catalog

## Project Overview

This is the **Governed Data Catalog** for Athora Italia: a centralized, governed registry of the company's entire data estate. It maps, classifies, and traces every data object from source to final consumption, with a focus on:

- **GDPR compliance** – Art. 30 processing register, personal data classification
- **Regulatory reporting** – Data traceability for IVASS, Banca d'Italia, Solvency II
- **Data Loss Prevention (DLP)** – 4-level classification with operational handling rules
- **Data Lineage** – End-to-end source-to-destination traceability
- **Operational governance** – Approval workflows, data ownership, audit trail

---

## Technology Stack

| Component | Technology |
|---|---|
| Backend | ASP.NET Core 8.0 (C#) |
| Data access | Dapper (micro-ORM, raw SQL) |
| Database | Microsoft SQL Server 2019+ |
| DB schema | `dcat` (all catalog tables live here) |
| Frontend | Bootstrap 5 + Razor Views (MVC) |
| Lineage rendering | Native SVG (extensible with D3.js) |

---

## Repository Layout

```
ragaz/
├── webapp/                        # ASP.NET Core MVC application
│   ├── Controllers/               # HTTP request handlers (thin, delegate to Services)
│   │   ├── CatalogController.cs   # Source systems, assets, entities, search
│   │   ├── GovernanceController.cs# Workflows, GDPR register, criticality matrix
│   │   ├── HomeController.cs      # Dashboard
│   │   └── LineageController.cs   # Lineage graph, pipelines, JSON API endpoint
│   ├── Services/                  # Business / data-access logic
│   │   ├── CatalogService.cs      # All catalog queries
│   │   ├── GovernanceService.cs   # Workflow, GDPR, criticality queries
│   │   └── LineageService.cs      # Graph traversal, pipeline queries
│   ├── Models/
│   │   └── CatalogModels.cs       # All C# model classes (one file)
│   ├── Views/
│   │   ├── Catalog/               # Index, Assets, Search, Entity, Regulatory
│   │   ├── Governance/            # Index (workflows), Gdpr, Criticality
│   │   ├── Lineage/               # Index (lineage graph)
│   │   ├── Home/                  # Dashboard
│   │   └── Shared/                # _Layout.cshtml, _ViewImports, _ViewStart
│   ├── wwwroot/css/site.css
│   ├── Program.cs                 # App bootstrap, DI registration
│   ├── appsettings.json           # Connection string, logging config
│   └── GovernedDataCatalog.csproj # .NET 8, SqlClient 5.2, Dapper 2.1
│
├── database/
│   ├── schema/                    # Run in numeric order to create schema
│   │   ├── 01_core_tables.sql     # SourceSystem, DataAsset, DataEntity, DataAttribute
│   │   ├── 02_classification_tables.sql  # ClassificationLevel, GDPR tables, DLP rules
│   │   ├── 03_lineage_tables.sql  # EtlPipeline, EtlPipelineStep, EntityLineage, etc.
│   │   └── 04_governance_workflow_tables.sql  # CatalogUser, GovernanceRole, Workflow*
│   ├── seed/
│   │   ├── 01_seed_classification.sql   # Classification levels, GDPR bases/purposes
│   │   └── 02_seed_source_systems.sql   # Initial source systems
│   ├── stored-procedures/
│   │   ├── 01_catalog_procedures.sql
│   │   └── 02_discovery_procedures.sql
│   └── views/
│       └── 01_catalog_views.sql
│
└── docs/                          # Architecture and operational documentation (Italian)
    ├── 01_ARCHITETTURA_DATA_CATALOG.md
    ├── 02_FRAMEWORK_CLASSIFICAZIONE_DLP.md
    ├── 03_GUIDA_GDPR_ATHORA.md
    ├── 04_MATRICE_CRITICITA.md
    ├── 05_PRESENTAZIONE_PROGETTO_MANAGEMENT.md
    └── 06_MANUALE_OPERATIVO.md
```

---

## Development Workflows

### Build and Run

```bash
# Build the web application
cd webapp
dotnet build

# Run locally (Kestrel)
dotnet run

# Publish for IIS/production
dotnet publish -c Release
```

### Database Setup

Run scripts in strict numeric order against SQL Server 2019+:

```sql
-- 1. Create schema and core tables
-- database/schema/01_core_tables.sql
-- database/schema/02_classification_tables.sql
-- database/schema/03_lineage_tables.sql
-- database/schema/04_governance_workflow_tables.sql

-- 2. Seed reference data
-- database/seed/01_seed_classification.sql
-- database/seed/02_seed_source_systems.sql

-- 3. Create stored procedures and views
-- database/stored-procedures/01_catalog_procedures.sql
-- database/stored-procedures/02_discovery_procedures.sql
-- database/views/01_catalog_views.sql
```

### Configuration

Edit `webapp/appsettings.json` to set the SQL Server connection string:

```json
{
  "ConnectionStrings": {
    "DataCatalog": "Server=YOUR_SERVER;Database=DataCatalog;Trusted_Connection=True;TrustServerCertificate=True;"
  }
}
```

The connection string key must remain `"DataCatalog"` – it is referenced by name in `CatalogService`, `LineageService`, and `GovernanceService`.

---

## Architecture and Conventions

### MVC Pattern

- **Controllers are thin.** They call a single service method and return a view or JSON. No business logic or SQL belongs in controllers.
- **Services own all data access.** Each service (`CatalogService`, `LineageService`, `GovernanceService`) receives `IConfiguration` via constructor injection and opens `SqlConnection` through a private `CreateConnection()` factory method.
- **DI registration** is in `Program.cs` with `AddScoped<>` lifetime for all three services.

### Data Access with Dapper

All database queries use Dapper directly against SQL Server. There is no Entity Framework.

Key patterns used throughout the services:

```csharp
// Always use 'using var db = CreateConnection();' – connections are not reused
using var db = CreateConnection();

// Parameterized queries – always use anonymous object parameters
await db.QueryAsync<T>("SELECT ... WHERE Id = @Id", new { Id = id });

// Multi-result queries use QueryFirstOrDefaultAsync / QueryFirstAsync
var entity = await db.QueryFirstOrDefaultAsync<DataEntityModel>(...);

// Queries are capped at TOP 200 for search results to prevent unbounded returns
```

Never concatenate user input into SQL strings. Always use Dapper's parameterized query syntax.

### Database Schema Conventions

All tables live in the `dcat` schema. Every table follows this pattern:

- `IsActive BIT NOT NULL DEFAULT 1` – soft deletes; never hard-delete rows
- `CreatedDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`
- `ModifiedDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()`
- `CreatedBy / ModifiedBy NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()`
- Primary keys are `INT IDENTITY(1,1)`
- String codes use `VARCHAR` (ASCII); display names use `NVARCHAR`

### Data Model Hierarchy

```
SourceSystem (1) ──> (N) DataAsset (1) ──> (N) DataEntity (1) ──> (N) DataAttribute
```

- **SourceSystem** – A source or destination system (e.g. PASS, Smarthall, SAP FI)
- **DataAsset** – A database, file, or network share within a system
- **DataEntity** – A table, view, Excel sheet, or file section within an asset
- **DataAttribute** – A column or field within an entity

### Domain Enumerations

These are stored as `VARCHAR` codes in the database, not foreign keys to lookup tables (except `ClassificationLevel`):

| Field | Values |
|---|---|
| `DwhLayer` | `STAGING`, `LEVEL0`, `LEVEL1`, `DATAMART` |
| `CriticalityLevel` | `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `GovernanceStatus` | `DRAFT`, `UNDER_REVIEW`, `APPROVED`, `DEPRECATED` |
| `EntityType` | `TABLE`, `VIEW`, `STORED_PROCEDURE`, `EXCEL_SHEET`, `ACCESS_TABLE`, `CSV_FILE`, `FLAT_SECTION` |
| `LoadStrategy` | `FULL`, `INCREMENTAL`, `SNAPSHOT`, `DELTA`, `YTD` |
| `WorkflowStatus` | `PENDING`, `IN_PROGRESS`, `APPROVED`, `REJECTED`, `CANCELLED` |

### Classification Levels (4-tier DLP)

Stored in `dcat.ClassificationLevel` and referenced by `ClassificationId` FK:

| Code | Name | Description |
|---|---|---|
| `PUBBLICO` | Pubblico | Data publishable without restrictions |
| `INTERNO` | Interno | Internal use, no specific restrictions |
| `RISERVATO` | Riservato | Limited access – personal/financial data |
| `STRETT_RIS` | Strettamente Riservato | Health, judicial, industrial secret data |

### Lineage Graph Traversal

`LineageService.GetLineageGraphAsync()` performs recursive CTE traversal up to 5 levels upstream and downstream from a given entity. The result is a `LineageGraphModel` with `Nodes` and `Edges` lists. The `LineageController.GraphData()` action returns this as JSON for JavaScript rendering.

### Models

All C# models are in a single file `webapp/Models/CatalogModels.cs`. When adding new models, add them to this file grouped by domain area (Catalog, Lineage, Governance, Dashboard, Search).

---

## Key URL Routes

| URL | Controller.Action | Description |
|---|---|---|
| `/` | `Home.Index` | Dashboard with KPIs |
| `/Catalog` | `Catalog.Index` | Browse by source system |
| `/Catalog/Assets?sourceSystemId=N` | `Catalog.Assets` | Assets for a system |
| `/Catalog/Search` | `Catalog.Search` | Full-text + filter search |
| `/Catalog/Entity/{id}` | `Catalog.Entity` | Entity detail with attributes |
| `/Catalog/Regulatory` | `Catalog.Regulatory` | Regulatory reports |
| `/Lineage?entityId=N` | `Lineage.Index` | Lineage graph for an entity |
| `/Lineage/Pipelines` | `Lineage.Pipelines` | ETL pipelines list |
| `/Lineage/GraphData?entityId=N` | `Lineage.GraphData` | JSON graph data (AJAX) |
| `/Governance` | `Governance.Index` | Pending approval workflows |
| `/Governance/Gdpr` | `Governance.Gdpr` | GDPR processing activities register |
| `/Governance/Criticality` | `Governance.Criticality` | Criticality assessment matrix |

---

## Language and Localization

- **Source code** (C#, SQL): identifiers and comments are in English or Italian depending on context. Business domain terms follow Italian insurance/regulatory terminology.
- **Documentation** (`docs/`): entirely in Italian.
- **UI views**: Italian labels and content.
- Do not introduce English-only UI strings; maintain Italian business terminology.

---

## What Is Not Implemented Yet

- **Authentication/Authorization** – `app.UseAuthorization()` is wired in `Program.cs` but no auth scheme is configured. No `[Authorize]` attributes are used. Adding auth requires configuring Windows Auth or an identity provider.
- **Write operations** – All current service methods are read-only queries. No create/update/delete endpoints exist yet.
- **Workflow actions** – The workflow table exists but there are no controller actions to advance or approve workflow steps.
- **Data Quality** – `DataQualityRule` and `DataQualityResult` tables are referenced in the architecture diagram but not yet in the schema scripts.
- **Tests** – No test project exists. When adding tests, create a separate `GovernedDataCatalog.Tests` project targeting xUnit.

---

## Adding New Features

### Adding a new service method

1. Add the SQL query method to the relevant service (`CatalogService`, `LineageService`, or `GovernanceService`).
2. Add a model class to `Models/CatalogModels.cs` if needed, grouped under the appropriate domain section.
3. Add the controller action in the corresponding controller.
4. Add or update the Razor view in `Views/{Controller}/`.

### Adding a new database table

1. Add the `CREATE TABLE` statement to the appropriate schema file (or create a new numbered file if it belongs to a new domain group).
2. Follow the soft-delete and audit column conventions described above.
3. Add to the `dcat` schema.
4. Update seed data scripts if reference data is needed.

### SQL query guidelines

- Always filter `WHERE IsActive = 1` on all tables that support soft deletes.
- Use `TOP N` on unbounded queries (search results) to prevent large result sets.
- Order criticality using `CASE CriticalityLevel WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 ...` pattern – do not rely on alphabetical ordering.
- Use `COALESCE(e.ClassificationId, a.ClassificationId)` when an entity may inherit classification from its parent asset.
