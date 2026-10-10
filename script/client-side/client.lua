-- =============================================================
--  mri_esc — Main Client Entry Point
-- =============================================================

local Config = Config or {}
open = false
isNativeMapOpen = false
lastMapClose = 0
redesSociais = { instagram = "", tiktok = "", youtube = "" }
local cachedTabs = nil

-- Initial Load
print("[vanguard_esc] Client Scripts Loaded")
CreateThread(function()
    local savedRedes = GetResourceKvpString("mri_esc:redes")
    if savedRedes then
        local ok, decoded = pcall(json.decode, savedRedes)
        if ok and decoded then redesSociais = decoded end
    end
end)

-- ── HELPERS ─────────────────────────────────────────────────

local function GetPlayerData()
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:GetPlayerData()
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.GetPlayerData()
    end
    return nil
end

local function GetPlayersOnline()
    if GetResourceState('ox_lib') == 'started' then
        return lib.callback.await('mri_esc:server:getPlayersOnline', false) or 1
    end
    return 1
end

local function BuildTabsConfig()
    local defaultTabs = {
        { id = 'inicio', label = 'INÍCIO', icon = 'fa-bars', action = 'inicio' },
        { id = 'mapa', label = 'MAPA', icon = 'fa-map', action = 'mapa' },
        { id = 'customizacao', label = 'CUSTOMIZAÇÃO', icon = 'fa-user', action = 'customizacao' },
        { id = 'config', label = 'CONFIGURAÇÕES', icon = 'fa-cog', action = 'config' }
    }
    if Config.Tabs then
        for _, tab in ipairs(Config.Tabs) do table.insert(defaultTabs, tab) end
    end
    return defaultTabs
end

local function GetCachedTabs()
    if not cachedTabs then cachedTabs = BuildTabsConfig() end
    return cachedTabs
end

-- ── MAIN LOGIC ──────────────────────────────────────────────

function closeMenu(ignoreFrontend)
    open = false
    SendNUIMessage({ action = "hideMenu" })
    StopScreenEffect("MenuMGSelectionIn")
    StopAllScreenEffects()
    TriggerEvent("hud:Active", true)
    SetNuiFocus(false, false)
    if not ignoreFrontend then
        SetFrontendActive(false)
    end
end

function OpenMenu(targetTab)
    if isNativeMapOpen or IsPauseMenuActive() or (GetGameTimer() - (lastMapClose or 0) < 300) then
        return
    end

    if not LocalPlayer.state.isLoggedIn or LocalPlayer.state.inArena or LocalPlayer.state.isDead or LocalPlayer.state.invOpen then
        return
    end

    SetFrontendActive(false)

    if open then
        if targetTab then
            SendNUIMessage({
                action = "navigate",
                data = { route = targetTab }
            })
        else
            closeMenu()
        end
        return
    end

    local playersOn = GetPlayersOnline()
    local playerData = GetPlayerData()
    local vipData = nil
    pcall(function()
        vipData = lib.callback.await('mri_esc:server:getVipData', 1500)
    end)

    local nome = "Jogador"
    local id = GetPlayerServerId(PlayerId())
    local money, bank = 0, 0
    local jobText = "Desempregado"

    if playerData then
        nome = (playerData.charinfo and (playerData.charinfo.firstname .. " " .. playerData.charinfo.lastname)) or nome
        id = playerData.citizenid or id
        if playerData.money then
            money = playerData.money.cash or 0
            bank = playerData.money.bank or 0
        end
        if playerData.job then
            local jName = playerData.job.label or "Desempregado"
            local jGrade = (playerData.job.grade and playerData.job.grade.name) or ""
            jobText = jGrade ~= "" and (jName .. " - " .. jGrade) or jName
        end
    end

    local coins = 0
    if LocalPlayer and LocalPlayer.state then
        if LocalPlayer.state.coins ~= nil and tonumber(LocalPlayer.state.coins) then
            coins = tonumber(LocalPlayer.state.coins)
        elseif LocalPlayer.state.vipCoins ~= nil and tonumber(LocalPlayer.state.vipCoins) then
            coins = tonumber(LocalPlayer.state.vipCoins)
        end
    end
    if coins == 0 and playerData and playerData.money and playerData.money.coin then
        coins = tonumber(playerData.money.coin) or 0
    end
    if coins == 0 and vipData and vipData.coins then
        coins = tonumber(vipData.coins) or 0
    end

    local gems = 0
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.gems ~= nil and tonumber(LocalPlayer.state.gems) then
        gems = tonumber(LocalPlayer.state.gems)
    end
    if gems == 0 and playerData and playerData.money and playerData.money.gems then
        gems = tonumber(playerData.money.gems) or 0
    end
    if gems == 0 and vipData and vipData.gems then
        gems = tonumber(vipData.gems) or 0
    end

    local isAdmin = vipData and vipData.isAdmin == true
    local coords = GetEntityCoords(PlayerPedId())

    -- Localização formatada (rua e bairro) via vanguard.geo.getStreetZone com fallback
    local location = "Distrito Paulista"
    local zone = nil
    if vanguard and vanguard.geo and vanguard.geo.getStreetZone then
        local ok, res = pcall(vanguard.geo.getStreetZone, coords)
        if ok and res and res ~= "" and res ~= "NULL" then
            zone = res
        end
    elseif GetResourceState('vanguard_lib') == 'started' then
        local ok, res = pcall(function()
            return exports['vanguard_lib']:FindLastLocation(coords)
        end)
        if ok and res and res ~= "" and res ~= "NULL" then
            zone = res
        end
    end

    if zone then
        local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = streetHash and GetStreetNameFromHashKey(streetHash)
        if streetName and streetName ~= "" and not string.find(zone, streetName, 1, true) then
            location = string.format("%s, %s", streetName, zone)
        else
            location = zone
        end
    end

    -- Sincronizar mira persistida no Qbox se disponível
    if playerData and playerData.metadata and (playerData.metadata.mira or playerData.metadata.crosshair) then
        if CheckQboxMiraPersistence then
            CheckQboxMiraPersistence(playerData)
        elseif SyncMiraFromData then
            SyncMiraFromData(playerData.metadata.mira or playerData.metadata.crosshair)
        end
    end

    SendNUIMessage({
        action     = "showMenu",
        playersOn  = playersOn,
        nome       = nome,
        id         = id,
        avatar     = vipData and vipData.avatar,
        location   = location,
        money      = money,
        bank       = bank,
        gems       = gems,
        coins      = coins,
        job        = jobText,
        vip        = vipData,
        isAdmin    = isAdmin,
        playerX    = coords.x,
        playerY    = coords.y,
        tabs       = GetCachedTabs(),
        initialTab = targetTab or "inicio"
    })

    if isAdmin then TriggerEvent('mri_esc:client:adminReady') end

    Wait(50)
    SetNuiFocus(true, true)
    StartScreenEffect("MenuMGSelectionIn", 0, true)
    TriggerEvent("hud:Active", false)
    open = true
