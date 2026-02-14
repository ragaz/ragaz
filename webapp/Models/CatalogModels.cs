namespace GovernedDataCatalog.Models;

// ============================================================================
// Modelli principali per il catalogo
// ============================================================================

public class SourceSystemModel
{
    public int SourceSystemId { get; set; }
    public string SystemCode { get; set; } = "";
    public string SystemName { get; set; } = "";
    public string SystemType { get; set; } = "";
    public string? Vendor { get; set; }
    public string? Description { get; set; }
    public string? ConnectionType { get; set; }
    public bool IsActive { get; set; }
    public string? DataOwnerName { get; set; }
    public int AssetCount { get; set; }
    public int EntityCount { get; set; }
}

public class DataAssetModel
{
    public int DataAssetId { get; set; }
    public int SourceSystemId { get; set; }
    public string AssetCode { get; set; } = "";
    public string AssetName { get; set; } = "";
    public string AssetType { get; set; } = "";
    public string? DwhLayer { get; set; }
    public string? RefreshFrequency { get; set; }
    public string? Description { get; set; }
    public string? ClassificationName { get; set; }
    public string? ClassificationColor { get; set; }
    public bool GdprRelevant { get; set; }
    public bool RegulatoryRelevant { get; set; }
    public string? SystemName { get; set; }
    public int EntityCount { get; set; }
}

public class DataEntityModel
{
    public int DataEntityId { get; set; }
    public string EntityCode { get; set; } = "";
    public string EntityName { get; set; } = "";
    public string EntityType { get; set; } = "";
    public string? Description { get; set; }
    public string? BusinessDescription { get; set; }
    public string? DwhLayer { get; set; }
    public string? LoadFrequency { get; set; }
    public string? LoadStrategy { get; set; }
    public string? CriticalityLevel { get; set; }
    public string? GovernanceStatus { get; set; }
    public bool ContainsPersonalData { get; set; }
    public bool ContainsSensitiveData { get; set; }
    public bool ContainsFinancialData { get; set; }
    public bool GdprRelevant { get; set; }
    // From joins
    public string? AssetName { get; set; }
    public string? SystemCode { get; set; }
    public string? SystemName { get; set; }
    public string? ClassificationCode { get; set; }
    public string? ClassificationName { get; set; }
    public string? ClassificationColor { get; set; }
    public string? DataOwnerName { get; set; }
    public string? DataStewardName { get; set; }
    public int? CriticalityScore { get; set; }
    public List<DataAttributeModel> Attributes { get; set; } = new();
    public List<string> Tags { get; set; } = new();
}

public class DataAttributeModel
{
    public int DataAttributeId { get; set; }
    public int DataEntityId { get; set; }
    public string AttributeCode { get; set; } = "";
    public string AttributeName { get; set; } = "";
    public string? DataType { get; set; }
    public int? MaxLength { get; set; }
    public bool IsNullable { get; set; }
    public bool IsPrimaryKey { get; set; }
    public string? Description { get; set; }
    public string? BusinessDescription { get; set; }
    public string? GdprCategory { get; set; }
    public bool IsPersonalData { get; set; }
    public bool IsSensitiveData { get; set; }
    public bool IsDirectIdentifier { get; set; }
    public string? DlpClassification { get; set; }
    public int? RetentionPeriodMonths { get; set; }
    public string? GlossaryTermName { get; set; }
}

// ============================================================================
// Modelli per Lineage
// ============================================================================

public class LineageNodeModel
{
    public int DataEntityId { get; set; }
    public string EntityCode { get; set; } = "";
    public string EntityName { get; set; } = "";
    public string? EntityType { get; set; }
    public string? SystemCode { get; set; }
    public string? SystemName { get; set; }
    public string? DwhLayer { get; set; }
    public string? CriticalityLevel { get; set; }
}

public class LineageEdgeModel
{
    public int SourceEntityId { get; set; }
    public int TargetEntityId { get; set; }
    public string? LineageType { get; set; }
    public string? TransformationType { get; set; }
    public string? PipelineName { get; set; }
}

