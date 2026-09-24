#define WLR_USE_UNSTABLE

#include <unistd.h>

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowQuery.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/view/WLSurface.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/config/ConfigManager.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/lua/bindings/LuaBindingsInternal.hpp>

#include "globals.hpp"

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#include <algorithm>
#include <cctype>
#include <hyprutils/string/ConstVarList.hpp>
using namespace Hyprutils::String;

inline CFunctionHook* g_pMouseMotionHook     = nullptr;
inline CFunctionHook* g_pSurfaceSizeHook     = nullptr;
inline CFunctionHook* g_pWLSurfaceDamageHook = nullptr;
inline CFunctionHook* g_pSmallHook           = nullptr;
typedef void (*origMotion)(CSeatManager*, uint32_t, const Vector2D&);
typedef void (*origSurfaceSize)(CXWaylandSurface*, const CBox&);
typedef CRegion (*origWLSurfaceDamage)(Desktop::View::CWLSurface*);
typedef bool (*origSmall)(Desktop::View::CWLSurface*);

static struct {
    SP<Config::Values::CBoolValue> fixMouse;
} configValues;

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

struct SAppConfig {
    std::string szClass;
    Vector2D    res;
};

std::vector<SAppConfig> g_appConfigs;

static std::string lowerCopy(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return (char)std::tolower(c); });
    return s;
}

static const SAppConfig* getAppConfig(const std::string& appClass) {
    if (appClass.empty())
        return nullptr;

    const auto lower = lowerCopy(appClass);
    // Steam CEF is class "steam". Never remap its pointer or force 1920x1080.
    if (lower == "steam" || lower.find("steamwebhelper") != std::string::npos)
        return nullptr;
    for (const auto& ac : g_appConfigs) {
        const auto acLower = lowerCopy(ac.szClass);
        if (acLower == lower)
            return &ac;
        // Class may be "steam_app_2357570" while we registered that id.
        // Never the reverse: class "steam" must not match "steam_app_*".
        if (acLower.size() >= 8 && lower.find(acLower) != std::string::npos)
            return &ac;
    }
    return nullptr;
}

static PHLWINDOW windowFromX(CXWaylandSurface* surface, const auto& cwl) {
    if (cwl) {
        if (const auto w = Desktop::View::CWindow::fromView(cwl->view()))
            return w;
    }
    if (!surface)
        return nullptr;
    for (const auto& w : Desktop::windowState()->windows()) {
        if (w && w->m_xwaylandSurface.lock().get() == surface)
            return w;
    }
    return nullptr;
}

static const SAppConfig* configFor(PHLWINDOW window, CXWaylandSurface* surface) {
    if (window) {
        if (const auto c = getAppConfig(window->m_initialClass))
            return c;
        if (const auto c = getAppConfig(window->m_class))
            return c;
        if (const auto c = getAppConfig(window->m_title))
            return c;
        if (const auto c = getAppConfig(window->m_initialTitle))
            return c;
    }
    if (surface) {
        if (const auto c = getAppConfig(surface->m_state.appid))
            return c;
        if (const auto c = getAppConfig(surface->m_state.title))
            return c;
    }
    return nullptr;
}

static void markFill(const auto& surf) {
    const auto cwl = Desktop::View::CWLSurface::fromResource(surf);
    if (cwl)
        cwl->m_fillIgnoreSmall = true;
}

void hkNotifyMotion(CSeatManager* thisptr, uint32_t time_msec, const Vector2D& local) {
    Vector2D   newCoords  = local;
    auto       focusState = Desktop::focusState();
    auto       window     = focusState->window();
    const auto CONFIG     = window ? configFor(window, nullptr) : nullptr;

    if (configValues.fixMouse->value() && CONFIG && window) {
        // Window pixels → fake 1920×1080. Do not also divide by
        // m_X11SurfaceScaledBy: force_zero_scaling already keeps that at 1,
        // and when it is the stretch factor the extra divide walks the
        // cursor left as x grows (left edge OK, right misses left).
        const CBox box = window->getWindowMainSurfaceBox();
        if (box.w > CONFIG->res.x + 2.0 && box.h > 1.0) {
            newCoords.x *= CONFIG->res.x / box.w;
            newCoords.y *= CONFIG->res.y / box.h;
        }
    }

    (*(origMotion)g_pMouseMotionHook->m_original)(thisptr, time_msec, newCoords);
}

