-- =============================================================
--  mri_esc — NUI Bridge (Callbacks & Events)
-- =============================================================

local SafeNUICallback = (EscCore and EscCore.SafeNUICallback) or function(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, err = pcall(handler, data, cb)
        if not ok then
            print(string.format("[vanguard_esc] Erro no NUI Callback '%s': %s", name, tostring(err)))
            if cb then cb({ success = false, error = tostring(err) }) end
        end
    end)
end

SafeNUICallback("close", function(_, cb)
    print("[vanguard_esc] NUI Callback 'close' received")
    closeMenu()
    if cb then cb({ success = true }) end
end)

SafeNUICallback("openNativeMap", function(_, cb)
    print("[vanguard_esc] NUI Callback 'openNativeMap' received")
    if cb then cb({ success = true }) end

    SetNuiFocus(false, false)
    closeMenu(true)
    isNativeMapOpen = true
    if EscCore then EscCore.isNativeMapOpen = true end

    CreateThread(function()
        AnimpostfxStopAll()
        StopAllScreenEffects()

        -- Ativa o menu frontend nativo
        ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_SP_PAUSE"), 0, -1)

        -- Aguarda ativamente até que o menu pause esteja de fato ativo no GTA V
        local timeoutLimit = (Config.Timings and Config.Timings.nativeMapTimeoutMs) or 1500
        local timeout = GetGameTimer() + timeoutLimit
        while not IsPauseMenuActive() and GetGameTimer() < timeout do
            Wait(10)
        end

        if not IsPauseMenuActive() then
            print("[vanguard_esc] Falha ao abrir o pause menu nativo (timeout)")
            isNativeMapOpen = false
            if EscCore then EscCore.isNativeMapOpen = false end
            lastMapClose = GetGameTimer()
            if EscCore then EscCore.lastMapClose = lastMapClose end
            return
        end

        -- Tempo para o Scaleform (pause_menu_sp_content) instanciar as páginas internas
        local scaleformWait = (Config.Timings and Config.Timings.scaleformWaitMs) or 60
        local scaleformTab = (Config.Controls and Config.Controls.scaleformTab) or 149
        Wait(scaleformWait)
        PauseMenuceptionGoDeeper(scaleformTab)

        -- DEBOUNCE CRÍTICO: descarta inputs dos primeiros ms para evitar falso-positivo do Frame 0
        local frameDebounce = (Config.Timings and Config.Timings.frameDebounceMs) or 350
        Wait(frameDebounce)

        -- Controles monitorados
        local ctrlAlt = (Config.Controls and Config.Controls.pauseAlternate) or 200
        local ctrlPause = (Config.Controls and Config.Controls.pause) or 199
        local ctrlCancel = (Config.Controls and Config.Controls.cancel) or 202

        -- Monitoramento de fechamento do mapa
        while isNativeMapOpen and IsPauseMenuActive() do
            Wait(0)
            if IsControlJustPressed(0, ctrlAlt) or IsDisabledControlJustPressed(0, ctrlAlt)
            or IsControlJustPressed(0, ctrlPause) or IsDisabledControlJustPressed(0, ctrlPause)
            or IsControlJustPressed(0, ctrlCancel) or IsDisabledControlJustPressed(0, ctrlCancel) then
                SetFrontendActive(false)
                break
            end
        end

        lastMapClose = GetGameTimer()
        isNativeMapOpen = false
        if EscCore then
            EscCore.lastMapClose = lastMapClose
            EscCore.isNativeMapOpen = false
        end
    end)
end)

SafeNUICallback("config", function(_, cb)
    print("[vanguard_esc] NUI Callback 'config' received")
    if cb then cb({ success = true }) end
    closeMenu(true)
    CreateThread(function()
        local cfgWait = (Config.Timings and Config.Timings.configMenuWaitMs) or 150
        Wait(cfgWait)
        ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_LANDING_MENU"), 0, -1)
    end)
end)

SafeNUICallback("openHudMenu", function(_, cb)
    print("[vanguard_esc] NUI Callback 'openHudMenu' received")
    if cb then cb({ success = true }) end
    closeMenu(true)
    CreateThread(function()
        local cfgWait = (Config.Timings and Config.Timings.configMenuWaitMs) or 150
        Wait(cfgWait)
        TriggerEvent('ps-hud:client:openMenu')
    end)
end)

SafeNUICallback("consultComandos", function(_, cb)
    print("[vanguard_esc] NUI Callback 'consultComandos' received")
    if cb then cb({ tabela = Config.Comandos or {} }) end
end)

SafeNUICallback("executarComando", function(data, cb)
    if data and data.comando and type(data.comando) == "string" then
        local rawCmd = data.comando:match("^/*(.-)%s*$")
        local isAllowed = false
        if Config and Config.Comandos then
            for _, item in ipairs(Config.Comandos) do
                local allowed = type(item) == "table" and item.comando or item
                if type(allowed) == "string" and allowed:match("^/*(.-)%s*$"):lower() == rawCmd:lower() then
                    isAllowed = true
                    break
                end
            end
        end

        if isAllowed then
            ExecuteCommand(rawCmd)
        else
            print(string.format("[vanguard_esc] Comando NUI bloqueado por não estar na whitelist: '%s'", tostring(data.comando)))
        end
    end
    if cb then cb({ success = true }) end
end)

SafeNUICallback("consultMira", function(_, cb)
    if cb then cb({ tabela = miraConfig or {} }) end
end)

SafeNUICallback("consultRedesSociais", function(_, cb)
    local redes = redesSociais or (EscCore and EscCore.redesSociais) or {}
    if cb then
        cb({
            success = true,
            instagram = redes.instagram or "",
            tiktok = redes.tiktok or "",
            youtube = redes.youtube or ""
        })
    end
end)

SafeNUICallback("salvarRedesSociais", function(data, cb)
    redesSociais = data or {}
    if EscCore then EscCore.redesSociais = redesSociais end
    SetResourceKvp("mri_esc:redes", json.encode(redesSociais))
    if cb then cb({ success = true }) end
end)

SafeNUICallback("openGemas", function(_, cb)
    print("[vanguard_esc] NUI Callback 'openGemas' received -> opening gem_store plugin")
    if exports['vanguard_esc'] and exports['vanguard_esc'].OpenPlugin then
        exports['vanguard_esc']:OpenPlugin('gem_store')
    end
    if cb then cb({ success = true }) end
end)

SafeNUICallback("gemas", function(_, cb)
    print("[vanguard_esc] NUI Callback 'gemas' received -> opening gem_store plugin")
    if exports['vanguard_esc'] and exports['vanguard_esc'].OpenPlugin then
        exports['vanguard_esc']:OpenPlugin('gem_store')
    end
    if cb then cb({ success = true }) end
end)
