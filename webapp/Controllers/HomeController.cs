using Microsoft.AspNetCore.Mvc;
using GovernedDataCatalog.Services;

namespace GovernedDataCatalog.Controllers;

public class HomeController : Controller
{
    private readonly CatalogService _catalogService;

    public HomeController(CatalogService catalogService)
    {
        _catalogService = catalogService;
    }

    public async Task<IActionResult> Index()
    {
        var dashboard = await _catalogService.GetDashboardAsync();
        return View(dashboard);
    }

    public IActionResult Error()
    {
        return View();
    }
}
