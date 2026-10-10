/**
 * components.js - Alpine Component Logic
 */

function appRoot() {
    return {
        get store() {
            try {
                return Alpine.store('ui') || {};
            } catch (e) {
                return {};
            }
        },
        openGemasStore() {
            const store = Alpine.store('ui');
            if (store && store.openGemasStore) {
                store.openGemasStore();
            } else {
                Nui.post('openGemas');
            }
        }
    };
}

function menuComponent() {
    return {
        get store() {
            try {
                return Alpine.store('ui') || {};
            } catch (e) {
                return {};
            }
        },
        openGemasStore() {
            const store = Alpine.store('ui');
            if (store && store.openGemasStore) {
                store.openGemasStore();
            } else {
                Nui.post('openGemas');
            }
        },
        handleTabClick(tab) {
            const store = Alpine.store('ui');
            const actions = {
                'mapa': () => { Nui.post('openNativeMap'); },
                'config': () => Nui.post('config'),
                'gemas': () => store.openGemasStore(),
                'loja_gemas': () => store.openGemasStore(),
                'customizacao': () => { store.activeTab = tab.id; store.loadRedesSociais(); },
                'comandos': () => { store.activeTab = tab.id; store.loadComandos(); },
                'mira': () => { store.activeTab = tab.id; store.loadMira(); },
                'default': () => { store.activeTab = tab.id; }
            };
            (actions[tab.action] || actions['default'])();
        }
    };
}

function miraComponent() {
    return {
        get store() {
            try {
                return Alpine.store('ui') || {};
            } catch (e) {
                return {};
            }
        },
        update() {
            const config = Alpine.store('ui').mira;
            window.miraPreview?.draw(config);
            window.miraPermanente?.draw(config);
        },
        updateMira() { this.update(); },
        updateMiraNumber(field, min, max) {
            const store = Alpine.store('ui');
            let val = parseInt(store.mira[field]);
            if (isNaN(val)) val = min;
            store.mira[field] = Math.max(min, Math.min(max, val));
            this.update();
        },
        updateColor() {
            Alpine.store('ui').mira.cor = Utils.validateHex(Alpine.store('ui').mira.cor);
            this.update();
        },
        validateColor() { this.updateColor(); }
    };
}

