-- =============================================================
--  mri_esc — Main Client Entry Point
-- =============================================================

local Config = Config or {}

-- Namespace local / interoperabilidade
EscCore = EscCore or {}
EscCore.open = false
EscCore.isNativeMapOpen = false
EscCore.lastMapClose = 0
EscCore.redesSociais = { instagram = "", tiktok = "", youtube = "" }
EscCore.cachedTabs = nil
EscCore.blocked = false
EscCore.lastOtherNuiFocus = 0
EscCore.lastOwnMenuClose = 0

-- Global aliases para retrocompatibilidade com módulos legados
open = false
isNativeMapOpen = false
lastMapClose = 0
redesSociais = EscCore.redesSociais

--- Wrapper defensivo para NUI Callbacks garantindo tratamento de erros e integridade de resposta
--- @param name string Nome do callback NUI
--- @param handler function Handler do callback (data, cb)
function EscCore.SafeNUICallback(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, err = pcall(handler, data, cb)
        if not ok then
            print(string.format("[vanguard_esc] Erro no NUI Callback '%s': %s", name, tostring(err)))
            if cb then cb({ success = false, error = tostring(err) }) end
        end
    end)
end

-- Initial Load
print("[vanguard_esc] Client Scripts Loaded (Zero-Resmon Engine)")
EscCore.cache = EscCore.cache or {
    playersOn = 1,
    vipData = nil,
    lastSync = 0
}

CreateThread(function()
    local savedRedes = GetResourceKvpString("mri_esc:redes")
    if savedRedes then
        local ok, decoded = pcall(json.decode, savedRedes)
        if ok and decoded then
            redesSociais = decoded
            EscCore.redesSociais = decoded
        end
    end
end)

-- Thread de monitoramento proativo de foco em NUIs externas com throttling dinâmico
CreateThread(function()
    while true do
        local checkWait = (Config.Timings and Config.Timings.nuiCheckIntervalMs) or 250
        local idleWait = (Config.Timings and Config.Timings.pauseCheckIdleMs) or 500
        local closeDebounce = (Config.Timings and Config.Timings.menuCloseDebounceMs) or 200

        if not open then
            local now = GetGameTimer()
            -- Ignora o instante logo após o fechamento do próprio vanguard_esc para evitar falso positivo
            if (now - (EscCore.lastOwnMenuClose or 0)) > closeDebounce then
                if IsNuiFocused() or IsNuiFocusKeepingInput() then
                    EscCore.lastOtherNuiFocus = now
                end
            end
            Wait(checkWait)
        else
            Wait(idleWait)
        end
    end
end)

-- ── HELPERS ─────────────────────────────────────────────────

local function GetPlayerData()
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:GetPlayerData()
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore and QBCore.Functions then
            return QBCore.Functions.GetPlayerData()
        end
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
    if not EscCore.cachedTabs then EscCore.cachedTabs = BuildTabsConfig() end
    return EscCore.cachedTabs
end

--- Validador estrito de condições para abertura do menu ESC.
--- Garante que o menu nunca abra quando outra interface (identidade, inventário, etc.)
--- estiver com foco ou tiver acabado de ser fechada via botão ESC.
--- @param force boolean? Se verdadeiro, ignora filtros de foco externo de NUI
--- @return boolean canOpen, string? reason
local function CanOpenEscMenu(force)
    if open then return true end

    local now = GetGameTimer()

    -- 1. Bloqueio manual programático (ex: cutscene, minigame, ou export SetBlocked)
    if EscCore and EscCore.blocked then
        return false, "manually_blocked"
    end

    -- 2. Pause menu nativo ou mapa nativo ativo / debounce do mapa
    local mapDebounce = (Config.Timings and Config.Timings.mapDebounceMs) or 300
    if isNativeMapOpen or IsPauseMenuActive() or (now - (lastMapClose or 0) < mapDebounce) then
        return false, "native_map_or_pause"
    end

    -- 3. Transição de tela esmaecida (Fade) e teclado nativo em tela
    if IsScreenFadedOut() or IsScreenFadingOut() then
        return false, "screen_faded"
    end

    if UpdateOnscreenKeyboard() == 0 then
        return false, "onscreen_keyboard_active"
    end

    -- 4. Proteção contra NUI Externa (identidade, CNH, documentos, lojas, etc.)
    if not force then
        if IsNuiFocused() or IsNuiFocusKeepingInput() then
            EscCore.lastOtherNuiFocus = now
            return false, "nui_currently_focused"
        end

        local nuiDebounce = (Config.Timings and Config.Timings.nuiFocusDebounceMs) or 500
        if (now - (EscCore.lastOtherNuiFocus or 0)) < nuiDebounce then
            return false, "recent_nui_focus_debounce"
        end
    end

    -- 5. Estado do jogador (LocalPlayer.state / StateBags)
    local plyState = LocalPlayer and LocalPlayer.state
    if not plyState or not plyState.isLoggedIn then
        return false, "not_logged_in"
    end

    if plyState.isDead or plyState.inArena then
        return false, "player_incapacitated"
    end

    -- StateBags que indicam interfaces abertas ou ações bloqueantes
    if plyState.invOpen or plyState.nuiFocused or plyState.nuiOpen or plyState.busy
    or plyState.inMenu or plyState.identidade or plyState.inIdentity or plyState.documentOpen
    or plyState.phoneOpen or plyState.usingPhone or plyState.phone_open or plyState.isPedDisabled
    or plyState.Handcuff or plyState.isHandcuffed then
        return false, "player_busy_statebag"
    end

    -- 6. Verificação de bibliotecas externas ativas (ex: ox_lib)
    if lib and lib.progressActive and lib.progressActive() then
        return false, "ox_progress_active"
    end

    return true
