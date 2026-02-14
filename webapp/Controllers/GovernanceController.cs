using Microsoft.AspNetCore.Mvc;
using GovernedDataCatalog.Services;

namespace GovernedDataCatalog.Controllers;

public class GovernanceController : Controller
{
    private readonly GovernanceService _governanceService;

    public GovernanceController(GovernanceService governanceService)
    {
        _governanceService = governanceService;
    }

    // GET /Governance - Workflow pendenti
    public async Task<IActionResult> Index()
    {
        var workflows = await _governanceService.GetPendingWorkflowsAsync();
        return View(workflows);
    }

    // GET /Governance/Gdpr - Registro trattamenti
    public async Task<IActionResult> Gdpr()
    {
        var activities = await _governanceService.GetGdprActivitiesAsync();
        return View(activities);
    }

    // GET /Governance/Criticality - Matrice di criticità
    public async Task<IActionResult> Criticality()
    {
        var matrix = await _governanceService.GetCriticalityMatrixAsync();
        return View(matrix);
    }
}
