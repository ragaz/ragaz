using System.Data;
using Microsoft.Data.SqlClient;
using Dapper;
using GovernedDataCatalog.Models;

namespace GovernedDataCatalog.Services;

public class CatalogService
{
    private readonly string _connectionString;

    public CatalogService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DataCatalog")
            ?? throw new InvalidOperationException("Connection string 'DataCatalog' not found.");
    }

    private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

    // ========================================================================
    // Source Systems
    // ========================================================================
    public async Task<IEnumerable<SourceSystemModel>> GetSourceSystemsAsync()
    {
        using var db = CreateConnection();
        return await db.QueryAsync<SourceSystemModel>(@"
            SELECT s.SourceSystemId, s.SystemCode, s.SystemName, s.SystemType,
                   s.Vendor, s.Description, s.ConnectionType, s.IsActive,
                   u.DisplayName AS DataOwnerName,
                   (SELECT COUNT(*) FROM dcat.DataAsset a WHERE a.SourceSystemId = s.SourceSystemId AND a.IsActive = 1) AS AssetCount,
                   (SELECT COUNT(*) FROM dcat.DataEntity e
                    INNER JOIN dcat.DataAsset a2 ON e.DataAssetId = a2.DataAssetId
                    WHERE a2.SourceSystemId = s.SourceSystemId AND e.IsActive = 1) AS EntityCount
            FROM dcat.SourceSystem s
            LEFT JOIN dcat.CatalogUser u ON s.DataOwnerUserId = u.UserId
            WHERE s.IsActive = 1
            ORDER BY s.SystemName");
    }

    // ========================================================================
    // Data Assets
    // ========================================================================
    public async Task<IEnumerable<DataAssetModel>> GetDataAssetsAsync(int? sourceSystemId = null)
    {
        using var db = CreateConnection();
        return await db.QueryAsync<DataAssetModel>(@"
            SELECT a.DataAssetId, a.SourceSystemId, a.AssetCode, a.AssetName, a.AssetType,
                   a.DwhLayer, a.RefreshFrequency, a.Description,
                   cl.LevelName AS ClassificationName, cl.Color AS ClassificationColor,
                   a.GdprRelevant, a.RegulatoryRelevant,
                   s.SystemName,
                   (SELECT COUNT(*) FROM dcat.DataEntity e WHERE e.DataAssetId = a.DataAssetId AND e.IsActive = 1) AS EntityCount
            FROM dcat.DataAsset a
            INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
            LEFT JOIN dcat.ClassificationLevel cl ON a.ClassificationId = cl.ClassificationId
            WHERE a.IsActive = 1
              AND (@SourceSystemId IS NULL OR a.SourceSystemId = @SourceSystemId)
            ORDER BY s.SystemName, a.AssetName",
            new { SourceSystemId = sourceSystemId });
    }

    // ========================================================================
    // Data Entities (Catalog Browse)
    // ========================================================================
    public async Task<IEnumerable<DataEntityModel>> SearchEntitiesAsync(SearchRequest request)
    {
        using var db = CreateConnection();
        return await db.QueryAsync<DataEntityModel>(@"
            SELECT TOP 200
                e.DataEntityId, e.EntityCode, e.EntityName, e.EntityType,
                e.Description, e.BusinessDescription, e.DwhLayer,
                e.LoadFrequency, e.LoadStrategy, e.CriticalityLevel,
                e.GovernanceStatus, e.ContainsPersonalData, e.ContainsSensitiveData,
                e.ContainsFinancialData, e.GdprRelevant,
                a.AssetName, s.SystemCode, s.SystemName,
                cl.LevelCode AS ClassificationCode,
                cl.LevelName AS ClassificationName,
                cl.Color AS ClassificationColor,
                do_u.DisplayName AS DataOwnerName,
                ds_u.DisplayName AS DataStewardName,
                ca.OverallScore AS CriticalityScore
            FROM dcat.DataEntity e
            INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
            INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
            LEFT JOIN dcat.ClassificationLevel cl ON COALESCE(e.ClassificationId, a.ClassificationId) = cl.ClassificationId
            LEFT JOIN dcat.CatalogUser do_u ON e.DataOwnerId = do_u.UserId
            LEFT JOIN dcat.CatalogUser ds_u ON e.DataStewardId = ds_u.UserId
            LEFT JOIN dcat.CriticalityAssessment ca ON e.DataEntityId = ca.DataEntityId
            WHERE e.IsActive = 1
              AND (@SearchTerm IS NULL OR @SearchTerm = ''
                   OR e.EntityName LIKE '%' + @SearchTerm + '%'
                   OR e.EntityCode LIKE '%' + @SearchTerm + '%'
                   OR e.Description LIKE '%' + @SearchTerm + '%'
                   OR e.BusinessDescription LIKE '%' + @SearchTerm + '%')
              AND (@EntityType IS NULL OR e.EntityType = @EntityType)
              AND (@SystemCode IS NULL OR s.SystemCode = @SystemCode)
              AND (@DwhLayer IS NULL OR e.DwhLayer = @DwhLayer)
              AND (@Classification IS NULL OR cl.LevelCode = @Classification)
              AND (@GdprOnly = 0 OR e.GdprRelevant = 1)
              AND (@CriticalOnly = 0 OR e.CriticalityLevel IN ('CRITICAL','HIGH'))
            ORDER BY
                CASE e.CriticalityLevel WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
                e.EntityName",
            new
            {
                request.SearchTerm,
                request.EntityType,
                request.SystemCode,
                request.DwhLayer,
                request.Classification,
                request.GdprOnly,
                request.CriticalOnly
            });
    }

    // ========================================================================
    // Entity Detail with Attributes
    // ========================================================================
    public async Task<DataEntityModel?> GetEntityDetailAsync(int entityId)
    {
        using var db = CreateConnection();

        var entity = await db.QueryFirstOrDefaultAsync<DataEntityModel>(@"
            SELECT e.*, a.AssetName, s.SystemCode, s.SystemName,
                   cl.LevelCode AS ClassificationCode, cl.LevelName AS ClassificationName,
                   cl.Color AS ClassificationColor,
                   do_u.DisplayName AS DataOwnerName, ds_u.DisplayName AS DataStewardName,
                   ca.OverallScore AS CriticalityScore
            FROM dcat.DataEntity e
            INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
            INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
            LEFT JOIN dcat.ClassificationLevel cl ON COALESCE(e.ClassificationId, a.ClassificationId) = cl.ClassificationId
            LEFT JOIN dcat.CatalogUser do_u ON e.DataOwnerId = do_u.UserId
            LEFT JOIN dcat.CatalogUser ds_u ON e.DataStewardId = ds_u.UserId
            LEFT JOIN dcat.CriticalityAssessment ca ON e.DataEntityId = ca.DataEntityId
            WHERE e.DataEntityId = @EntityId",
            new { EntityId = entityId });

        if (entity == null) return null;

        entity.Attributes = (await db.QueryAsync<DataAttributeModel>(@"
            SELECT attr.*, bg.TermName AS GlossaryTermName
            FROM dcat.DataAttribute attr
            LEFT JOIN dcat.BusinessGlossary bg ON attr.BusinessGlossaryTermId = bg.TermId
            WHERE attr.DataEntityId = @EntityId AND attr.IsActive = 1
            ORDER BY attr.IsPrimaryKey DESC, attr.AttributeCode",
            new { EntityId = entityId })).ToList();

        entity.Tags = (await db.QueryAsync<string>(@"
            SELECT t.TagName
            FROM dcat.EntityTag et
            INNER JOIN dcat.Tag t ON et.TagId = t.TagId
            WHERE et.TargetEntityType = 'DATA_ENTITY' AND et.TargetEntityId = @EntityId",
            new { EntityId = entityId })).ToList();

        return entity;
    }

    // ========================================================================
    // Dashboard
    // ========================================================================
    public async Task<DashboardModel> GetDashboardAsync()
    {
        using var db = CreateConnection();
        var dashboard = new DashboardModel();

        // Conteggi generali
        var counts = await db.QueryFirstAsync<dynamic>(@"
            SELECT
                (SELECT COUNT(*) FROM dcat.SourceSystem WHERE IsActive = 1) AS TotalSystems,
                (SELECT COUNT(*) FROM dcat.DataAsset WHERE IsActive = 1) AS TotalAssets,
                (SELECT COUNT(*) FROM dcat.DataEntity WHERE IsActive = 1) AS TotalEntities,
                (SELECT COUNT(*) FROM dcat.DataAttribute WHERE IsActive = 1) AS TotalAttributes,
                (SELECT COUNT(*) FROM dcat.EtlPipeline WHERE IsActive = 1) AS TotalPipelines,
                (SELECT COUNT(*) FROM dcat.BusinessGlossary WHERE IsActive = 1) AS TotalGlossaryTerms,
                (SELECT COUNT(*) FROM dcat.WorkflowInstance WHERE Status IN ('PENDING','IN_PROGRESS')) AS PendingWorkflows");

        dashboard.TotalSystems = (int)counts.TotalSystems;
        dashboard.TotalAssets = (int)counts.TotalAssets;
        dashboard.TotalEntities = (int)counts.TotalEntities;
        dashboard.TotalAttributes = (int)counts.TotalAttributes;
        dashboard.TotalPipelines = (int)counts.TotalPipelines;
        dashboard.TotalGlossaryTerms = (int)counts.TotalGlossaryTerms;
        dashboard.PendingWorkflows = (int)counts.PendingWorkflows;

        // GDPR stats
        var gdpr = await db.QueryFirstAsync<dynamic>(@"
            SELECT
                SUM(CASE WHEN ContainsPersonalData = 1 THEN 1 ELSE 0 END) AS WithPersonalData,
                SUM(CASE WHEN ContainsSensitiveData = 1 THEN 1 ELSE 0 END) AS WithSensitiveData,
                SUM(CASE WHEN GdprRelevant = 1 THEN 1 ELSE 0 END) AS GdprRelevant
            FROM dcat.DataEntity WHERE IsActive = 1");

        dashboard.WithPersonalData = (int)(gdpr.WithPersonalData ?? 0);
        dashboard.WithSensitiveData = (int)(gdpr.WithSensitiveData ?? 0);
        dashboard.GdprRelevant = (int)(gdpr.GdprRelevant ?? 0);

        // Classification stats
        dashboard.ByClassification = (await db.QueryAsync<ClassificationStat>(@"
            SELECT cl.LevelCode, cl.LevelName, cl.Color, COUNT(e.DataEntityId) AS EntityCount
            FROM dcat.ClassificationLevel cl
            LEFT JOIN dcat.DataEntity e ON e.ClassificationId = cl.ClassificationId AND e.IsActive = 1
            GROUP BY cl.LevelCode, cl.LevelName, cl.Color, cl.LevelOrder
            ORDER BY cl.LevelOrder")).ToList();

        // Governance status
        var govStats = await db.QueryAsync<dynamic>(@"
            SELECT GovernanceStatus, COUNT(*) AS Cnt
            FROM dcat.DataEntity WHERE IsActive = 1
            GROUP BY GovernanceStatus");
        foreach (var g in govStats)
            dashboard.ByGovernanceStatus[(string)g.GovernanceStatus] = (int)g.Cnt;

        // Criticality
        var critStats = await db.QueryAsync<dynamic>(@"
            SELECT CriticalityLevel, COUNT(*) AS Cnt
            FROM dcat.DataEntity WHERE IsActive = 1 AND CriticalityLevel IS NOT NULL
            GROUP BY CriticalityLevel");
        foreach (var c in critStats)
            dashboard.ByCriticality[(string)c.CriticalityLevel] = (int)c.Cnt;

        return dashboard;
    }

    // ========================================================================
    // Regulatory Reports
    // ========================================================================
    public async Task<IEnumerable<RegulatoryReportModel>> GetRegulatoryReportsAsync()
    {
        using var db = CreateConnection();
        return await db.QueryAsync<RegulatoryReportModel>(@"
            SELECT r.*,
                   (SELECT COUNT(*) FROM dcat.ReportEntityMap rem WHERE rem.ReportId = r.ReportId) AS SourceEntityCount
            FROM dcat.RegulatoryReport r
            WHERE r.IsActive = 1
            ORDER BY
                CASE r.CriticalityLevel WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 ELSE 3 END,
                r.ReportCode");
    }
}
