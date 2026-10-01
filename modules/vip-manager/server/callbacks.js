{
    console.log("[vanguard_esc] JS CALLBACKS LOADING (Full Version)...");

    const resourceName = GetCurrentResourceName();
    const bridge = exports[resourceName];

    const lib = {
        callback: {
            register: (name, cb) => {
                if (exports.ox_lib && exports.ox_lib.setValidCallback) {
                    exports.ox_lib.setValidCallback(name, true);
                }
                onNet(`__ox_cb_${name}`, async (resource, key, ...args) => {
                    const src = source;
                    console.log(`[vanguard_esc] DEBUG: Callback '${name}' requested by [${src}]`);
                    try {
                        const result = await cb(src, ...args);
                        console.log(`[vanguard_esc] DEBUG: Callback '${name}' responding with data`);
                        TriggerClientEvent(`__ox_cb_${resource}`, src, key, result);
                    } catch (err) {
                        console.error(`[vanguard_esc] ERROR in callback '${name}':`, err);
                        TriggerClientEvent(`__ox_cb_${resource}`, src, key, false);
                    }
                });
            }
        }
    };

    lib.callback.register('mri_esc:server:getPlayersOnline', () => {
        return Object.keys(exports.qbx_core.GetQBPlayers()).length || 1;
    });

    lib.callback.register('mri_esc:server:getVipData', async (source) => {
        const player = exports.qbx_core.GetPlayer(source);
        if (!player) return null;

        const metadata = player.PlayerData.metadata || {};
        const vipTier = metadata.vip || 'nenhum';
        let gems = 0;
        try {
            if (GetResourceState('dp_sistema_gemas') === 'started') {
                gems = exports['dp_sistema_gemas'].GetGems(source) || 0;
            }
        } catch (e) {
            gems = 0;
        }
        if (!gems && player.PlayerData.money && player.PlayerData.money.coin) {
            gems = player.PlayerData.money.coin;
        }
        const coins = gems;
        const cid = player.PlayerData.citizenid;

        console.log(`[vanguard_esc] DEBUG: Player CID [${cid}] | Source [${source}] | Metadata VIP: [${vipTier}] | Gems: [${gems}]`);

        const safeParse = (data) => {
            if (typeof data === 'object' && data !== null) return data;
            try { return JSON.parse(data || "[]"); } catch (e) { return []; }
        };

        let vipConfigs = {};
        try {
            const plans = await exports.oxmysql.query_async("SELECT * FROM mri_vip_plans");
            if (plans && plans.length > 0) {
                for (const p of plans) {
                    vipConfigs[p.id] = {
                        label: p.label,
                        payment: p.payment,
                        inventory: p.inventory,
                        benefits: safeParse(p.benefits),
                        rewards: safeParse(p.rewards)
                    };
                }
            }
        } catch (e) { console.error("[vanguard_esc] Error SQL plans:", e.message); }

        if (!vipConfigs['nenhum']) {
            vipConfigs['nenhum'] = { label: "Sem VIP", payment: 0, inventory: 100, benefits: ["Torne-se VIP para ganhar benefícios exclusivos!"] };
        }

        const currentVipInfo = vipConfigs[vipTier] || vipConfigs['nenhum'];
        const cleanCid = cid.toUpperCase();

        let r = null;
        try {
            r = await exports.oxmysql.single_async('SELECT * FROM mri_vip_records WHERE UPPER(citizenid) = ?', [cleanCid]);
        } catch (e) {
            console.error(`[vanguard_esc] SQL ERROR for CID ${cleanCid}:`, e.message);
        }
        
        // AUTO-HEALING in JS: If has VIP but no record
        if (!r && vipTier !== 'nenhum') {
            console.log(`[vanguard_esc] DEBUG: Auto-healing record for ${cleanCid} in JS`);
            const now = Math.floor(Date.now() / 1000);
            try {
                await exports.oxmysql.insert_async('INSERT INTO mri_vip_records (citizenid, tier, granted_at, granted_by, updated_at) VALUES (?, ?, ?, ?, ?)', 
                    [cleanCid, vipTier, now, 'js-auto-heal', now]);
                r = await exports.oxmysql.single_async('SELECT * FROM mri_vip_records WHERE UPPER(citizenid) = ?', [cleanCid]);
            } catch (e) { console.error("[vanguard_esc] Auto-heal SQL Error:", e.message); }
        }

        const hasRecord = (r && typeof r === 'object');
        const vipSince = hasRecord ? r.granted_at : (vipTier !== 'nenhum' ? 0 : null);
        const vipExpires = hasRecord ? r.expires_at : null;
        const totalEarned = hasRecord ? r.total_earned : 0;
        const paycheckCount = hasRecord ? r.paycheck_count : 0;

        let daysActive = 0;
        const nowTs = Math.floor(Date.now() / 1000);
        if (vipSince && vipSince > 0) {
            daysActive = Math.floor((nowTs - vipSince) / 86400);
        }

        let daysLeft = null;
        if (vipExpires && vipExpires > 0) {
            const diff = vipExpires - nowTs;
            daysLeft = Math.max(0, Math.floor(diff / 86400));
        }

        return {
            tier: vipTier,
            label: currentVipInfo.label || "Nenhum",
            salary: currentVipInfo.payment || 0,
            inventory: currentVipInfo.inventory || 0,
            coins: coins,
            gems: gems,
            benefits: currentVipInfo.benefits || [],
            interval: bridge.GetPaycheckInterval ? bridge.GetPaycheckInterval() : 30,
            timeLeft: bridge.GetSyncedTimeLeft ? bridge.GetSyncedTimeLeft() : 0,
            vipSince: vipSince,
            vipExpires: vipExpires,
            daysActive: daysActive,
            daysLeft: daysLeft,
            totalEarned: totalEarned,
            paycheckCount: paycheckCount,
            charName: `${player.PlayerData.charinfo.firstname} ${player.PlayerData.charinfo.lastname}`,
            charJob: player.PlayerData.job.label || 'Desempregado',
            citizenId: cid,
            isAdmin: bridge.IsAdminPlayer(source) === true,
            allPlans: (() => {
                const p = [];
                for (const [id, cfg] of Object.entries(vipConfigs)) {
                    if (id !== 'nenhum') {
                        p.push({
                            id: id,
                            label: cfg.label,
                            payment: cfg.payment,
                            inventory: cfg.inventory,
                            benefits: cfg.benefits,
                            rewards: cfg.rewards || {}
                        });
                    }
                }
                return p;
            })()
        };
    });

    lib.callback.register('mri_esc:admin:getPlans', (source) => {
        const cfg = bridge.GetVipConfigs();
        const list = [];
        for (const [id, data] of Object.entries(cfg)) {
            if (id !== 'nenhum') {
                list.push({
                    id: id,
                    label: data.label,
                    payment: data.payment,
                    inventory: data.inventory,
                    benefits: data.benefits,
                    rewards: data.rewards || {},
                    vehicle: data.vehicle || null
                });
            }
        }
        return list;
    });

    lib.callback.register('mri_esc:admin:getItems', (source) => {
        if (!bridge.IsAdminPlayer(source)) return [];
        const list = [];
        try {
            if (GetResourceState('ox_inventory') === 'started' && exports.ox_inventory && exports.ox_inventory.Items) {
                const items = exports.ox_inventory.Items() || {};
                for (const [name, data] of Object.entries(items)) {
                    list.push({
                        name: name,
                        label: data.label || name,
                        weight: data.weight || 0,
                        description: data.description || ""
                    });
                }
                list.sort((a, b) => a.label.localeCompare(b.label));
            }
        } catch (err) {
            console.error('[vanguard_esc] Erro ao carregar itens do ox_inventory:', err.message || err);
        }
        return list;
    });

    lib.callback.register('mri_esc:admin:getVehicles', (source) => {
        if (!bridge.IsAdminPlayer(source)) return [];
        let VEHICLES = {};
        if (GetResourceState('qbx_core') === 'started') {
            VEHICLES = exports.qbx_core.GetVehiclesByName() || {};
        }
        if (!VEHICLES || typeof VEHICLES !== 'object') VEHICLES = {};
        const list = [];
        for (const [model, data] of Object.entries(VEHICLES)) {
            list.push({
                model: data.model || model,
                name: data.name || model,
                brand: data.brand || "",
                category: data.category || "",
                hash: data.hash || GetHashKey(model),
                price: data.price || 0
            });
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        return list;
    });

    lib.callback.register('mri_esc:admin:savePlan', async (source, data) => {
        if (!bridge.IsAdminPlayer(source)) return { success: false, error: "Permissão negada" };
        try {
            await exports.oxmysql.query(`
                INSERT INTO mri_vip_plans (id, label, payment, inventory, benefits, rewards, vehicle_data, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    label=VALUES(label), payment=VALUES(payment),
                    inventory=VALUES(inventory), benefits=VALUES(benefits),
                    rewards=VALUES(rewards), vehicle_data=VALUES(vehicle_data), updated_at=VALUES(updated_at)
            `, [
                data.id, data.label, data.payment, data.inventory,
                JSON.stringify(data.benefits || {}),
                JSON.stringify(data.rewards || {}),
                JSON.stringify(data.vehicle || null),
                Math.floor(Date.now() / 1000)
            ]);
            bridge.LoadVipPlans();
            return { success: true };
        } catch (err) {
            return { success: false, error: err.toString() };
        }
    });

    lib.callback.register('mri_esc:admin:deletePlan', async (source, id) => {
        if (!bridge.IsAdminPlayer(source)) return { success: false, error: "Permissão negada" };
        try {
            await exports.oxmysql.update("DELETE FROM mri_vip_plans WHERE id = ?", [id]);
            bridge.LoadVipPlans();
            return { success: true };
        } catch (err) {
            return { success: false, error: err.toString() };
        }
    });

    console.log("[vanguard_esc] JS CALLBACKS RESTORED SUCCESSFULLY");
}