void hkSetWindowSize(CXWaylandSurface* surface, const CBox& box) {
    if (!surface) {
        (*(origSurfaceSize)g_pSurfaceSizeHook->m_original)(surface, box);
        return;
    }

    const auto SURF    = surface->m_surface.lock();
    const auto CWLSURF = Desktop::View::CWLSurface::fromResource(SURF);
    const auto PWINDOW = windowFromX(surface, CWLSURF);

    CBox       newBox = box;
    if (const auto CONFIG = configFor(PWINDOW, surface); CONFIG) {
        newBox.w = CONFIG->res.x;
        newBox.h = CONFIG->res.y;
        markFill(SURF);
        if (CWLSURF)
            CWLSURF->m_fillIgnoreSmall = true;
    }

    (*(origSurfaceSize)g_pSurfaceSizeHook->m_original)(surface, newBox);
}

bool hkSmall(Desktop::View::CWLSurface* thisptr) {
    if (thisptr && thisptr->m_fillIgnoreSmall)
        return false;
    const auto WINDOW = thisptr ? Desktop::View::CWindow::fromView(thisptr->view()) : nullptr;
    if (configFor(WINDOW, nullptr))
        return false;
    return (*(origSmall)g_pSmallHook->m_original)(thisptr);
}

CRegion hkWLSurfaceDamage(Desktop::View::CWLSurface* thisptr) {
    const auto RG = (*(origWLSurfaceDamage)g_pWLSurfaceDamageHook->m_original)(thisptr);

    if (thisptr->exists() && Desktop::View::CWindow::fromView(thisptr->view())) {
        const auto WINDOW = Desktop::View::CWindow::fromView(thisptr->view());
        const auto CONFIG = configFor(WINDOW, nullptr);

        if (CONFIG) {
            thisptr->m_fillIgnoreSmall = true;
            // damageMonitor redrew the whole ultrawide every OW frame and
            // hitch'd 1% lows at 200Hz. Window damage is enough for stretch.
            g_pHyprRenderer->damageWindow(WINDOW);
        }
    }

    return RG;
}