end

-- ── MAIN LOGIC ──────────────────────────────────────────────

function closeMenu(ignoreFrontend)
    open = false
    EscCore.open = false
    EscCore.lastOwnMenuClose = GetGameTimer()
    SendNUIMessage({ action = "hideMenu" })
    StopScreenEffect("MenuMGSelectionIn")
    StopAllScreenEffects()
    TriggerEvent("hud:Active", true)
    SetNuiFocus(false, false)
    if not ignoreFrontend then
        SetFrontendActive(false)
    end
end

function OpenMenu(targetTab, force)
    if not open then
        local canOpen = CanOpenEscMenu(force)
        if not canOpen then
            return
        end
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

    -- SWR Local Cache: leitura instantânea em memória (0ms overhead)
    local cache = EscCore.cache or { playersOn = 1, vipData = nil, lastSync = 0 }

    -- Fast Re-entry: se a NUI já foi hidratada nesta sessão,
    -- envia um sinal ultraleve (< 0.1ms IPC) reaproveitando o DOM e texturas em VRAM
    if EscCore.hasHydrated then
        local money, bank = 0, 0
        local playerData = GetPlayerData()
        if playerData and playerData.money then
            money = playerData.money.cash or 0
            bank = playerData.money.bank or 0
        end

        SendNUIMessage({
            action     = "showMenu",
            fast       = true,
            playersOn  = cache.playersOn or 1,
            money      = money,
            bank       = bank,
            initialTab = targetTab
        })

        SetNuiFocus(true, true)
        StartScreenEffect("MenuMGSelectionIn", 0, true)
        TriggerEvent("hud:Active", false)
        open = true
        EscCore.open = true
        return
    end

    local playersOn = cache.playersOn or 1
    local vipData = cache.vipData
    local playerData = GetPlayerData()

    local nome = "Jogador"
    local id = GetPlayerServerId(PlayerId())
    local money, bank = 0, 0
    local jobText = "Desempregado"

    if playerData then
        local cInfo = playerData.charinfo or {}
        local fn = cInfo.firstname or "Jogador"
        local ln = cInfo.lastname or ""
        nome = (ln ~= "") and (fn .. " " .. ln) or fn
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
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return
    end
    local coords = GetEntityCoords(ped)

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

    -- Frame-0 Dispatch Atômico (< 16ms nativo)
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

    SetNuiFocus(true, true)
    StartScreenEffect("MenuMGSelectionIn", 0, true)
    TriggerEvent("hud:Active", false)
    open = true
    EscCore.open = true
    EscCore.hasHydrated = true

    if isAdmin then TriggerEvent('mri_esc:client:adminReady') end

    -- Revalidação Assíncrona em Segundo Plano (SWR Engine)
    local now = GetGameTimer()
    local cacheTtlMs = ((Config.Timings and Config.Timings.playersCacheTtlSec) or 5) * 1000
    local cbTimeout = (Config.Timings and Config.Timings.callbackTimeoutMs) or 1500

    if (now - (cache.lastSync or 0)) > cacheTtlMs then
        CreateThread(function()
            local freshVip = nil
            pcall(function()
                if GetResourceState('ox_lib') == 'started' then
                    freshVip = lib.callback.await('mri_esc:server:getVipData', cbTimeout)
                end
            end)
            local freshPlayers = nil
            pcall(function()
                if GetResourceState('ox_lib') == 'started' then
                    freshPlayers = lib.callback.await('mri_esc:server:getPlayersOnline', false)
                end
            end)

            if open then
                cache.lastSync = GetGameTimer()
                if freshVip then
                    cache.vipData = freshVip
                    local freshGems = (LocalPlayer and LocalPlayer.state and LocalPlayer.state.gems) or freshVip.gems or 0
                    local freshCoins = (LocalPlayer and LocalPlayer.state and (LocalPlayer.state.coins or LocalPlayer.state.vipCoins)) or freshVip.coins or 0
                    SendNUIMessage({
                        action = "updateVipData",
                        vip    = freshVip,
                        gems   = freshGems,
                        coins  = freshCoins
                    })
                    if freshVip.isAdmin then TriggerEvent('mri_esc:client:adminReady') end
                end
                if freshPlayers and freshPlayers ~= playersOn then
                    cache.playersOn = freshPlayers
                    SendNUIMessage({
                        action    = "updatePlayersOn",
                        playersOn = freshPlayers
                    })
                end
            end
        end)
    end
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

