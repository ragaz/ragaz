using System.Data;
using Microsoft.Data.SqlClient;
using Dapper;
using GovernedDataCatalog.Models;

namespace GovernedDataCatalog.Services;

public class LineageService
{
    private readonly string _connectionString;

    public LineageService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DataCatalog")!;
    }

    private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

    public async Task<LineageGraphModel> GetLineageGraphAsync(int entityId)
    {
        using var db = CreateConnection();
        var graph = new LineageGraphModel();

        // Nodo focus
        graph.FocusNode = await db.QueryFirstOrDefaultAsync<LineageNodeModel>(@"
            SELECT e.DataEntityId, e.EntityCode, e.EntityName, e.EntityType,
                   s.SystemCode, s.SystemName, e.DwhLayer, e.CriticalityLevel
            FROM dcat.DataEntity e
            INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
            INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
            WHERE e.DataEntityId = @EntityId",
            new { EntityId = entityId });

        if (graph.FocusNode == null) return graph;

        // Upstream (2 livelli)
        var upstream = await db.QueryAsync<dynamic>(@"
            ;WITH Up AS (
                SELECT el.SourceEntityId, el.TargetEntityId, el.LineageType, el.TransformationType,
                       p.PipelineName, 1 AS Depth
                FROM dcat.EntityLineage el
                LEFT JOIN dcat.EtlPipeline p ON el.PipelineId = p.PipelineId
                WHERE el.TargetEntityId = @EntityId AND el.IsActive = 1
                UNION ALL
                SELECT el2.SourceEntityId, el2.TargetEntityId, el2.LineageType, el2.TransformationType,
                       p2.PipelineName, u.Depth + 1
                FROM Up u
                INNER JOIN dcat.EntityLineage el2 ON u.SourceEntityId = el2.TargetEntityId
                LEFT JOIN dcat.EtlPipeline p2 ON el2.PipelineId = p2.PipelineId
                WHERE el2.IsActive = 1 AND u.Depth < 5
            )
            SELECT DISTINCT SourceEntityId, TargetEntityId, LineageType, TransformationType, PipelineName
            FROM Up", new { EntityId = entityId });

        // Downstream (2 livelli)
        var downstream = await db.QueryAsync<dynamic>(@"
            ;WITH Down AS (
                SELECT el.SourceEntityId, el.TargetEntityId, el.LineageType, el.TransformationType,
                       p.PipelineName, 1 AS Depth
                FROM dcat.EntityLineage el
                LEFT JOIN dcat.EtlPipeline p ON el.PipelineId = p.PipelineId
                WHERE el.SourceEntityId = @EntityId AND el.IsActive = 1
                UNION ALL
                SELECT el2.SourceEntityId, el2.TargetEntityId, el2.LineageType, el2.TransformationType,
                       p2.PipelineName, d.Depth + 1
                FROM Down d
                INNER JOIN dcat.EntityLineage el2 ON d.TargetEntityId = el2.SourceEntityId
                LEFT JOIN dcat.EtlPipeline p2 ON el2.PipelineId = p2.PipelineId
                WHERE el2.IsActive = 1 AND d.Depth < 5
            )
            SELECT DISTINCT SourceEntityId, TargetEntityId, LineageType, TransformationType, PipelineName
            FROM Down", new { EntityId = entityId });

        // Raccogli tutti gli ID nodo
        var nodeIds = new HashSet<int> { entityId };
        foreach (var e in upstream.Concat(downstream))
        {
            nodeIds.Add((int)e.SourceEntityId);
            nodeIds.Add((int)e.TargetEntityId);
        }

        // Carica nodi
        if (nodeIds.Count > 0)
        {
            graph.Nodes = (await db.QueryAsync<LineageNodeModel>(@"
                SELECT e.DataEntityId, e.EntityCode, e.EntityName, e.EntityType,
                       s.SystemCode, s.SystemName, e.DwhLayer, e.CriticalityLevel
                FROM dcat.DataEntity e
                INNER JOIN dcat.DataAsset a ON e.DataAssetId = a.DataAssetId
                INNER JOIN dcat.SourceSystem s ON a.SourceSystemId = s.SourceSystemId
                WHERE e.DataEntityId IN @Ids",
                new { Ids = nodeIds.ToArray() })).ToList();
        }

        // Edges
        foreach (var e in upstream.Concat(downstream))
        {
            graph.Edges.Add(new LineageEdgeModel
            {
                SourceEntityId = (int)e.SourceEntityId,
                TargetEntityId = (int)e.TargetEntityId,
                LineageType = (string?)e.LineageType,
                TransformationType = (string?)e.TransformationType,
                PipelineName = (string?)e.PipelineName
            });
        }

        return graph;
    }

    public async Task<IEnumerable<dynamic>> GetPipelinesAsync()
    {
        using var db = CreateConnection();
        return await db.QueryAsync<dynamic>(@"
            SELECT p.*,
                   (SELECT COUNT(*) FROM dcat.EtlPipelineStep s WHERE s.PipelineId = p.PipelineId) AS StepCount,
                   (SELECT TOP 1 ex.Status FROM dcat.EtlExecution ex
                    WHERE ex.PipelineId = p.PipelineId ORDER BY ex.StartTime DESC) AS LastStatus,
                   (SELECT TOP 1 ex.StartTime FROM dcat.EtlExecution ex
                    WHERE ex.PipelineId = p.PipelineId ORDER BY ex.StartTime DESC) AS LastRunTime
            FROM dcat.EtlPipeline p
            WHERE p.IsActive = 1
            ORDER BY
                CASE p.CriticalityLevel WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 ELSE 3 END,
                p.PipelineName");
    }
}
