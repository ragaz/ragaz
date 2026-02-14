using System.Data;
using Microsoft.Data.SqlClient;
using Dapper;
using GovernedDataCatalog.Models;

namespace GovernedDataCatalog.Services;

public class GovernanceService
{
    private readonly string _connectionString;

    public GovernanceService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DataCatalog")!;
    }

    private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

    public async Task<IEnumerable<WorkflowInstanceModel>> GetPendingWorkflowsAsync()
    {
        using var db = CreateConnection();
        return await db.QueryAsync<WorkflowInstanceModel>(@"
            SELECT wi.InstanceId, wd.WorkflowCode, wd.WorkflowName,
                   wi.TargetEntityType, wi.TargetEntityId, wi.Status,
                   wi.RequestDate, wi.RequestNotes, wi.ChangeDescription,
                   ws.StepName AS CurrentStepName,
                   gr.RoleName AS ApproverRoleName,
                   ru.DisplayName AS RequestedByName,
                   DATEDIFF(DAY, wi.RequestDate, SYSUTCDATETIME()) AS DaysPending
            FROM dcat.WorkflowInstance wi
            INNER JOIN dcat.WorkflowDefinition wd ON wi.WorkflowId = wd.WorkflowId
            LEFT JOIN dcat.WorkflowStep ws ON wi.CurrentStepId = ws.WorkflowStepId
            LEFT JOIN dcat.GovernanceRole gr ON ws.ApproverRoleId = gr.RoleId
            INNER JOIN dcat.CatalogUser ru ON wi.RequestedBy = ru.UserId
            WHERE wi.Status IN ('PENDING','IN_PROGRESS')
            ORDER BY wi.RequestDate DESC");
    }

    public async Task<IEnumerable<GdprActivityModel>> GetGdprActivitiesAsync()
    {
        using var db = CreateConnection();
        return await db.QueryAsync<GdprActivityModel>(@"
            SELECT pa.ActivityId, pa.ActivityCode, pa.ActivityName, pa.Description,
                   lb.BasisName, lb.GdprArticle,
                   pp.PurposeName, pp.RetentionPeriodMonths,
                   pa.Status, pa.DpiaRequired, pa.DpiaStatus
            FROM dcat.GdprProcessingActivity pa
            LEFT JOIN dcat.GdprLegalBasis lb ON pa.LegalBasisId = lb.LegalBasisId
            LEFT JOIN dcat.GdprProcessingPurpose pp ON pa.PurposeId = pp.PurposeId
            ORDER BY pa.ActivityName");
    }

    public async Task<IEnumerable<CriticalityAssessmentModel>> GetCriticalityMatrixAsync()
    {
        using var db = CreateConnection();
        return await db.QueryAsync<CriticalityAssessmentModel>(@"
            SELECT ca.DataEntityId, e.EntityName,
                   ca.RegulatoryImpact, ca.OperationalImpact, ca.FinancialImpact,
                   ca.ReputationalImpact, ca.GdprImpact, ca.DataLossImpact,
                   ca.OverallScore, ca.OverallLevel
            FROM dcat.CriticalityAssessment ca
            INNER JOIN dcat.DataEntity e ON ca.DataEntityId = e.DataEntityId
            WHERE e.IsActive = 1
            ORDER BY ca.OverallScore DESC");
    }
}
