using Microsoft.AspNetCore.Mvc;
using GovernedDataCatalog.Models;
using GovernedDataCatalog.Services;

namespace GovernedDataCatalog.Controllers;

public class CatalogController : Controller
{
    private readonly CatalogService _catalogService;

    public CatalogController(CatalogService catalogService)
    {
        _catalogService = catalogService;
    }

    // GET /Catalog - Navigazione per sistemi sorgente
    public async Task<IActionResult> Index()
    {
        var systems = await _catalogService.GetSourceSystemsAsync();
        return View(systems);
    }

    // GET /Catalog/Assets?sourceSystemId=1
    public async Task<IActionResult> Assets(int? sourceSystemId)
    {
        var assets = await _catalogService.GetDataAssetsAsync(sourceSystemId);
        return View(assets);
    }

    // GET /Catalog/Search
    public async Task<IActionResult> Search(SearchRequest request)
    {
        var results = await _catalogService.SearchEntitiesAsync(request);
        ViewBag.Request = request;
        return View(results);
    }

    // GET /Catalog/Entity/5
    public async Task<IActionResult> Entity(int id)
    {
        var entity = await _catalogService.GetEntityDetailAsync(id);
        if (entity == null) return NotFound();
        return View(entity);
    }

    // GET /Catalog/Regulatory
    public async Task<IActionResult> Regulatory()
    {
        var reports = await _catalogService.GetRegulatoryReportsAsync();
        return View(reports);
    }
}
