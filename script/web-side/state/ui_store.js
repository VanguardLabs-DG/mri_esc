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
            money: 0, bank: 0, gems: 0, playersOn: 0 
        },
        mira: {
            ativo: false, tamanho: 12, gap: 4, espessura: 2,
            outline: 1, cor: '#FFFFFF', opacidade: 100, dot: false
        },
        redesSociais: { instagram: '', tiktok: '', youtube: '' },
        comandos: [],
        comandosSearch: '',
        plans: [],
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
            if (data.allPlans) {
                this.plans = data.allPlans;
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

        async saveMira() { await Nui.post('salvarMira', this.mira); },

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
            Nui.post('openGemas');
        },

        destroy() {
            if (this.paycheckInterval) {
                clearInterval(this.paycheckInterval);
                this.paycheckInterval = null;
            }
        }
    });
});
