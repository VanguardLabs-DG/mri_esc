-- =============================================================
--  mri_esc — Main Server Entry Point
-- =============================================================

ServerState = ServerState or {}
ServerState.paycheckInterval = (Config and Config.Timings and Config.Timings.paycheckIntervalMin) or 30

-- Backward compatibility alias
paycheckInterval = ServerState.paycheckInterval
exports('GetPaycheckInterval', function() return ServerState.paycheckInterval end)

-- Resource startup sequence
CreateThread(function()
    print("^4[vanguard_esc]^7 Inicializando arquitetura atômica...")
    
    -- Verificação de dependências críticas
    if GetResourceState('ox_lib') ~= 'started' then
        print("^1[vanguard_esc] ERRO: ox_lib é necessário para este resource!^7")
    end
    
    if GetResourceState('qbx_core') ~= 'started' then
        print("^1[vanguard_esc] ERRO: qbx_core é necessário!^7")
    end

    print("^2[vanguard_esc] Inicialização server-side concluída com sucesso.^7")
end)
