-- =========================================================================
--  vanguard_esc — Client-Side Plugin Controller & Bridge
-- =========================================================================
-- Manages plugin state on client, transmits plugin lists to NUI,
-- handles navigation / focus delegation, and provides public exports.
-- =========================================================================

local cachedPlugins = {}
local pluginsFetched = false
local currentRoute = nil
local openedRoutes = {}

---Fetches and caches the available plugins for this player
---@return table<string, table>
local function GetPlugins()
    if not pluginsFetched then
        local awaitCb = (vanguard and vanguard.callback and vanguard.callback.await) or function(name) return lib.callback.await(name, false) end
        local p = awaitCb('vanguard_esc:server:getPlugins')
        cachedPlugins = p or {}
        pluginsFetched = true
    end
    return cachedPlugins
end

---Receives server-side plugin updates and forwards them to NUI
RegisterNetEvent('vanguard_esc:client:pluginsUpdated', function(plugins)
    cachedPlugins = plugins or {}
    pluginsFetched = true
    SendNUIMessage({
        action = 'pluginsUpdated',
        data = { plugins = cachedPlugins }
    })
end)

---Resolves target route, page, and category for a plugin
---@param pluginId string
---@param opts table|nil { route?: string, page?: string, category?: string, focus?: string }
---@return string|nil route, string|nil page, string|nil category, string|nil focus
local function ResolveTarget(pluginId, opts)
    local plugins = GetPlugins()
    local manifest = plugins[pluginId]
    if not manifest then return nil end

    opts = type(opts) == 'table' and opts or {}
    local route = opts.route or manifest.defaultRoute or ('plugin:' .. pluginId)
    local page = opts.page or manifest.defaultPage
    local category = opts.category or manifest.defaultCategory
    local focus = opts.focus

    return route, page, category, focus
end

---Opens a registered plugin tab inside vanguard_esc
---@param pluginId string
---@param opts table|nil
---@return boolean success, string|nil reason
local function OpenPlugin(pluginId, opts)
    if type(pluginId) ~= 'string' or pluginId == '' then
        return false, 'invalid_id'
    end

    local route, page, category, focus = ResolveTarget(pluginId, opts)
    if not route then
        print(string.format("^1[vanguard_esc]^7 Cannot open unknown plugin: %s", pluginId))
        return false, 'not_registered'
    end

    openedRoutes[pluginId] = route

    -- If menu is not open, open it directly on this plugin tab
    if not open then
        if OpenMenu then
            OpenMenu(route)
        else
            ExecuteCommand("open_menu")
        end
    end

    SendNUIMessage({
        action = 'navigate',
        data = {
            route = route,
            pluginId = pluginId,
            page = page,
            category = category,
            focus = focus
        }
    })

    return true
end

---Closes the menu or active plugin tab
---@param pluginId string|nil
---@return boolean success, string|nil reason
local function ClosePlugin(pluginId)
    if not open then return false, 'already_closed' end

    if pluginId then
        local route = openedRoutes[pluginId] or ('plugin:' .. pluginId)
        if currentRoute ~= route then
            return false, 'not_active'
        end
    end

    if closeMenu then
        closeMenu()
    end
    openedRoutes = {}
    return true
end

---Toggles plugin open/close state
---@param pluginId string
---@param opts table|nil
---@return boolean success
local function TogglePlugin(pluginId, opts)
    if type(pluginId) ~= 'string' or pluginId == '' then return false end
    local route = openedRoutes[pluginId] or ('plugin:' .. pluginId)
    if open and currentRoute == route then
        return ClosePlugin(pluginId)
    end
    return OpenPlugin(pluginId, opts)
end

---Checks whether a plugin tab is currently open and visible
---@param pluginId string
---@return boolean
local function IsPluginOpen(pluginId)
    if not open or type(pluginId) ~= 'string' then return false end
    local route = openedRoutes[pluginId] or ('plugin:' .. pluginId)
    return currentRoute == route
end

-- Client Exports
exports('OpenPlugin', OpenPlugin)
exports('ClosePlugin', ClosePlugin)
exports('TogglePlugin', TogglePlugin)
exports('IsPluginOpen', IsPluginOpen)
exports('GetPlugins', GetPlugins)

-- NetEvents for Server-Driven actions
RegisterNetEvent('vanguard_esc:client:OpenPlugin', function(pluginId, opts)
    OpenPlugin(pluginId, opts)
end)

RegisterNetEvent('vanguard_esc:client:ClosePlugin', function(pluginId)
    ClosePlugin(pluginId)
end)

RegisterNetEvent('vanguard_esc:client:TogglePlugin', function(pluginId, opts)
    TogglePlugin(pluginId, opts)
end)

-- NUI Callbacks
RegisterNUICallback('getPlugins', function(_, cb)
    cb(GetPlugins())
end)

RegisterNUICallback('routeChanged', function(data, cb)
    if type(data) == 'table' and type(data.route) == 'string' then
        currentRoute = data.route
    end
    if cb then cb({ status = 'ok' }) end
end)