public class LineageGraphModel
{
    public List<LineageNodeModel> Nodes { get; set; } = new();
    public List<LineageEdgeModel> Edges { get; set; } = new();
    public LineageNodeModel? FocusNode { get; set; }
}

// ============================================================================
// Modelli per Governance
// ============================================================================

public class WorkflowInstanceModel
{
    public int InstanceId { get; set; }
    public string WorkflowCode { get; set; } = "";
    public string WorkflowName { get; set; } = "";
    public string TargetEntityType { get; set; } = "";
    public int TargetEntityId { get; set; }
    public string Status { get; set; } = "";
    public DateTime RequestDate { get; set; }
    public string? RequestNotes { get; set; }
    public string? ChangeDescription { get; set; }
    public string? CurrentStepName { get; set; }
    public string? ApproverRoleName { get; set; }
    public string? RequestedByName { get; set; }
    public int DaysPending { get; set; }
}

public class RegulatoryReportModel
{
    public int ReportId { get; set; }
    public string ReportCode { get; set; } = "";
    public string ReportName { get; set; } = "";
    public string RegulatoryBody { get; set; } = "";
    public string? Regulation { get; set; }
    public string? Frequency { get; set; }
    public string? Deadline { get; set; }
    public string CriticalityLevel { get; set; } = "";
    public string? ResponsibleTeam { get; set; }
    public int SourceEntityCount { get; set; }
}

public class GdprActivityModel
{
    public int ActivityId { get; set; }
    public string ActivityCode { get; set; } = "";
    public string ActivityName { get; set; } = "";
    public string? Description { get; set; }
    public string? BasisName { get; set; }
    public string? GdprArticle { get; set; }
    public string? PurposeName { get; set; }
    public int? RetentionPeriodMonths { get; set; }
    public string Status { get; set; } = "";
    public bool DpiaRequired { get; set; }
    public string? DpiaStatus { get; set; }
}

public class CriticalityAssessmentModel
{
    public int DataEntityId { get; set; }
    public string EntityName { get; set; } = "";
    public int RegulatoryImpact { get; set; }
    public int OperationalImpact { get; set; }
    public int FinancialImpact { get; set; }
    public int ReputationalImpact { get; set; }
    public int GdprImpact { get; set; }
    public int DataLossImpact { get; set; }
    public int OverallScore { get; set; }
    public string? OverallLevel { get; set; }
}

// ============================================================================
// Modelli per Dashboard
// ============================================================================

public class DashboardModel
{
    public int TotalSystems { get; set; }
    public int TotalAssets { get; set; }
    public int TotalEntities { get; set; }
    public int TotalAttributes { get; set; }
    public int TotalPipelines { get; set; }
    public int TotalGlossaryTerms { get; set; }
    public int PendingWorkflows { get; set; }
    public int WithPersonalData { get; set; }
    public int WithSensitiveData { get; set; }
    public int GdprRelevant { get; set; }
    public Dictionary<string, int> ByGovernanceStatus { get; set; } = new();
    public List<ClassificationStat> ByClassification { get; set; } = new();
    public Dictionary<string, int> ByCriticality { get; set; } = new();
    public List<RegulatoryReportModel> RegulatoryReports { get; set; } = new();
    public List<WorkflowInstanceModel> RecentWorkflows { get; set; } = new();
}

public class ClassificationStat
{
    public string LevelCode { get; set; } = "";
    public string LevelName { get; set; } = "";
    public string? Color { get; set; }
    public int EntityCount { get; set; }
}

// ============================================================================
// Modelli per ricerca
// ============================================================================

public class SearchRequest
{
    public string? SearchTerm { get; set; }
    public string? EntityType { get; set; }
    public string? SystemCode { get; set; }
    public string? DwhLayer { get; set; }
    public string? Classification { get; set; }
    public bool GdprOnly { get; set; }
    public bool CriticalOnly { get; set; }
}
