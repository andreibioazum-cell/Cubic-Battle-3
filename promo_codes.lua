-- ============================================================
-- PROMO CODES SYSTEM
-- ============================================================

local promoSystem = {}

-- ========== PROMO CODES DATABASE ==========
local promoCodes = {
    ["KAKAK"] = {
        reward = 100,
        description = "KAKAK!",
        maxUses = 999,
        used = 0
    },
    ["KAKAK2026"] = {
        reward = 100,
        description = "Godzilla KAKAK!",
        maxUses = 999,
        used = 0
    },
    ["CUBIC"] = {
        reward = 50,
        description = "Cubic",
        maxUses = 999,
        used = 0
    },
    ["BETA2026"] = {
        reward = 200,
        description = "Beta tester",
        maxUses = 100,
        used = 0
    },
    ["FURRY"] = {
        reward = 150,
        description = "Furry",
        maxUses = 50,
        used = 0
    },
    ["GODZILLA"] = {
        reward = 500,
        description = "Godzilla!",
        maxUses = 10,
        used = 0
    },
    ["PLATI"] = {
        reward = 1000,
        description = "Pay or no badge!",
        maxUses = 5,
        used = 0
    }
}

-- ========== USED CODES ==========
local usedByPlayer = {}

-- ========== LOAD DATA ==========
function promoSystem.load()
    local data = love.filesystem.read("player_promos.txt")
    if data then
        usedByPlayer = {}
        for code in data:gmatch("[^\r\n]+") do
            usedByPlayer[code] = true
        end
    end
    
    local stats = love.filesystem.read("promo_stats.txt")
    if stats then
        for line in stats:gmatch("[^\r\n]+") do
            local code, uses = line:match("([^:]+):(%d+)")
            if code and uses and promoCodes[code] then
                promoCodes[code].used = tonumber(uses) or 0
            end
        end
    end
    
    print("Promo codes loaded: " .. #promoCodes)
end

-- ========== SAVE DATA ==========
function promoSystem.save()
    local data = ""
    for code in pairs(usedByPlayer) do
        data = data .. code .. "\n"
    end
    love.filesystem.write("player_promos.txt", data)
    
    local stats = ""
    for code, info in pairs(promoCodes) do
        stats = stats .. code .. ":" .. info.used .. "\n"
    end
    love.filesystem.write("promo_stats.txt", stats)
end

-- ========== USE PROMO CODE ==========
function promoSystem.useCode(code, playerId)
    code = string.upper(code)
    
    if not promoCodes[code] then
        return false, "Invalid promo code!"
    end
    
    local promo = promoCodes[code]
    
    if usedByPlayer[code] then
        return false, "You already used this code!"
    end
    
    if promo.used >= promo.maxUses then
        return false, "This code is no longer active!"
    end
    
    promo.used = promo.used + 1
    usedByPlayer[code] = true
    
    promoSystem.save()
    
    return true, promo.reward, promo.description
end

-- ========== GET AVAILABLE CODES ==========
function promoSystem.getAvailableCodes()
    local available = {}
    for code, info in pairs(promoCodes) do
        if info.used < info.maxUses then
            table.insert(available, {
                code = code,
                description = info.description,
                reward = info.reward,
                remaining = info.maxUses - info.used
            })
        end
    end
    return available
end

-- ========== ADMIN FUNCTIONS ==========
function promoSystem.addCode(code, reward, description, maxUses)
    code = string.upper(code)
    if promoCodes[code] then
        return false, "Code already exists!"
    end
    
    promoCodes[code] = {
        reward = reward,
        description = description,
        maxUses = maxUses or 999,
        used = 0
    }
    promoSystem.save()
    return true, "Promo code created!"
end

function promoSystem.removeCode(code)
    code = string.upper(code)
    if not promoCodes[code] then
        return false, "Code not found!"
    end
    promoCodes[code] = nil
    promoSystem.save()
    return true, "Promo code removed!"
end

return promoSystem