end

-- ── NUI CALLBACKS ───────────────────────────────────────────

local function handleSaveMira(data, cb)
    if data then
        if SyncMiraFromData then
            SyncMiraFromData(data)
        elseif exports[GetCurrentResourceName()] and exports[GetCurrentResourceName()].SetMiraConfig then
            exports[GetCurrentResourceName()]:SetMiraConfig(data)
        else
            miraConfig = data
            SetResourceKvp("mri_esc:mira", json.encode(data))
            SendNUIMessage({ action = "miraData", mira = data })
        end
        TriggerServerEvent('mri_esc:server:saveMira', data)
    end
    if cb then cb({ success = true }) end
end

RegisterNUICallback('saveMira', handleSaveMira)
RegisterNUICallback('salvarMira', handleSaveMira)

RegisterCommand("open_menu", function()
    if isNativeMapOpen or IsPauseMenuActive() then
        SetFrontendActive(false)
        lastMapClose = GetGameTimer()
        isNativeMapOpen = false
        return
    end

    if open then
        closeMenu()
        return
    end

    if GetGameTimer() - (lastMapClose or 0) < 300 then
        return
    end

    SetFrontendActive(false)
    OpenMenu()
end)

RegisterKeyMapping("open_menu", "Abrir Esc Menu", "keyboard", "ESCAPE")

RegisterNetEvent('mri_esc:client:refreshVip', function()
    if open then
        local vipData = nil
        pcall(function()
            vipData = lib.callback.await('mri_esc:server:getVipData', 1500)
        end)
        local gems = (LocalPlayer and LocalPlayer.state and LocalPlayer.state.gems) or (vipData and vipData.gems) or 0
        local coins = (LocalPlayer and LocalPlayer.state and (LocalPlayer.state.coins or LocalPlayer.state.vipCoins)) or (vipData and vipData.coins) or 0
        SendNUIMessage({
            action = "updateVipData",
            vip = vipData,
            gems = gems,
            coins = coins
        })
    end
end)

-- Real-time Gems statebag synchronization
AddStateBagChangeHandler('gems', nil, function(bagName, key, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == PlayerId() and open then
        SendNUIMessage({
            action = "updateGems",
            gems = tonumber(value) or 0
        })
    end
end)

-- Real-time Coins statebag synchronization
AddStateBagChangeHandler('coins', nil, function(bagName, key, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == PlayerId() and open then
        SendNUIMessage({
            action = "updateCoins",
            coins = tonumber(value) or 0
        })
    end
end)

AddStateBagChangeHandler('vipCoins', nil, function(bagName, key, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == PlayerId() and open then
        SendNUIMessage({
            action = "updateCoins",
            coins = tonumber(value) or 0
        })
    end
end)

-- Global Thread for UI protection
CreateThread(function()
    while true do
        Wait(0)
        if not isNativeMapOpen and not IsPauseMenuActive() then
            DisableControlAction(0, 200, true)
            if open then
                DisableControlAction(0, 199, true)
            end
        end
    end
end)


-- ── EXPORTS ─────────────────────────────────────────────────

exports('AddTab', function(tab)
    if not Config.Tabs then Config.Tabs = {} end
    table.insert(Config.Tabs, tab)
    cachedTabs = nil
end)

exports('RemoveTab', function(tabId)
    if Config.Tabs then
        for i, tab in ipairs(Config.Tabs) do
            if tab.id == tabId then
                table.remove(Config.Tabs, i)
                cachedTabs = nil
                break
            end
        end
    end
end)