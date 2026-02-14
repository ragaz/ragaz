using Microsoft.AspNetCore.Mvc;
using GovernedDataCatalog.Services;

namespace GovernedDataCatalog.Controllers;

public class LineageController : Controller
{
    private readonly LineageService _lineageService;

    public LineageController(LineageService lineageService)
    {
        _lineageService = lineageService;
    }

    // GET /Lineage?entityId=5
    public async Task<IActionResult> Index(int entityId)
    {
        var graph = await _lineageService.GetLineageGraphAsync(entityId);
        return View(graph);
    }

    // GET /Lineage/Pipelines
    public async Task<IActionResult> Pipelines()
    {
        var pipelines = await _lineageService.GetPipelinesAsync();
        return View(pipelines);
    }

    // API endpoint per il grafo (usato da JavaScript)
    [HttpGet]
    public async Task<IActionResult> GraphData(int entityId)
    {
        var graph = await _lineageService.GetLineageGraphAsync(entityId);
        return Json(graph);
    }
}
