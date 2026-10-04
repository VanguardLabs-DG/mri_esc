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
    closeMenu(true)
    Wait(300)
    ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_MP_PAUSE"), 0, -1)
    if cb then cb({ success = true }) end
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
