/**
 * ui_store.js - Alpine.js Central Store
 */

document.addEventListener('alpine:init', () => {
    Alpine.store('ui', {
        isOpen: false,
        activeTab: 'inicio',
        isAdmin: false,
        adminList: [],
        player: { 
            name: '', id: '', job: 'Desempregado', 
            money: 0, bank: 0, gems: 0, playersOn: 0,
            avatar: '', location: ''
        },
        mira: {
            ativo: false, tamanho: 12, gap: 4, espessura: 2,
            outline: 1, cor: '#FFFFFF', opacidade: 100, dot: false
        },
        redesSociais: { instagram: '', tiktok: '', youtube: '' },
        comandos: [],
        comandosSearch: '',
        selectedPlanIndex: 1, // Default to Ouro (Decoy Sweet Spot)
        vipAcquireModal: {
            isOpen: false,
            plan: null,
            loading: false,
            feedbackMsg: '',
            feedbackType: '',
            needGems: false,
            copied: false
        },
        plans: [
            {
                id: 'bronze',
                label: 'VIP Bronze',
                badge: 'STARTER',
                featured: false,
                priceGems: 350,
                priceReal: '35,00',
                payment: 25000,
                inventory: 135,
                vehicle: { model: 'sultan', name: 'Karin Sultan RS VIP', type: 'temp' },
                benefits: [
                    'Salário Passivo de R$ 25.000 / 30m',
                    '+35kg de Mochila (135kg total)',
                    '1 Vaga Extra na Garagem',
                    'Prioridade Leve na Fila do Servidor',
                    'Acesso aos Comandos VIP Básicos'
                ]
            },
            {
                id: 'ouro',
                label: 'VIP Ouro',
                badge: '★ MAIS ESCOLHIDO',
                featured: true,
                priceGems: 650,
                priceReal: '65,00',
                payment: 55000,
                inventory: 175,
                vehicle: { model: 'rs6', name: 'Audi RS6 Avant VIP', type: 'temp' },
                benefits: [
                    'Salário Passivo de R$ 55.000 / 30m',
                    '+75kg de Mochila (175kg total)',
                    'Supercarro Exclusivo Audi RS6 VIP',
                    '3 Vagas Extras na Garagem',
                    'Fila Rápida Prioritária',
                    'Acesso a Todos os Comandos VIP',
                    'Tag e Sala Exclusiva no Discord'
                ]
            },
            {
                id: 'diamante',
                label: 'VIP Diamante Supremo',
                badge: 'ELITE ANCHOR',
                featured: false,
                priceGems: 1200,
                priceReal: '120,00',
                payment: 120000,
                inventory: 220,
                vehicle: { model: 'gt3rs', name: 'Porsche 911 GT3 RS VIP', type: 'perm' },
                benefits: [
                    'Salário Passivo de R$ 120.000 / 30m',
                    '+120kg de Mochila (220kg total)',
                    'Supercarro Porsche 911 GT3 RS Permanente',
                    'Garagens e Vagas ILIMITADAS',
                    'Fila ZERO (Prioridade Máxima)',
                    'Troca de Placa Personalizada Grátis',
                    'Salário Dobrado em Eventos',
                    'Suporte Exclusivo e Sala VIP'
                ]
            }
        ],
        plugins: [],
        loadedPlugins: {},
        mountedPlugins: {},
        activePluginTarget: null,
        tabs: [
            { id: 'inicio', label: 'INÍCIO', icon: 'fa-bars', action: 'inicio' },
            { id: 'mapa', label: 'MAPA', icon: 'fa-map', action: 'mapa' },
            { id: 'customizacao', label: 'CUSTOMIZAÇÃO', icon: 'fa-user', action: 'customizacao' },
            { id: 'config', label: 'CONFIGURAÇÕES', icon: 'fa-cog', action: 'config' }
        ],
        vip: {
            tier: 'nenhum', label: 'Nenhum', salary: 0, inventory: 0, coins: 0,
            benefits: [], paycheckTime: 0, paycheckMax: 1800,
            vipSince: null, vipExpires: null, daysActive: 0, daysLeft: null,
            isExpired: false, totalEarned: 0, paycheckCount: 0,
            charName: '', charJob: '', citizenId: ''
        },
        paycheckInterval: null,

        init(data) {
            if (!data) return;
            this.player = { ...this.player, ...data };
            if (data.isAdmin !== undefined) this.isAdmin = data.isAdmin;
            if (data.vip) this.updateVip(data.vip);
        },

        updateVip(data) {
            if (!data) return;
            
            // Explicit assignment as per user's working version
            this.vip.tier           = data.tier     || 'nenhum';
            this.vip.label          = data.label    || 'Sem VIP';
            this.vip.salary         = data.salary   || 0;
            this.vip.inventory      = data.inventory|| 0;
            this.vip.coins          = data.coins    || 0;
            this.vip.benefits       = Array.isArray(data.benefits) ? data.benefits : [];
            
            // Time Metrics
            this.vip.vipSince       = data.vipSince   ?? null;
            this.vip.vipExpires     = data.vipExpires ?? null;
            this.vip.daysActive     = data.daysActive || 0;
            this.vip.daysLeft       = data.daysLeft   ?? null;
            this.vip.isExpired      = data.isExpired  || false;
            
            // Earning Metrics
            this.vip.totalEarned    = data.totalEarned   || 0;
            this.vip.paycheckCount  = data.paycheckCount || 0;
            
            // Character Info
            this.vip.charName       = data.charName  || '';
            this.vip.charJob        = data.charJob   || '';
            this.vip.citizenId      = data.citizenId || '';

            if (data.isAdmin !== undefined) this.isAdmin = data.isAdmin === true;

            if (data.interval) {
                this.vip.paycheckMax = data.interval * 60;
            }
            if (data.timeLeft !== undefined) {
                this.vip.paycheckTime = data.timeLeft;
            }
            if (data.allPlans && data.allPlans.length > 0) {
                this.plans = data.allPlans;
                if (this.selectedPlanIndex >= this.plans.length) {
                    this.selectedPlanIndex = 0;
                }
            }
            this.startPaycheckTimer();
        },

        startPaycheckTimer() {
            if (this.paycheckInterval) clearInterval(this.paycheckInterval);
            if (this.vip.paycheckTime <= 0) this.vip.paycheckTime = this.vip.paycheckMax;
            this.paycheckInterval = setInterval(() => {
                if (this.vip.paycheckTime > 0) this.vip.paycheckTime--;
                else this.vip.paycheckTime = this.vip.paycheckMax;
            }, 1000);
        },

        formatTime(seconds) {
            if (seconds == null || isNaN(seconds)) return "0:00";
            const m = Math.floor(seconds / 60);
            const s = seconds % 60;
            return `${m}:${s < 10 ? '0' : ''}${s}`;
        },

        formatDate(unixTs) {
            if (!unixTs || unixTs === 0) return 'Não registrada';
            return new Date(unixTs * 1000).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' });
        },
        
        getPaycheckProgress() {
            if (!this.vip.paycheckMax) return 0;
            return (this.vip.paycheckTime / this.vip.paycheckMax) * 100;
        },

        async loadMira() {
            const res = await Nui.post('consultMira');
            if (res?.tabela) {
                this.mira = { ...this.mira, ...res.tabela };
                window.miraPreview?.draw(this.mira);
            }
        },

        async saveMiraToServer(miraData) {
            const data = miraData !== undefined ? miraData : this.mira;
            return await Nui.post('saveMira', data);
        },

        async saveMira() {
            return await this.saveMiraToServer(this.mira);
        },

        async loadComandos() {
            const res = await Nui.post('consultComandos');
            if (res?.tabela) this.comandos = res.tabela;
        },

        getFilteredComandos() {
            const query = this.comandosSearch.toLowerCase();
            if (!query) return this.comandos;
            return this.comandos.filter(c => 
                c.comando.toLowerCase().includes(query) || 
                c.descricao.toLowerCase().includes(query)
            );
        },

        resetMira() {
            this.mira = {
                ativo: false, tamanho: 12, gap: 4, espessura: 2,
                outline: 1, cor: '#FFFFFF', opacidade: 100, dot: false
            };
        },

        formatMoney(val) { return Utils.formatMoney(val); },
        formatGems(val) {
            if (val === undefined || val === null || isNaN(val)) return '0';
            return Number(val).toLocaleString('pt-BR');
        },
        openGemasStore() {
            this.openPlugin('gem_store');
        },

        getSelectedPlan() {
            if (!this.plans || this.plans.length === 0) return null;
            return this.plans[this.selectedPlanIndex] || this.plans[0];
        },

        selectPlan(index) {
            if (index >= 0 && index < this.plans.length) {
                this.selectedPlanIndex = index;
            }
        },

        openVipAcquireModal(plan) {
            const target = plan || this.getSelectedPlan();
            if (!target) return;
            this.vipAcquireModal.isOpen = true;
            this.vipAcquireModal.plan = target;
            this.vipAcquireModal.loading = false;
            this.vipAcquireModal.feedbackMsg = '';
            this.vipAcquireModal.feedbackType = '';
            this.vipAcquireModal.needGems = false;
            this.vipAcquireModal.copied = false;
        },

        closeVipAcquireModal() {
            this.vipAcquireModal.isOpen = false;
            this.vipAcquireModal.feedbackMsg = '';
            this.vipAcquireModal.needGems = false;
        },

        async buyVipWithGems(plan) {
            const target = plan || this.vipAcquireModal.plan || this.getSelectedPlan();
            if (!target) return;
            this.vipAcquireModal.loading = true;
            this.vipAcquireModal.feedbackMsg = '';
            this.vipAcquireModal.feedbackType = '';
            this.vipAcquireModal.needGems = false;

            try {
                const res = await Nui.post('buyVipWithGems', { tier: target.id });
                this.vipAcquireModal.loading = false;
                if (res && res.success) {
                    this.vipAcquireModal.feedbackType = 'success';
                    this.vipAcquireModal.feedbackMsg = res.message || 'VIP ativado com sucesso!';
                    if (res.newGems !== undefined) {
                        this.player.gems = res.newGems;
                        if (this.vip) {
                            this.vip.gems = res.newGems;
                            this.vip.coins = res.newGems;
                        }
                    }
                    setTimeout(() => {
                        this.closeVipAcquireModal();
                    }, 2200);
                } else {
                    this.vipAcquireModal.feedbackType = 'error';
                    this.vipAcquireModal.feedbackMsg = res?.error || 'Erro ao processar compra de VIP.';
                    this.vipAcquireModal.needGems = res?.needGems === true;
                }
            } catch (err) {
                console.error('[vanguard_esc] buyVipWithGems error:', err);
                this.vipAcquireModal.loading = false;
                this.vipAcquireModal.feedbackType = 'error';
                this.vipAcquireModal.feedbackMsg = 'Erro de comunicação ao adquirir VIP.';
            }
        },

        copyStoreLink() {
            const link = 'https://discord.gg/distritopaulista';
            try {
                if (navigator.clipboard && navigator.clipboard.writeText) {
                    navigator.clipboard.writeText(link);
                } else {
                    const inp = document.createElement('input');
                    inp.value = link;
                    document.body.appendChild(inp);
                    inp.select();
                    document.execCommand('copy');
                    document.body.removeChild(inp);
                }
                this.vipAcquireModal.copied = true;
                setTimeout(() => {
                    this.vipAcquireModal.copied = false;
                }, 3000);
            } catch (e) {
                this.vipAcquireModal.copied = true;
            }
        },

        setPlugins(list) {
            if (!list) {
                this.plugins = [];
                return;
            }
            const rawArr = Array.isArray(list) ? list : Object.values(list);
            const arr = rawArr.filter(p => p && typeof p === 'object' && p.id);
            this.plugins = arr.sort((a, b) => (Number(a.order) || 100) - (Number(b.order) || 100));
            // Pre-mount all plugins so they are pre-warmed, cached, and render with zero latency
            for (const p of this.plugins) {
                this.mountedPlugins[p.id] = true;
            }
        },

        getPluginUrl(plugin) {
            if (!plugin) return '';
            const resource = plugin.resource || 'vanguard_esc';
            const path = (plugin.htmlPath || 'web/index.html').replace(/^\//, '');
            return `https://cfx-nui-${resource}/${path}?embedded=1`;
        },

        safePostMessage(id, message) {
            const iframe = document.getElementById('plugin-iframe-' + id);
            if (!iframe || !iframe.contentWindow) return false;
            try {
                // Strip all Alpine.js reactive Proxies, non-clonable getters, and symbols
                const cleanPayload = JSON.parse(JSON.stringify(message));
                iframe.contentWindow.postMessage(cleanPayload, '*');
                return true;
            } catch (err) {
                console.error('[vanguard_esc] safePostMessage error for plugin ' + id + ':', err);
                return false;
            }
        },

        openPlugin(id, opts) {
            this.mountedPlugins[id] = true;
            const previousTab = this.activeTab;
            this.activeTab = 'plugin:' + id;
            this.activePluginTarget = opts || null;
            Nui.post('routeChanged', { route: 'plugin:' + id });

            if (previousTab && previousTab.startsWith('plugin:') && previousTab !== ('plugin:' + id)) {
                const prevId = previousTab.replace('plugin:', '');
                this.notifyPluginVisibility(prevId, false);
            }

            if (this.loadedPlugins[id]) {
                this.sendPluginNavigate(id, opts);
                if (this.isOpen) {
                    this.notifyPluginVisibility(id, true);
                    this.safePostMessage(id, {
                        type: 'mri-plugin/updateGems',
                        gems: Number(this.player?.gems) || 0
                    });
                }
            } else {
                // Safety timeout: unblock spinner if iframe load stalls or resource stopped
                setTimeout(() => {
                    if (!this.loadedPlugins[id] && this.activeTab === ('plugin:' + id)) {
                        this.loadedPlugins[id] = true;
                    }
                }, 6000);
            }
        },

        onPluginLoaded(id) {
            this.loadedPlugins[id] = true;
            this.sendPluginInit(id);
            if (this.isOpen && this.activeTab === 'plugin:' + id) {
                this.notifyPluginVisibility(id, true);
                if (this.activePluginTarget) {
                    this.sendPluginNavigate(id, this.activePluginTarget);
                }
            } else {
                this.notifyPluginVisibility(id, false);
            }
        },

        sendPluginInit(id) {
            const p = this.player || {};
            const v = this.vip || {};
            const cleanPlayer = {
                id: p.id || '',
                name: p.name || '',
                job: p.job || '',
                gems: Number(p.gems) || 0,
                money: Number(p.money) || 0,
                bank: Number(p.bank) || 0
            };
            const cleanVip = {
                tier: v.tier || 'nenhum',
                label: v.label || 'Nenhum',
                gems: Number(v.gems ?? v.coins) || 0
            };

            this.safePostMessage(id, {
                type: 'mri-plugin/init',
                action: 'init',
                pluginId: id,
                accentColor: '#00e5ff',
                backgroundColor: '#0b0e14',
                theme: {
                    bg: '#0b0e14',
                    cyan: '#00e5ff',
                    gold: '#e5a93c'
                },
                protocolVersion: 1,
                player: cleanPlayer,
                vip: cleanVip,
                payload: {
                    player: cleanPlayer,
                    vip: cleanVip
                }
            });
        },

        sendPluginNavigate(id, opts) {
            const cleanOpts = opts ? {
                page: opts.page || null,
                category: opts.category || null,
                focus: opts.focus || null
            } : {};

            this.safePostMessage(id, {
                type: 'mri-plugin/navigate',
                action: 'navigate',
                pluginId: id,
                page: cleanOpts.page,
                category: cleanOpts.category,
                focus: cleanOpts.focus,
                payload: cleanOpts
            });
        },

        notifyPluginVisibility(id, isVisible) {
            this.safePostMessage(id, {
                type: 'mri-plugin/visibility',
                action: 'visibility',
                pluginId: id,
                visible: !!isVisible,
                payload: { visible: !!isVisible }
            });
        },

        destroy() {
            if (this.paycheckInterval) {
                clearInterval(this.paycheckInterval);
                this.paycheckInterval = null;
            }
        }
    });

    // Reactive watcher for tab switches: immediately notifies plugins of dormancy or activation
    let lastTab = null;
    Alpine.effect(() => {
        try {
            const store = Alpine.store('ui');
            if (!store) return;
            const currentTab = store.activeTab;
            if (lastTab !== currentTab) {
                if (lastTab && lastTab.startsWith('plugin:') && lastTab !== currentTab) {
                    const prevPluginId = lastTab.replace('plugin:', '');
                    store.notifyPluginVisibility(prevPluginId, false);
                }
                if (currentTab && currentTab.startsWith('plugin:')) {
                    const currentPluginId = currentTab.replace('plugin:', '');
                    if (store.isOpen) {
                        store.notifyPluginVisibility(currentPluginId, true);
                    }
                }
                lastTab = currentTab;
            }
        } catch (_) {}
    });
});
