/**
 * app.js - Main Controller for MRI_ESC Web with Extensible Plugin Engine
 */

"use strict";

const App = {
    init() {
        this.setupEventListeners();
        this.preloadPlugins();
    },

    preloadPlugins() {
        if (typeof Nui !== 'undefined' && Nui.post) {
            Nui.post('getPlugins').then(plugins => {
                const store = Alpine?.store('ui');
                if (store && plugins) {
                    store.setPlugins(plugins);
                }
            }).catch(() => {});
        }
    },

    setupEventListeners() {
        window.addEventListener('message', this.onMessage.bind(this));
        document.addEventListener('keydown', this.onKeyDown.bind(this));

        document.addEventListener('alpine:initialized', () => {
            const preview = document.getElementById('canvas-mira-preview');
            const permanent = document.getElementById('canvas-mira-permanente');
            
            if (preview) window.miraPreview = new MiraRenderer(preview);
            if (permanent) window.miraPermanente = new MiraRenderer(permanent, true);
            
            Nui.post('requestMiraSync'); 
        });
    },

    handlePluginMessage(data) {
        const store = Alpine?.store('ui');
        if (!store) return;

        const type = data.type || data.action;

        if (type === 'mri-plugin/ready' || type === 'esc-plugin/ready') {
            const pluginId = data.pluginId;
            if (pluginId) {
                store.onPluginLoaded(pluginId);
            }
        } else if (type === 'mri-plugin/request-close' || type === 'esc-plugin/close') {
            Nui.post('close');
        } else if (type === 'mri-plugin/open-tab' || type === 'esc-plugin/open-tab') {
            if (data.tab) {
                store.activeTab = data.tab;
                Nui.post('routeChanged', { route: data.tab });
            }
        } else if (type === 'esc-plugin/notify' || type === 'mri-plugin/notify') {
            if (data.action === 'updateGems' && data.gems !== undefined) {
                if (store.player) store.player.gems = data.gems;
                if (store.vip) store.vip.gems = data.gems;
            }
        }
    },

    onMessage(event) {
        if (!event.data) return;

        // Check if message came from an embedded plugin iframe
        const msgType = event.data.type || event.data.action;
        if (typeof msgType === 'string' && (msgType.startsWith('mri-plugin/') || msgType.startsWith('esc-plugin/'))) {
            this.handlePluginMessage(event.data);
            return;
        }

        const { action, ...data } = event.data;
        const store = Alpine.store('ui');
        if (!store) return;

        switch (action) {
            case 'showMenu':
                store.player = {
                    name: Utils.sanitize(data.nome),
                    id: data.id,
                    job: Utils.sanitize(data.job),
                    money: Number(data.money) || 0,
                    bank: Number(data.bank) || 0,
                    gems: data.gems !== undefined ? Number(data.gems) : (data.vip?.gems || 0),
                    coins: data.coins !== undefined ? Number(data.coins) : (data.vip?.coins || 0),
                    playersOn: data.playersOn,
                    avatar: data.avatar || '',
                    location: data.location || ''
                };
                if (data.vip) store.updateVip(data.vip);
                if (data.vip?.mira) {
                    store.mira = { ...store.mira, ...data.vip.mira };
                    window.miraPermanente?.draw(store.mira);
                    window.miraPreview?.draw(store.mira);
                }
                if (data.tabs) store.tabs = data.tabs;
                store.isAdmin   = data.isAdmin || false;
                store.isOpen    = true;
                document.documentElement.classList.remove('cef-dormant');

                if (data.initialTab) {
                    if (data.initialTab.startsWith('plugin:')) {
                        const pluginId = data.initialTab.replace('plugin:', '');
                        store.openPlugin(pluginId);
                    } else {
                        store.activeTab = data.initialTab;
                    }
                } else {
                    store.activeTab = 'inicio';
                }

                if (data.playerX !== undefined && data.playerY !== undefined) {
                    setTimeout(() => {
                        if (window.leafletEngine) {
                            window.leafletEngine.setView([data.playerY, data.playerX], 4);
                            window.leafletEngine.invalidateSize(); 
                        }
                    }, 150);
                }
                break;

            case 'hideMenu':
                store.isOpen = false;
                document.documentElement.classList.add('cef-dormant');
                if (store.plugins && store.plugins.length) {
                    store.plugins.forEach(p => store.notifyPluginVisibility(p.id, false));
                }
                window.dispatchEvent(new Event('mri:cleanup'));
                break;

            case 'pluginsUpdated':
                if (data.data?.plugins) {
                    store.setPlugins(data.data.plugins);
                } else if (data.plugins) {
                    store.setPlugins(data.plugins);
                }
                break;

            case 'navigate':
                if (data.data) {
                    const target = data.data;
                    if (target.route && target.route.startsWith('plugin:')) {
                        const pluginId = target.pluginId || target.route.replace('plugin:', '');
                        store.openPlugin(pluginId, target);
                    } else if (target.route) {
                        store.activeTab = target.route;
                        Nui.post('routeChanged', { route: target.route });
                    }
                }
                break;

            case 'openPlugin':
                if (data.pluginId) {
                    store.openPlugin(data.pluginId, data.opts);
                }
                break;

            case 'closePlugin':
                if (store.activeTab === ('plugin:' + data.pluginId) || !data.pluginId) {
                    Nui.post('close');
                }
                break;

            case 'miraData':
                store.mira = { ...store.mira, ...data.mira };
                window.miraPermanente?.draw(store.mira);
                break;

            case 'updateAdminList':
                store.adminList = Array.isArray(data.list) ? data.list : [];
                if (data.allPlans) store.plans = data.allPlans;
                break;

            case 'updateAdmin':
                store.isAdmin = data.isAdmin === true;
                break;

            case 'updateVipData':
                if (data.vip) store.updateVip(data.vip);
                if (data.gems !== undefined) store.player.gems = Number(data.gems) || 0;
                if (data.coins !== undefined) store.player.coins = Number(data.coins) || 0;
                break;

            case 'updateGems':
                if (store.player) {
                    store.player.gems = Number(data.gems) || 0;
                }
                if (store.vip) {
                    store.vip.gems = Number(data.gems) || 0;
                }
                const gemIframe = document.getElementById('plugin-iframe-gem_store');
                if (gemIframe && gemIframe.contentWindow) {
                    gemIframe.contentWindow.postMessage({
                        type: 'mri-plugin/updateGems',
                        gems: Number(data.gems) || 0
                    }, '*');
                }
                break;

            case 'updateCoins':
                if (store.player) {
                    store.player.coins = Number(data.coins) || 0;
                }
                if (store.vip) {
                    store.vip.coins = Number(data.coins) || 0;
                }
                break;

            case 'adminActionResult':
                window.dispatchEvent(new CustomEvent('mri:adminResult', { detail: data }));
                break;
        }
    },

    onKeyDown(event) {
        const store = Alpine.store('ui');
        if (event.key === 'Escape' && store?.isOpen) {
            Nui.post('close');
        }
    }
};

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => App.init());
} else {
    App.init();
}
window.App = App;