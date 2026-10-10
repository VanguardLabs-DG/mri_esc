-- =========================================================================
--  vanguard_esc — Server-Side Plugin Registry & Host Controller
-- =========================================================================
-- Extensible plugin registry inspired by mri_Qadmin micro-frontend pattern.
-- Allows internal and external resources to register interactive tabs/apps
-- seamlessly inside vanguard_esc NUI with state preservation (Keep-Alive).
-- =========================================================================

local Plugins = {
    gem_store = {
        id              = 'gem_store',
        label           = 'Loja de Gemas',
        icon            = 'fa-solid fa-gem',
        resource        = 'dp_sistema_gemas',
        htmlPath        = 'esc/index.html',
        category        = 'loja',
        order           = 10,
        badge           = 'LOJA',
        requiredPerms   = {},
        description     = 'Loja oficial de Gemas, Benefícios e Vouchers',
        defaultRoute    = 'plugin:gem_store'
    }
}
local ready = false

---Checks if player has permission to access a plugin
---@param source number
---@param requiredPerms table|nil
---@return boolean
local function HasPluginPerms(source, requiredPerms)
    if not requiredPerms or #requiredPerms == 0 then return true end
    local srcNum = tonumber(source)
    if not srcNum or srcNum <= 0 then return false end
    local srcStr = tostring(srcNum)

    for i = 1, #requiredPerms do
        local perm = requiredPerms[i]
        if perm == 'admin' and IsAdminPlayer(srcNum) then
            return true
        elseif IsPlayerAceAllowed(srcStr, perm) then
            return true
        end
    end
    return false
end

---Filters plugins list for a specific player based on ACE / permissions
---@param source number
---@return table<string, table>
local function GetPluginsForSource(source)
    local visible = {}
    for id, manifest in pairs(Plugins) do
        if HasPluginPerms(source, manifest.requiredPerms) then
            visible[id] = manifest
        end
    end
    return visible
end

---Broadcasts updated plugins list to all connected players (filtered per source)
local function BroadcastPluginsUpdated()
    local players = GetPlayers()
    for i = 1, #players do
        local src = tonumber(players[i])
        if src and src > 0 then
            TriggerClientEvent('vanguard_esc:client:pluginsUpdated', src, GetPluginsForSource(src))
        end
    end
end

---Registers a new plugin in the vanguard_esc host registry
---@param manifest table
---@return boolean success, string|nil reason
local function RegisterPlugin(manifest)
    if type(manifest) ~= 'table' then
        return false, 'invalid_manifest_table'
    end

    if type(manifest.id) ~= 'string' or manifest.id == '' then
        return false, 'invalid_plugin_id'
    end

    local invokingResource = GetInvokingResource() or GetCurrentResourceName()

    local pluginData = {
        id              = manifest.id,
        label           = manifest.label or manifest.id:upper(),
        icon            = manifest.icon or 'fa-solid fa-puzzle-piece',
        resource        = manifest.resource or invokingResource,
        htmlPath        = manifest.htmlPath or 'web/index.html',
        category        = manifest.category or 'plugins',
        order           = tonumber(manifest.order) or 100,
        badge           = manifest.badge or nil,
        requiredPerms   = type(manifest.requiredPerms) == 'table' and manifest.requiredPerms or {},
        description     = manifest.description or '',
        defaultRoute    = manifest.defaultRoute or ('plugin:' .. manifest.id),
        defaultPage     = manifest.defaultPage or nil,
        defaultCategory = manifest.defaultCategory or nil
    }

    Plugins[pluginData.id] = pluginData
    print(string.format("^2[vanguard_esc]^7 Plugin registered: ^3%s^7 from resource ^5%s^7", pluginData.id, pluginData.resource))

    if ready then
        BroadcastPluginsUpdated()
    end

    return true
end

---Unregisters a plugin from the registry
---@param pluginId string
---@return boolean success
local function UnregisterPlugin(pluginId)
    if type(pluginId) ~= 'string' then return false end
    if Plugins[pluginId] then
        Plugins[pluginId] = nil
        print(string.format("^3[vanguard_esc]^7 Plugin unregistered: ^1%s^7", pluginId))
        BroadcastPluginsUpdated()
        return true
    end
    return false
end

-- Official Server Exports
exports('RegisterPlugin', RegisterPlugin)
exports('UnregisterPlugin', UnregisterPlugin)
exports('GetPlugins', function(source)
    return GetPluginsForSource(source or 0)
end)

---Allows server-side code to instruct client to open a registered plugin
---@param source number
---@param pluginId string
---@param opts table|nil
---@return boolean success, string|nil reason
exports('OpenPluginForPlayer', function(source, pluginId, opts)
    local srcNum = tonumber(source)
    if not srcNum or srcNum <= 0 then return false, 'invalid_source' end
    if not Plugins[pluginId] then return false, 'not_registered' end
    if not HasPluginPerms(srcNum, Plugins[pluginId].requiredPerms) then
        return false, 'no_permission'
    end

    TriggerClientEvent('vanguard_esc:client:OpenPlugin', srcNum, pluginId, opts)
    return true
end)

---Allows server-side code to instruct client to close a plugin
---@param source number
---@param pluginId string|nil
---@return boolean success
exports('ClosePluginForPlayer', function(source, pluginId)
    local srcNum = tonumber(source)
    if not srcNum or srcNum <= 0 then return false end
    TriggerClientEvent('vanguard_esc:client:ClosePlugin', srcNum, pluginId)
    return true
end)

---Allows server-side code to toggle a plugin
---@param source number
---@param pluginId string
---@param opts table|nil
---@return boolean success
exports('TogglePluginForPlayer', function(source, pluginId, opts)
    local srcNum = tonumber(source)
    if not srcNum or srcNum <= 0 then return false end
    TriggerClientEvent('vanguard_esc:client:TogglePlugin', srcNum, pluginId, opts)
    return true
end)

-- Server-internal event for resources preferring events over exports (not network-callable by clients)
AddEventHandler('vanguard_esc:server:registerPlugin', function(manifest)
    RegisterPlugin(manifest)
end)

-- Auto-cleanup on resource stop: prevents broken iframes pointing to terminated resources
AddEventHandler('onResourceStop', function(stoppedResource)
    local removedAny = false
    for id, manifest in pairs(Plugins) do
        if manifest.resource == stoppedResource then
            Plugins[id] = nil
            removedAny = true
            print(string.format("^3[vanguard_esc]^7 Cleaned up plugin ^1%s^7 due to resource stop (^5%s^7)", id, stoppedResource))
        end
    end
    if removedAny then
        BroadcastPluginsUpdated()
    end
end)

-- Vanguard Callback for initial plugin hydration on client boot / menu open
local registerCb = (vanguard and vanguard.callback and vanguard.callback.register) or lib.callback.register
registerCb('vanguard_esc:server:getPlugins', function(source)
    return GetPluginsForSource(source)
end)

-- Initialize signal on resource start
CreateThread(function()
    Wait(250)
    ready = true
    print("^2[vanguard_esc]^7 Plugin Host Engine Ready. Broadcasting pluginsReady event...")
    TriggerEvent('vanguard_esc:server:pluginsReady')
    BroadcastPluginsUpdated()
end)