function adminVipPanel() {
    return {
        get store() {
            try {
                return Alpine.store('ui') || {};
            } catch (e) {
                return {};
            }
        },
        search: '',
        searchResults: [],
        searching: false,
        loading: false,
        toast: null,
        _subTab: 'players',
        get subTab() { return this._subTab; },
        set subTab(val) {
            this._subTab = val;
            if (val === 'plans') this.loadPlans();
        },
        get plans() { return Alpine.store('ui').plans || []; },
        searchPlans: '',
        modal: { open: false, mode: 'grant', citizenId: '', playerName: '', tier: 'tier1', duration: '30' },
        planModal: { open: false, isNew: true, id: '', label: '', payment: 0, inventory: 0, benefits: [], rewards: [], vehicle: null },
        confirm: { open: false, citizenId: '', playerName: '' },
        get list() { return Alpine.store('ui').adminList || []; },

        itemsList: [],
        itemSearch: '',
        itemLoading: false,

        vehiclesList: [],
        vehSearch: '',
        vehLoading: false,

        init() {
            if (Alpine.store('ui')?.isAdmin) {
                this.loadPlans();
                this.loadItems();
                this.loadVehicles();
            }
            this._onAdminResult = (e) => {
                const { operation, result } = e.detail || {};
                if (result?.success) {
                    const msgs = { grant: 'VIP concedido!', revoke: 'VIP revogado.', extend: 'VIP renovado!' };
                    this.showToast('success', msgs[operation] || 'Operação realizada.');
                } else {
                    this.showToast('error', result?.error || 'Erro desconhecido');
                }
            };
            window.addEventListener('mri:adminResult', this._onAdminResult);
            window.addEventListener('mri:cleanup', () => this.destroy());
        },

        destroy() {
            if (this._onAdminResult) window.removeEventListener('mri:adminResult', this._onAdminResult);
        },

        showToast(type, msg) {
            this.toast = { type, msg };
            setTimeout(() => { this.toast = null; }, 3500);
        },

        formatDate(ts) {
            if (!ts || ts === 0) return 'Não registrada';
            return new Date(ts * 1000).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' });
        },

        getPlanLabel(tierId) {
            if (!tierId || tierId === 'nenhum') return 'S/ VIP';
            const plan = (Alpine.store('ui').plans || []).find(p => p.id && p.id.toLowerCase() === tierId.toLowerCase());
            return plan ? plan.label : `ID: ${tierId}`;
        },

        formatMoney(n) { return Utils.formatMoney(n); },

        statusClass(row) {
            if (!row.expires_at) return 'st-perm';
            const diff = row.expires_at - Math.floor(Date.now() / 1000);
            if (diff <= 0) return 'st-expired';
            if (diff <= 7 * 86400) return 'st-warn';
            return 'st-ok';
        },

        statusLabel(row) {
            if (!row.expires_at) return '∞ Permanente';
            const diff = row.expires_at - Math.floor(Date.now() / 1000);
            if (diff <= 0) return 'EXPIRADO';
            return `${Math.floor(diff / 86400)}d restantes`;
        },

        filtered() {
            const q = this.search.toLowerCase().trim();
            if (!q) return this.list;
            return this.list.filter(r => r.citizenid?.toLowerCase().includes(q) || r.name?.toLowerCase().includes(q));
        },

        async loadList() {
            this.loading = true;
            await Nui.post('vipAdminRefresh');
            setTimeout(() => { this.loading = false; }, 1500);
        },

        async loadPlans() {
            this.loading = true;
            try {
                const res = await Nui.post('vipAdminGetPlans');
                if (Array.isArray(res) && res.length > 0) Alpine.store('ui').plans = res;
            } catch (e) { console.error(e); }
            this.loading = false;
        },

        openGrant(citizenId, name) {
            const firstTier = (Alpine.store('ui').plans && Alpine.store('ui').plans[0]) ? Alpine.store('ui').plans[0].id : 'tier1';
            this.modal = { open: true, mode: 'grant', citizenId, playerName: name || citizenId, tier: firstTier, duration: '30' };
        },

        openExtend(row) {
            this.modal = { open: true, mode: 'extend', citizenId: row.citizenid, playerName: row.name || row.citizenid, tier: row.tier, duration: '30' };
        },

        confirmGrant() {
            const days = parseInt(this.modal.duration) || 0;
            if (this.modal.mode === 'grant') Nui.post('vipAdminGrant', { citizenId: this.modal.citizenId, tier: this.modal.tier, durationDays: days });
            else Nui.post('vipAdminExtend', { citizenId: this.modal.citizenId, tier: this.modal.tier, days });
            this.modal.open = false;
        },

        openRevoke(row) { this.confirm = { open: true, citizenId: row.citizenid, playerName: row.name || row.citizenid }; },

        executeRevoke() {
            const cid = this.confirm.citizenId;
            this.confirm.open = false;
            Nui.post('vipAdminRevoke', { citizenId: cid });
        },

        // ── GERENCIAMENTO DE PLANOS (CRUD) ──────────────────────
        filteredPlans() {
            const q = this.searchPlans.toLowerCase().trim();
            if (!q) return this.plans;
            return this.plans.filter(p => 
                (p && p.label ? String(p.label).toLowerCase() : '').includes(q) || 
                (p && p.id ? String(p.id).toLowerCase() : '').includes(q)
            );
        },


        async openPlanModal(plan = null) {
            // Always re-fetch plans fresh from server before opening modal
            await this.loadPlans();
            
            if (plan) {
                // Find the FRESHEST version of the plan from the store
                const fresh = (Alpine.store('ui').plans || []).find(p => p.id === plan.id) || plan;
                const rewards = Array.isArray(fresh.rewards) ? fresh.rewards.map(r => ({...r})) : [];
                this.planModal = {
                    open: true, isNew: false,
                    id: fresh.id, label: fresh.label,
                    payment: fresh.payment, inventory: fresh.inventory,
                    benefits: Array.isArray(fresh.benefits) ? [...fresh.benefits] : [],
                    rewards: rewards,
                    vehicle: fresh.vehicle ? {...fresh.vehicle} : null
                };
            } else {
                this.planModal = {
                    open: true, isNew: true,
                    id: '', label: '',
                    payment: 5000, inventory: 100,
                    benefits: [''],
                    rewards: [],
                    vehicle: null
                };
            }
        },

        async savePlan() {
            if (!this.planModal.id || !this.planModal.label) {
                return this.showToast('error', 'Preencha ID e Nome.');
            }
            
            const data = {
                id: this.planModal.id.trim().toLowerCase().replace(/\s+/g, '_'),
                label: this.planModal.label.trim(),
                payment: parseInt(this.planModal.payment) || 0,
                inventory: parseInt(this.planModal.inventory) || 0,
                benefits: this.planModal.benefits.map(b => b.trim()).filter(b => b !== ''),
                rewards: this.planModal.rewards,
                vehicle: this.planModal.vehicle
            };

            const res = await Nui.post('vipAdminSavePlan', data);
            if (res && res.success) {
                this.showToast('success', 'Plano salvo com sucesso!');
                this.planModal.open = false;
                this.loadPlans();
            } else {
                this.showToast('error', res?.error || 'Erro ao salvar plano.');
            }
        },

        async loadItems() {
            this.itemLoading = true;
            try {
                const res = await Nui.post('vipAdminGetItems');
                if (Array.isArray(res)) this.itemsList = res;
            } catch (e) { console.error(e); }
            this.itemLoading = false;
        },

        filteredItems() {
            const q = this.itemSearch.toLowerCase().trim();
            if (!q) return [];
            return this.itemsList.filter(i => 
                (i && i.label ? String(i.label).toLowerCase() : '').includes(q) || 
                (i && i.name ? String(i.name).toLowerCase() : '').includes(q)
            ).slice(0, 10);
        },


        addReward(item) {
            const exists = this.planModal.rewards.find(r => r.item === item.name);
            if (exists) return;
            this.planModal.rewards.push({
                item: item.name,
                label: item.label,
                amount: 1
            });
            this.itemSearch = '';
        },

        removeReward(index) {
            this.planModal.rewards.splice(index, 1);
        },

        getItemImage(itemName) {
            return `nui://ox_inventory/web/images/${itemName}.png`;
        },

        // ── VEÍCULOS ───────────────────────────────────────────
        async loadVehicles() {
            this.vehLoading = true;
            try {
                const res = await Nui.post('vipAdminGetVehicles');
                if (Array.isArray(res)) {
                    this.vehiclesList = res;
                } else {
                    console.error("Failed to load vehicles list", res);
                }
            } catch (e) { console.error(e); }
            this.vehLoading = false;
        },

        filteredVehicles() {
            const q = this.vehSearch.toLowerCase().trim();
            if (!q) return [];
            return this.vehiclesList.filter(v => {
                const name = (v.name || "").toLowerCase();
                const model = (v.model || "").toLowerCase();
                const brand = (v.brand || "").toLowerCase();
                return name.includes(q) || model.includes(q) || brand.includes(q);
            }).slice(0, 10);
        },

        setVehicle(veh) {
            this.planModal.vehicle = {
                model: veh.model,
                name: (veh.brand ? veh.brand + " " : "") + veh.name,
                type: 'perm'
            };
            this.vehSearch = '';
        },

        async deletePlan(id) {
            if (confirm(`Atenção: Deseja realmente excluir o plano "${id}"? Isso não removerá o cargo dos jogadores que já o possuem, mas eles perderão os benefícios.`)) {
                const res = await Nui.post('vipAdminDeletePlan', { id });
                if (res && res.success) {
                    this.showToast('success', 'Plano removido.');
                    this.loadPlans();
                } else {
                    this.showToast('error', res?.error || 'Erro ao excluir.');
                }
            }
        }
    };
}

window.appRoot = appRoot;
window.menuComponent = menuComponent;
window.miraComponent = miraComponent;
window.adminVipPanel = adminVipPanel;

// Register Alpine components upon alpine:init
document.addEventListener('alpine:init', () => {
    if (typeof Alpine !== 'undefined' && Alpine.data) {
        Alpine.data('appRoot', appRoot);
        Alpine.data('menuComponent', menuComponent);
        Alpine.data('miraComponent', miraComponent);
        Alpine.data('adminVipPanel', adminVipPanel);
    }
});

// Global fallback for any un-scoped expression referencing 'store'
if (!window.store) {
    try {
        Object.defineProperty(window, 'store', {
            get() {
                try {
                    return (typeof Alpine !== 'undefined' && Alpine.store) ? Alpine.store('ui') || {} : {};
                } catch (e) {
                    return {};
                }
            },
            configurable: true
        });
    } catch (e) {
        window.store = {};
    }
}

