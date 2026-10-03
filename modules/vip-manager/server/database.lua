-- =============================================================
--  mri_esc — VIP Manager Module (Database Atom)
-- =============================================================

VipPlansConfigs = {}
local mysqlReady = false

CreateThread(function()
    Wait(1000)
    mysqlReady = (GetResourceState('oxmysql') == 'started')
    
    if mysqlReady then
        -- Consolidada a criação de tabelas e atualizações de esquema
        local tables = {
            [[CREATE TABLE IF NOT EXISTS `mri_vip_records` (
                `citizenid`      VARCHAR(50)  NOT NULL,
                `tier`           VARCHAR(50)  NOT NULL,
                `granted_at`     INT(11)      NOT NULL,
                `expires_at`     INT(11)      DEFAULT NULL,
                `granted_by`     VARCHAR(100) DEFAULT 'system',
                `total_earned`   INT(11)      DEFAULT 0,
                `paycheck_count` INT(11)      DEFAULT 0,
                `updated_at`     INT(11)      DEFAULT NULL,
                `vehicle_plate`  VARCHAR(20)  DEFAULT NULL,
                PRIMARY KEY (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
            
            [[CREATE TABLE IF NOT EXISTS `mri_vip_plans` (
                `id`           VARCHAR(50)  NOT NULL,
                `label`        VARCHAR(100) NOT NULL,
                `payment`      INT          NOT NULL DEFAULT 0,
                `inventory`    INT          NOT NULL DEFAULT 0,
                `benefits`     LONGTEXT     DEFAULT '[]',
                `rewards`      LONGTEXT     DEFAULT '[]',
                `vehicle_data` LONGTEXT     DEFAULT NULL,
                `updated_at`   INT(11)      DEFAULT NULL,
                PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],

            "ALTER TABLE `mri_vip_plans` ADD COLUMN IF NOT EXISTS `rewards` LONGTEXT DEFAULT '[]'",
            "ALTER TABLE `mri_vip_plans` ADD COLUMN IF NOT EXISTS `vehicle_data` LONGTEXT DEFAULT NULL",
            "ALTER TABLE `mri_vip_records` ADD COLUMN IF NOT EXISTS `vehicle_plate` VARCHAR(20) DEFAULT NULL"
        }

        for _, query in ipairs(tables) do
            MySQL.query(query)
        end
        
        Wait(500)
        LoadVipPlans()
    end
end)

local DEFAULT_PLANS = {
    bronze = {
        label     = "VIP Bronze",
        payment   = 25000,
        inventory = 135,
        priceGems = 350,
        priceReal = "35,00",
        badge     = "STARTER",
        benefits  = {
            "Salário Passivo de R$ 25.000 / 30m",
            "+35kg de Mochila (135kg total)",
            "1 Vaga Extra na Garagem",
            "Prioridade Leve na Fila do Servidor",
            "Acesso aos Comandos VIP Básicos"
        },
        rewards   = {},
        vehicle   = { model = "sultan", name = "Karin Sultan RS VIP", type = "temp" }
    },
    ouro = {
        label     = "VIP Ouro",
        payment   = 55000,
        inventory = 175,
        priceGems = 650,
        priceReal = "65,00",
        badge     = "★ MAIS ESCOLHIDO",
        featured  = true,
        benefits  = {
            "Salário Passivo de R$ 55.000 / 30m",
            "+75kg de Mochila (175kg total)",
            "Supercarro Exclusivo Audi RS6 VIP",
            "3 Vagas Extras na Garagem",
            "Fila Rápida Prioritária",
            "Acesso a Todos os Comandos VIP",
            "Tag e Sala Exclusiva no Discord"
        },
        rewards   = {},
        vehicle   = { model = "rs6", name = "Audi RS6 Avant VIP", type = "temp" }
    },
    diamante = {
        label     = "VIP Diamante Supremo",
        payment   = 120000,
        inventory = 220,
        priceGems = 1200,
        priceReal = "120,00",
        badge     = "ELITE ANCHOR",
        benefits  = {
            "Salário Passivo de R$ 120.000 / 30m",
            "+120kg de Mochila (220kg total)",
            "Supercarro Porsche 911 GT3 RS VIP Permanente",
            "Garagens e Vagas ILIMITADAS",
            "Fila ZERO (Prioridade Máxima)",
            "Troca de Placa Personalizada Grátis",
            "Salário Dobrado em Eventos",
            "Suporte Exclusivo e Sala VIP"
        },
        rewards   = {},
        vehicle   = { model = "gt3rs", name = "Porsche 911 GT3 RS VIP", type = "perm" }
    }
}

function LoadVipPlans()
    if not mysqlReady then return end
    local ok, results = pcall(function()
        return MySQL.query.await("SELECT * FROM mri_vip_plans")
    end)
    
    if ok and results and #results > 0 then
        local newPlans = {}
        for _, p in ipairs(results) do
            local meta = DEFAULT_PLANS[p.id] or {}
            newPlans[p.id] = {
                label     = p.label,
                payment   = p.payment,
                inventory = p.inventory,
                priceGems = meta.priceGems or 500,
                priceReal = meta.priceReal or "50,00",
                badge     = meta.badge or "VIP",
                featured  = meta.featured or false,
                benefits  = json.decode(p.benefits or "[]"),
                rewards   = json.decode(p.rewards  or "[]"),
                vehicle   = json.decode(p.vehicle_data or "null") or meta.vehicle
            }
        end
        VipPlansConfigs = newPlans
    else
        -- Auto-seed default plans into MySQL
        for id, plan in pairs(DEFAULT_PLANS) do
            pcall(function()
                MySQL.query.await([[
                    INSERT INTO mri_vip_plans (id, label, payment, inventory, benefits, rewards, vehicle_data, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP())
                    ON DUPLICATE KEY UPDATE label=VALUES(label)
                ]], {
                    id, plan.label, plan.payment, plan.inventory,
                    json.encode(plan.benefits), json.encode(plan.rewards),
                    json.encode(plan.vehicle)
                })
            end)
        end
        VipPlansConfigs = DEFAULT_PLANS
    end
end

function GetVipConfigs()
    local cfg = {}
    -- Copy current plans from DB
    if VipPlansConfigs and next(VipPlansConfigs) ~= nil then
        for k, v in pairs(VipPlansConfigs) do cfg[k] = v end
    else
        for k, v in pairs(DEFAULT_PLANS) do cfg[k] = v end
    end
    -- Safety fallback ONLY for the 'nenhum' key (required for UI stability)
    if not cfg['nenhum'] then
        cfg['nenhum'] = { 
            label = "Sem VIP", 
            payment = 0, 
            inventory = 100,
            benefits = { "Torne-se VIP para ganhar benefícios exclusivos!" }
        }
    end
    return cfg
end

--- Safely fetches a VIP record from the database
--- @param cid string
--- @return table | nil
function SafeGetVipRecord(cid)
    if not mysqlReady then return nil end
    local cleanCid = cid:upper()
    local ok, result = pcall(function()
        return MySQL.single.await(
            "SELECT * FROM mri_vip_records WHERE UPPER(citizenid) = ?",
            { cleanCid }
        )
    end)
    
    if ok and result then
        print(("^2[vanguard_esc]^7 Database found record for %s: Tier=%s, Earned=%s"):format(cleanCid, result.tier, result.total_earned))
        return result 
    end
    
    print(("^1[vanguard_esc]^7 Database NO record found for %s"):format(cleanCid))
    return nil
end

exports('LoadVipPlans', LoadVipPlans)
exports('GetVipConfigs', GetVipConfigs)
exports('SafeGetVipRecord', SafeGetVipRecord)
