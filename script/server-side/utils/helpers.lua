-- =============================================================
--  mri_esc — General Helpers
-- =============================================================

local MS_PER_MINUTE = 60000
local MS_PER_SECOND = 1000

--- Calculates the time left until the next paycheck synchronization
--- @return number
local function GetSyncedTimeLeft()
    local intervalMinutes = (ServerState and ServerState.paycheckInterval)
        or tonumber(paycheckInterval)
        or (Config and Config.Timings and Config.Timings.paycheckIntervalMin)
        or 30
    local intervalMs    = intervalMinutes * MS_PER_MINUTE
    local uptime        = GetGameTimer()
    local timeSinceLast = uptime % intervalMs
    return math.floor((intervalMs - timeSinceLast) / MS_PER_SECOND)
end

-- Backward compatibility alias
GetSyncedTimeLeft = GetSyncedTimeLeft
exports('GetSyncedTimeLeft', GetSyncedTimeLeft)
