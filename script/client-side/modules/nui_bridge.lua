-- =============================================================
--  mri_esc — NUI Bridge (Callbacks & Events)
-- =============================================================

RegisterNUICallback("close", function(_, cb)
    print("[vanguard_esc] NUI Callback 'close' received")
    closeMenu()
    if cb then cb({ success = true }) end
end)

RegisterNUICallback("openNativeMap", function(_, cb)
    print("[vanguard_esc] NUI Callback 'openNativeMap' received")
    if cb then cb({ success = true }) end

    SetNuiFocus(false, false)
    closeMenu(true)
    isNativeMapOpen = true
    
    CreateThread(function()
        AnimpostfxStopAll()
        StopAllScreenEffects()

        -- Garante que o pause menu esteja habilitado na engine caso algum script de admin/zona tenha desativado
        SetPauseMenuActive(true)

        -- Ativa o menu frontend nativo
        ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_SP_PAUSE"), 0, -1)

        -- Aguarda ativamente até que o menu pause esteja de fato ativo no GTA V (timeout de 1.5s)
        local timeout = GetGameTimer() + 1500
        while not IsPauseMenuActive() and GetGameTimer() < timeout do
            Wait(10)
        end

        if not IsPauseMenuActive() then
            print("[vanguard_esc] Falha ao abrir o pause menu nativo (timeout)")
            isNativeMapOpen = false
            lastMapClose = GetGameTimer()
            return
        end

        -- Tempo para o Scaleform (pause_menu_sp_content) instanciar as páginas internas
        Wait(60)
        PauseMenuceptionGoDeeper(149)

        -- DEBOUNCE CRÍTICO: descarta inputs dos primeiros 350ms para evitar o falso-positivo do Frame 0
        Wait(350)

        -- Monitoramento de fechamento do mapa:
        -- NOTA: O controle 177 (botão direito do mouse) foi removido para permitir desmarcar waypoints sem fechar o mapa.
        while isNativeMapOpen and IsPauseMenuActive() do
            Wait(0)
            if IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 200)
            or IsControlJustPressed(0, 199) or IsDisabledControlJustPressed(0, 199)
            or IsControlJustPressed(0, 202) or IsDisabledControlJustPressed(0, 202) then
                SetFrontendActive(false)
                break
            end
        end

        lastMapClose = GetGameTimer()
        isNativeMapOpen = false
    end)
end)



RegisterNUICallback("config", function(_, cb)
    print("[vanguard_esc] NUI Callback 'config' received")
    closeMenu(true)
    Wait(300)
    ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_LANDING_MENU"), 0, -1)
    if cb then cb({ success = true }) end
end)

RegisterNUICallback("consultComandos", function(_, cb)
    print("[vanguard_esc] NUI Callback 'consultComandos' received")
    if cb then cb({ tabela = Config.Comandos or {} }) end
end)

RegisterNUICallback("executarComando", function(data, cb)
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

RegisterNUICallback("consultMira", function(_, cb)
    if cb then cb({ tabela = miraConfig }) end
end)

-- Note: 'salvarMira' and 'saveMira' are registered in client.lua with Qbox/server metadata persistence.


RegisterNUICallback("consultRedesSociais", function(_, cb)
    if cb then cb({ success = true, instagram = redesSociais.instagram, tiktok = redesSociais.tiktok, youtube = redesSociais.youtube }) end
end)

RegisterNUICallback("salvarRedesSociais", function(data, cb)
    redesSociais = data or {}
    SetResourceKvp("mri_esc:redes", json.encode(redesSociais))
    if cb then cb({ success = true }) end
end)

RegisterNUICallback("openGemas", function(_, cb)
    print("[vanguard_esc] NUI Callback 'openGemas' received -> opening gem_store plugin")
    if exports['vanguard_esc'] and exports['vanguard_esc'].OpenPlugin then
        exports['vanguard_esc']:OpenPlugin('gem_store')
    end
    if cb then cb({ success = true }) end
end)

RegisterNUICallback("gemas", function(_, cb)
    print("[vanguard_esc] NUI Callback 'gemas' received -> opening gem_store plugin")
    if exports['vanguard_esc'] and exports['vanguard_esc'].OpenPlugin then
        exports['vanguard_esc']:OpenPlugin('gem_store')
    end
    if cb then cb({ success = true }) end
end)
