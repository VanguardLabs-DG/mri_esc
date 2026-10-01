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
    if data.comando then
        ExecuteCommand(data.comando)
    end
    if cb then cb({ success = true }) end
end)

RegisterNUICallback("consultMira", function(_, cb)
    if cb then cb({ tabela = miraConfig }) end
end)

RegisterNUICallback("salvarMira", function(data, cb)
    miraConfig = data
    SetResourceKvp("mri_esc:mira", json.encode(data))
    SendNUIMessage({ action = "miraData", mira = data })
    if cb then cb({ success = true }) end
end)

RegisterNUICallback("consultRedesSociais", function(_, cb)
    if cb then cb({ success = true, instagram = redesSociais.instagram, tiktok = redesSociais.tiktok, youtube = redesSociais.youtube }) end
end)

RegisterNUICallback("salvarRedesSociais", function(data, cb)
    redesSociais = data or {}
    SetResourceKvp("mri_esc:redes", json.encode(redesSociais))
    if cb then cb({ success = true }) end
end)

RegisterNUICallback("openGemas", function(_, cb)
    print("[vanguard_esc] NUI Callback 'openGemas' received")
    if cb then cb({ success = true }) end
    closeMenu()
    CreateThread(function()
        Wait(350)
        ExecuteCommand("gemas")
        TriggerEvent("Gems:Open")
    end)
end)

RegisterNUICallback("gemas", function(_, cb)
    print("[vanguard_esc] NUI Callback 'gemas' received")
    if cb then cb({ success = true }) end
    closeMenu()
    CreateThread(function()
        Wait(350)
        ExecuteCommand("gemas")
        TriggerEvent("Gems:Open")
    end)
end)
