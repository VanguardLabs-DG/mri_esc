Config = {}

--------------------------------------------------------------------------------
-- Atalhos exibidos no menu "Comandos"
--------------------------------------------------------------------------------

Config.Comandos = {
    [1] = { comando = "e dancar5", descricao = "Dança 5" },
    [2] = { comando = "e dancar6", descricao = "Dança 6" },
    [3] = { comando = "e dancar7", descricao = "Dança 7" },
    [4] = { comando = "e dancar8", descricao = "Dança 8" },
    [5] = { comando = "hud", descricao = "Alternar HUD/Interface" }
}

--------------------------------------------------------------------------------
-- Abas do menu (Sistema de Addons)
-- Estrutura para injeção de novas abas:
-- { id: 'identificador', label: 'TEXTO DO BOTÃO', icon: 'fa-icon', action: 'ação' }
-- Actions disponíveis: 'inicio', 'mapa', 'customizacao', 'config', 'comandos', 'mira', ou id de aba customizada
--
-- Exemplo de como adicionar novas abas via outro script:
-- exports.mri_esc:AddTab({ id: 'minha_aba', label: 'MINHA ABA', icon: 'fa-star', action: 'minha_aba' })
--------------------------------------------------------------------------------

Config.Tabs = {
    -- Abas padrão (não remover)
    -- { id = 'inicio', label = 'INÍCIO', icon = 'fa-bars', action = 'inicio' },
    -- { id = 'mapa', label = 'MAPA', icon = 'fa-map', action = 'mapa' },
    -- { id = 'customizacao', label = 'CUSTOMIZAÇÃO', icon = 'fa-user', action = 'customizacao' },
    -- { id = 'config', label = 'CONFIGURAÇÕES', icon = 'fa-cog', action = 'config' }
    { id = 'vip', label = 'VIP', icon = 'fa-crown', action = 'vip' },
    { id = 'hud_settings', label = 'HUD', icon = 'fa-sliders', action = 'hud_settings' }
}

--------------------------------------------------------------------------------
-- Configurações da Mira
--------------------------------------------------------------------------------

Config.Mira = {
    ativo = false,
    tamanho = 12,
    gap = 4,
    espessura = 2,
    outline = 1,
    cor = "#FFFFFF",
    opacidade = 100,
    dot = false
}

--------------------------------------------------------------------------------
-- Configurações Gerais
--------------------------------------------------------------------------------

Config.AllowSupport = true
Config.AllowCommands = true

--------------------------------------------------------------------------------
-- Admins do Painel VIP (identificadores do jogador)
-- Adicione seus identificadores para garantir acesso ao painel admin
-- Exemplo: "license:abc123", "steam:110000112345678", "fivem:123456"
-- Para descobrir seus identificadores, abra o menu e veja o console do servidor
--------------------------------------------------------------------------------

Config.AdminIds = {
    -- "license:SEU_LICENSE_AQUI",
    -- "steam:SEU_STEAM_AQUI",
    -- "fivem:SEU_FIVEM_AQUI",
}

--------------------------------------------------------------------------------
-- Timers, Throttles e Constantes de Engine (Prevenção de Magic Numbers)
--------------------------------------------------------------------------------

Config.Timings = {
    mapDebounceMs       = 300,  -- Tempo mínimo de debounce entre reabertura de mapa nativo
    nativeMapTimeoutMs  = 1500, -- Timeout máximo aguardando abertura do pause menu nativo
    scaleformWaitMs     = 60,   -- Delay de sincronização do scaleform nativo (pause_menu_sp_content)
    frameDebounceMs     = 350,  -- Descarte de input inicial após abrir mapa (evita falso-positivo)
    configMenuWaitMs    = 300,  -- Delay antes de invocar menu de configurações nativo
    callbackTimeoutMs   = 1500, -- Timeout padrão em chamadas síncronas lib.callback
    playersCacheTtlSec  = 5,    -- TTL de cache (em segundos) da contagem de jogadores online
    nuiFocusDelayMs     = 50,   -- Delay em milissegundos para foco da NUI
    nuiFocusDebounceMs  = 500,  -- Tempo de debounce contra abertura acidental ao fechar outras NUIs com ESC
    adminListPushWaitMs = 300,  -- Delay para atualização da lista administrativa
    actionRefreshWaitMs = 400,  -- Delay pós-ação administrativa antes de atualizar lista
    crosshairIdleMs     = 500,  -- Intervalo de sleep da thread de retícula quando inativa
    pauseCheckIdleMs    = 500,  -- Intervalo de sleep da thread de controle quando em repouso (0.00ms resmon)
    nuiCheckIntervalMs  = 250,  -- Intervalo de checagem proativa de foco externo
    menuCloseDebounceMs = 200,  -- Debounce pós-fechamento do próprio menu ESC
    paycheckIntervalMin = 30,   -- Intervalo padrão de sincronização do salário (minutos)
}

Config.Controls = {
    pauseAlternate = 200, -- INPUT_FRONTEND_PAUSE_ALTERNATE (ESC)
    pause          = 199, -- INPUT_FRONTEND_PAUSE (P)
    cancel         = 202, -- INPUT_FRONTEND_CANCEL (Backspace)
    hudReticle     = 14,  -- HUD component ID para mira nativa
    scaleformTab   = 149, -- Índice de página do Scaleform para mapa
}

return Config