EscCore.SafeNUICallback('saveMira', handleSaveMira)
EscCore.SafeNUICallback('salvarMira', handleSaveMira)

RegisterCommand("open_menu", function()
    if isNativeMapOpen or IsPauseMenuActive() then
        SetFrontendActive(false)
        lastMapClose = GetGameTimer()
        EscCore.lastMapClose = lastMapClose
        isNativeMapOpen = false
        EscCore.isNativeMapOpen = false
        return
    end

    if open then
        closeMenu()
        return
    end

    -- Filtro e proteção de foco: se outra NUI (ex: identidade, CNH, inventário) estiver aberta
    -- ou tiver acabado de ser fechada via ESC, ignora a abertura do vanguard_esc!
    local canOpen, reason = CanOpenEscMenu(false)
    if not canOpen then
        return
    end

    SetFrontendActive(false)
    OpenMenu()
end)

RegisterKeyMapping("open_menu", "Abrir Esc Menu", "keyboard", "ESCAPE")

RegisterNetEvent('mri_esc:client:refreshVip', function()
    local ok, err = pcall(function()
        if open then
            local cbTimeout = (Config.Timings and Config.Timings.callbackTimeoutMs) or 1500
            local vipData = nil
            pcall(function()
                vipData = lib.callback.await('mri_esc:server:getVipData', cbTimeout)
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
    if not ok then
        print(string.format("[vanguard_esc] Erro no evento refreshVip: %s", tostring(err)))
    end
end)

-- Real-time Gems statebag synchronization
AddStateBagChangeHandler('gems', nil, function(bagName, _, value)
    local ok, err = pcall(function()
        local ply = GetPlayerFromStateBagName(bagName)
        if ply == PlayerId() and open then
            SendNUIMessage({
                action = "updateGems",
                gems = tonumber(value) or 0
            })
        end
    end)
    if not ok then
        print(string.format("[vanguard_esc] Erro no handler gems: %s", tostring(err)))
    end
end)

-- Real-time Coins statebag synchronization
AddStateBagChangeHandler('coins', nil, function(bagName, _, value)
    local ok, err = pcall(function()
        local ply = GetPlayerFromStateBagName(bagName)
        if ply == PlayerId() and open then
            SendNUIMessage({
                action = "updateCoins",
                coins = tonumber(value) or 0
            })
        end
    end)
    if not ok then
        print(string.format("[vanguard_esc] Erro no handler coins: %s", tostring(err)))
    end
end)

AddStateBagChangeHandler('vipCoins', nil, function(bagName, _, value)
    local ok, err = pcall(function()
        local ply = GetPlayerFromStateBagName(bagName)
        if ply == PlayerId() and open then
            SendNUIMessage({
                action = "updateCoins",
                coins = tonumber(value) or 0
            })
        end
    end)
    if not ok then
        print(string.format("[vanguard_esc] Erro no handler vipCoins: %s", tostring(err)))
    end
end)

-- Global Thread for UI protection & pause menu exclusivity
-- 0.00ms resmon permanente quando fechado: roda a cada frame (Wait(0)) APENAS enquanto o menu estiver aberto
CreateThread(function()
    local ctrlAlt = (Config.Controls and Config.Controls.pauseAlternate) or 200
    local ctrlPause = (Config.Controls and Config.Controls.pause) or 199
    local idleSleep = (Config.Timings and Config.Timings.pauseCheckIdleMs) or 500

    while true do
        if open then
            -- Quando o menu estiver ABERTO: bloqueia ESC e P e fecha qualquer pause nativo residual
            DisableControlAction(0, ctrlAlt, true)
            DisableControlAction(0, ctrlPause, true)
            if IsPauseMenuActive() then
                SetFrontendActive(false)
            end
            Wait(0)
        else
            -- Quando o menu estiver FECHADO: hiberna completamente a thread (estritos 0.00ms no resmon)
            Wait(idleSleep)
        end
    end
end)


-- ── EXPORTS & EXTERNAL CONTROLS ─────────────────────────────

exports('SetBlocked', function(isBlocked)
    EscCore.blocked = isBlocked == true
end)

exports('CanOpen', function()
    return CanOpenEscMenu(false)
end)

exports('IsOpen', function()
    return open == true
end)

exports('AddTab', function(tab)
    if not Config.Tabs then Config.Tabs = {} end
    table.insert(Config.Tabs, tab)
    EscCore.cachedTabs = nil
end)

exports('RemoveTab', function(tabId)
    if Config.Tabs then
        for i, tab in ipairs(Config.Tabs) do
            if tab.id == tabId then
                table.remove(Config.Tabs, i)
                EscCore.cachedTabs = nil
                break
            end
        end
    end
end)

-- Eventos de bloqueio para compatibilidade com outros recursos
RegisterNetEvent('vanguard_esc:client:setBlocked', function(isBlocked)
    EscCore.blocked = isBlocked == true
end)

RegisterNetEvent('mri_esc:client:setBlocked', function(isBlocked)
    EscCore.blocked = isBlocked == true
end)