int vkfixAppLua(lua_State* L) {
    if (!lua_istable(L, 1))
        return Config::Lua::Bindings::Internal::configError(L, "vkfix_app: expected a table { app, w, h }");

    SAppConfig config;

    {
        Hyprutils::Utils::CScopeGuard x([L] { lua_pop(L, 1); });

        lua_getfield(L, 1, "app");

        if (!lua_isstring(L, -1))
            return Config::Lua::Bindings::Internal::configError(L, "vkfix_app: app must be a class string");

        config.szClass = lua_tostring(L, -1);
    }

    {
        Hyprutils::Utils::CScopeGuard x([L] { lua_pop(L, 1); });

        lua_getfield(L, 1, "w");

        if (!lua_isinteger(L, -1))
            return Config::Lua::Bindings::Internal::configError(L, "vkfix_app: w must be an integer");

        config.res.x = lua_tointeger(L, -1);
    }

    {
        Hyprutils::Utils::CScopeGuard x([L] { lua_pop(L, 1); });

        lua_getfield(L, 1, "h");

        if (!lua_isinteger(L, -1))
            return Config::Lua::Bindings::Internal::configError(L, "vkfix_app: h must be an integer");

        config.res.y = lua_tointeger(L, -1);
    }

    const auto want = lowerCopy(config.szClass);
    for (auto& ac : g_appConfigs) {
        if (lowerCopy(ac.szClass) == want) {
            ac = std::move(config);
            return 0;
        }
    }
    g_appConfigs.emplace_back(std::move(config));

    return 0;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    const std::string HASH        = __hyprland_api_get_hash();
    const std::string CLIENT_HASH = __hyprland_api_get_client_hash();

    if (HASH != CLIENT_HASH) {
        HyprlandAPI::addNotification(PHANDLE, "[csgo-vulkan-fix] Failure in initialization: Version mismatch (headers ver is not equal to running hyprland ver)",
                                     CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[vkfix] Version mismatch");
    }

    static auto P = Event::bus()->m_events.config.preReload.listen([&] { g_appConfigs.clear(); });

    if (Config::mgr()->type() == Config::CONFIG_LEGACY) {
        HyprlandAPI::addConfigKeyword(
            PHANDLE, "vkfix-app",
            [](const char* l, const char* r) -> Hyprlang::CParseResult {
                const std::string      str = r;
                CConstVarList          data(str, 0, ',', true);

                Hyprlang::CParseResult result;

                if (data.size() != 3) {
                    result.setError("vkfix-app requires 3 params");
                    return result;
                }

                try {
                    SAppConfig config;
                    config.szClass = data[0];
                    config.res     = Vector2D{std::stoi(std::string{data[1]}), std::stoi(std::string{data[2]})};
                    g_appConfigs.emplace_back(std::move(config));
                } catch (std::exception& e) {
                    result.setError("failed to parse line");
                    return result;
                }

                return result;
            },
            Hyprlang::SHandlerOptions{});
    } else if (Config::mgr()->type() == Config::CONFIG_LUA) {
        HyprlandAPI::addLuaFunction(PHANDLE, "csgo_vulkan_fix", "vkfix_app", ::vkfixAppLua);
    } else {
        HyprlandAPI::addNotification(PHANDLE, "[csgo-vulkan-fix] Failure in initialization: Failed to get a valid config manager", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[vkfix] Config manager bad");
    }

    configValues.fixMouse =
        makeShared<Config::Values::CBoolValue>("plugin:csgo_vulkan_fix:fix_mouse", "Whether to fix the mouse position. A select few apps might be wonky with this.", true);
    HyprlandAPI::addConfigValueV2(PHANDLE, configValues.fixMouse);

    auto FNS = HyprlandAPI::findFunctionsByName(PHANDLE, "sendPointerMotion");
    for (auto& fn : FNS) {
        if (!fn.demangled.contains("CSeatManager"))
            continue;

        g_pMouseMotionHook = HyprlandAPI::createFunctionHook(PHANDLE, fn.address, (void*)::hkNotifyMotion);
        break;
    }

    FNS = HyprlandAPI::findFunctionsByName(PHANDLE, "configure");
    for (auto& fn : FNS) {
        if (!fn.demangled.contains("XWaylandSurface"))
            continue;

        g_pSurfaceSizeHook = HyprlandAPI::createFunctionHook(PHANDLE, fn.address, (void*)::hkSetWindowSize);
        break;
    }

    FNS = HyprlandAPI::findFunctionsByName(PHANDLE, "computeDamage");
    for (auto& r : FNS) {
        if (!r.demangled.contains("CWLSurface"))
            continue;

        g_pWLSurfaceDamageHook = HyprlandAPI::createFunctionHook(PHANDLE, r.address, (void*)::hkWLSurfaceDamage);
        break;
    }

    FNS = HyprlandAPI::findFunctionsByName(PHANDLE, "small");
    for (auto& r : FNS) {
        if (!r.demangled.contains("CWLSurface"))
            continue;

        g_pSmallHook = HyprlandAPI::createFunctionHook(PHANDLE, r.address, (void*)::hkSmall);
        break;
    }

    bool success = g_pSurfaceSizeHook && g_pWLSurfaceDamageHook && g_pMouseMotionHook;
    if (!success) {
        HyprlandAPI::addNotification(PHANDLE, "[csgo-vulkan-fix] Failure in initialization: Failed to find required hook fns", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[vkfix] Hooks fn init failed");
    }

    success = success && g_pWLSurfaceDamageHook->hook();
    success = success && g_pMouseMotionHook->hook();
    success = success && g_pSurfaceSizeHook->hook();
    if (g_pSmallHook)
        success = success && g_pSmallHook->hook();

    if (success)
        HyprlandAPI::addNotification(PHANDLE, "[csgo-vulkan-fix] Initialized successfully! (Anything version)", CHyprColor{0.2, 1.0, 0.2, 1.0}, 5000);
    else {
        HyprlandAPI::addNotification(PHANDLE, "[csgo-vulkan-fix] Failure in initialization (hook failed)!", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[csgo-vk-fix] Hooks failed");
    }

    return {"csgo-vulkan-fix", "A plugin to force specific apps to a fake resolution", "Vaxry", "1.2"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    configValues = {};
}
