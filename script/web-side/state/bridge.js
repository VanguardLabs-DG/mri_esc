/**
 * bridge.js - Ultra-High Performance Communication & Formatting Engine
 */

const NUI_RES_NAME = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'vanguard_esc';

// In-flight deduplication & TTL Cache
const pendingPosts = new Map();
const postCache = new Map();

const Nui = {
    _makeKey(action, data) {
        try {
            return `${action}:${JSON.stringify(data)}`;
        } catch (e) {
            return `${action}:[fallback]`;
        }
    },

    async post(action, data = {}, timeoutMs = 4000) {
        const key = this._makeKey(action, data);
        if (pendingPosts.has(key)) {
            return pendingPosts.get(key);
        }

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

        const promise = (async () => {
            try {
                const resp = await fetch(`https://${NUI_RES_NAME}/${action}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data),
                    signal: controller.signal
                });
                clearTimeout(timeoutId);
                return await resp.json();
            } catch (e) {
                clearTimeout(timeoutId);
                return { error: true, msg: e.name === 'AbortError' ? 'Timeout' : 'Fetch failed' };
            } finally {
                pendingPosts.delete(key);
            }
        })();

        pendingPosts.set(key, promise);
        return promise;
    },

    async cachedPost(action, data = {}, ttlMs = 15000) {
        const key = this._makeKey(action, data);
        const now = Date.now();
        const cached = postCache.get(key);
        if (cached && (now - cached.timestamp < ttlMs)) {
            return cached.data;
        }

        const res = await this.post(action, data);
        if (res && !res.error) {
            if (postCache.size > 100) postCache.clear();
            postCache.set(key, { timestamp: now, data: res });
        }
        return res;
    },

    clearCache(actionPattern = null) {
        if (!actionPattern) {
            postCache.clear();
            return;
        }
        for (const k of postCache.keys()) {
            if (k.startsWith(actionPattern)) {
                postCache.delete(k);
            }
        }
    }
};

// FastFormat: LRU-bounded memoized formatters (zero V8 ICU thrashing)
const moneyCache = new Map();
const dateCache = new Map();

const FastFormat = {
    formatMoney(n) {
        if (n == null) return "$ 0";
        const cached = moneyCache.get(n);
        if (cached !== undefined) return cached;

        const formatted = "$ " + n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
        if (moneyCache.size > 500) moneyCache.clear();
        moneyCache.set(n, formatted);
        return formatted;
    },

    formatDate(unixTs) {
        if (!unixTs || unixTs === 0) return 'Não registrada';
        const cached = dateCache.get(unixTs);
        if (cached !== undefined) return cached;

        const formatted = new Date(unixTs * 1000).toLocaleDateString('pt-BR', { 
            day: '2-digit', 
            month: '2-digit', 
            year: 'numeric' 
        });
        if (dateCache.size > 500) dateCache.clear();
        dateCache.set(unixTs, formatted);
        return formatted;
    },

    formatTime(seconds) {
        if (seconds == null || isNaN(seconds)) return "0:00";
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return `${m}:${s < 10 ? '0' : ''}${s}`;
    }
};

const Utils = {
    formatMoney: (n) => FastFormat.formatMoney(n),
    formatDate: (ts) => FastFormat.formatDate(ts),
    formatTime: (s) => FastFormat.formatTime(s),
    
    sanitize: (str) => {
        if (typeof str !== 'string') return '';
        return str.replace(/[<>"']/g, '').trim();
    },
    
    validateHex: (color) => {
        return /^#[0-9A-F]{6}$/i.test(color) ? color.toUpperCase() : '#FFFFFF';
    },

    hexToRgba: (hex, alpha) => {
        const r = parseInt(hex.slice(1, 3), 16);
        const g = parseInt(hex.slice(3, 5), 16);
        const b = parseInt(hex.slice(5, 7), 16);
        return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    },

    shallowPatch: (target, patch) => {
        if (!target || !patch || typeof target !== 'object' || typeof patch !== 'object') return target;
        for (const [key, val] of Object.entries(patch)) {
            if (target[key] !== val) {
                target[key] = val;
            }
        }
        return target;
    }
};

window.Nui = Nui;
window.Utils = Utils;
window.FastFormat = FastFormat;
