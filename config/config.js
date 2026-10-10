const Config = {};

// ------------------------------------------------------------------------------
// Atalhos exibidos no menu "Comandos"
// ------------------------------------------------------------------------------

Config.Comandos = [
    { comando: "e dancar5", descricao: "Dança 5" },
    { comando: "e dancar6", descricao: "Dança 6" },
    { comando: "e dancar7", descricao: "Dança 7" },
    { comando: "e dancar8", descricao: "Dança 8" },
    { comando: "hud", descricao: "Alternar HUD/Interface" }
];

// ------------------------------------------------------------------------------
// Abas do menu (Sistema de Addons)
// ------------------------------------------------------------------------------

Config.Tabs = [
    // Abas padrão (não remover)
    // { id: 'inicio', label: 'INÍCIO', icon: 'fa-bars', action: 'inicio' },
    // { id: 'mapa', label: 'MAPA', icon: 'fa-map', action: 'mapa' },
    // { id: 'customizacao', label: 'CUSTOMIZAÇÃO', icon: 'fa-user', action: 'customizacao' },
    // { id: 'config', label: 'CONFIGURAÇÕES', icon: 'fa-cog', action: 'config' },
    { id: 'vip', label: 'VIP', icon: 'fa-crown', action: 'vip' },
    { id: 'hud_settings', label: 'HUD', icon: 'fa-sliders', action: 'hud_settings' }
];

// ------------------------------------------------------------------------------
// Configurações da Mira
// ------------------------------------------------------------------------------

Config.Mira = {
    ativo: false,
    tamanho: 12,
    gap: 4,
    espessura: 2,
    outline: 1,
    cor: "#FFFFFF",
    opacidade: 100,
    dot: false
};

// ------------------------------------------------------------------------------
// Configurações Gerais
// ------------------------------------------------------------------------------

Config.AllowSupport = true;
Config.AllowCommands = true;

// ------------------------------------------------------------------------------
// Admins do Painel VIP
// ------------------------------------------------------------------------------

Config.AdminIds = [
    // "license:SEU_LICENSE_AQUI",
    // "steam:SEU_STEAM_AQUI",
    // "fivem:SEU_FIVEM_AQUI",
];

// Caso esteja usando em um ambiente Node.js ou módulos ES6:
// export default Config;

// Caso esteja usando no NUI do FiveM:
// window.Config = Config;