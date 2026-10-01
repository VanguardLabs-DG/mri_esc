/**
 * app.js - Main Controller for MRI_ESC Web
 */

"use strict";

const App = {
    init() {
        this.setupEventListeners();
        this.initMap();
    },

    initMap() {
        const mapElement = document.getElementById('meu-mapa');
        if (mapElement) {
            mapElement.addEventListener('map-ready', (e) => {
                window.leafletEngine = e.detail.map;
                const controls = mapElement.shadowRoot.querySelector('.leaflet-control-container');
                if (controls) controls.style.display = 'none';
            });
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

    onMessage(event) {
        const { action, ...data } = event.data;
        const store = Alpine.store('ui');
        if (!store) return;

        switch (action) {
            case 'showMenu':
                store.player = {
                    name: Utils.sanitize(data.nome),
                    id: data.id,
                    job: Utils.sanitize(data.job),
                    money: data.money,
                    bank: data.bank,
                    gems: data.gems !== undefined ? data.gems : (data.vip ? (data.vip.gems ?? data.vip.coins ?? 0) : 0),
                    playersOn: data.playersOn
                };
                if (data.vip) store.updateVip(data.vip);
                if (data.tabs) store.tabs = data.tabs;
                store.isAdmin   = data.isAdmin || false;
                store.activeTab = 'inicio';
                store.isOpen    = true;

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
                window.dispatchEvent(new Event('mri:cleanup'));
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
                if (data.gems !== undefined) store.player.gems = data.gems;
                break;

            case 'updateGems':
                if (store.player) {
                    store.player.gems = data.gems || 0;
                }
                if (store.vip) {
                    store.vip.coins = data.gems || 0;
                }
                break;

            case 'updateCoins':
                store.player.money = data.coins;
                store.player.bank = data.coinsArma;
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

App.init();
window.App = App;