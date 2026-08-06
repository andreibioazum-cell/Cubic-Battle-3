local enemy = {}

-- Параметры по умолчанию (NORMAL)
local SIZE = 55
local SPEED = 140
local SIGHT = 650
local SHOOT_RANGE = 450
local KEEP_DIST = 150
local MAX_HP = 10
local RESPAWN = 2
local SHOOT_CD = 1.2
local BULLET_SPEED = 220
local DODGE_RADIUS = 140
local DODGE_SPEED = 320

local DODGE_CHANCE = 0.3
local REACTION_DELAY = 0.2
local DODGE_COOLDOWN = 0.8
local MAX_DODGE_TIME = 0.5
local DANGER_THRESHOLD = 200
local DANGER_THRESHOLD_SQ = DANGER_THRESHOLD * DANGER_THRESHOLD

local e
local timer = 0
local img
local eBullets = {}

local dodgeTimer = 0
local lastDodgeTime = 0
local reactionTimer = 0
local currentDodgeDir = 1

function enemy.setDifficulty(diff)
    if diff == "easy" then
        SPEED = 80
        SHOOT_CD = 1.8
        BULLET_SPEED = 160
        MAX_HP = 6
    elseif diff == "hard" then
        SPEED = 200
        SHOOT_CD = 0.8
        BULLET_SPEED = 280
        MAX_HP = 14
    elseif diff == "impossible" then
        SPEED = 280
        SHOOT_CD = 0.4
        BULLET_SPEED = 350
        MAX_HP = 20
    else -- normal
        SPEED = 140
        SHOOT_CD = 1.2
        BULLET_SPEED = 220
        MAX_HP = 10
    end
    e = nil
    timer = 0
end

local function spawnBullet(x, y, dx, dy)
    table.insert(eBullets, {
        x = x, y = y,
        vx = dx * BULLET_SPEED,
        vy = dy * BULLET_SPEED,
        dirX = dx, dirY = dy,
        life = 3
    })
    if _G.playShootSound then _G.playShootSound() end
end

local function spawn(px, py)
    local w, h = love.graphics.getDimensions()
    local minR = math.min(w, h) * 0.30
    local maxR = math.min(w, h) * 0.45
    local a = math.random() * math.pi * 2
    local dist = minR + math.random() * (maxR - minR)
    e = {
        x = px + math.cos(a) * dist,
        y = py + math.sin(a) * dist,
        hp = MAX_HP,
        hit = 0,
        angle = 0,
        state = "wander",
        wanderT = 0,
        wanderDX = 0,
        wanderDY = 0,
        shootT = SHOOT_CD * 0.5,
        strafeDir = math.random() > 0.5 and 1 or -1,
        dodgeCooldown = 0,
        isDodging = false,
        dodgeTime = 0,
        dodgeDirX = 0,
        dodgeDirY = 0,
        dodgeSpeed = 300,
        freezeTimer = 0,
        freezeDuration = 0,
        isFrozen = false,
        freezeSpeedMult = 0.25
    }
end

function enemy.load()
    img = love.graphics.newImage("player.png")
    img:setFilter("nearest", "nearest")
end

function enemy.reset()
    e = nil
    timer = 0
    eBullets = {}
end

function enemy.get() return e, SIZE, MAX_HP end
function enemy.getBullets() return eBullets end

-- Заморозка врага
function enemy.freeze(duration, speedMult)
    if not e then return end
    duration = duration or 5
    e.freezeTimer = duration
    e.freezeDuration = duration
    e.isFrozen = true
    e.freezeSpeedMult = speedMult or 0.25
    e.hit = 1
end

function enemy.isFrozen()
    return e and e.freezeTimer and e.freezeTimer > 0
end

-- Новая функция для нанесения урона врагу (используется лазером и миной)
function enemy.takeDamage(dmg)
    if not e then return false end
    e.hp = e.hp - dmg
    e.hit = 1
    if _G.playHitSound then _G.playHitSound() end
    if e.hp <= 0 then
        e = nil
        return true
    end
    return false
end

function enemy.update(dt, px, py, playerBullets, onHitPlayer)
    for i = #eBullets, 1, -1 do
        local b = eBullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        if b.life <= 0 then table.remove(eBullets, i) end
    end

    if not e then
        timer = timer + dt
        if timer >= RESPAWN then
            timer = 0
            spawn(px, py)
        end
        return false
    end

    -- Обработка заморозки
    local curSpeed = SPEED
    local curDodgeSpeed = e.dodgeSpeed or 300
    local isFrozen = false
    if e.freezeTimer and e.freezeTimer > 0 then
        e.freezeTimer = e.freezeTimer - dt
        if e.freezeTimer <= 0 then
            e.freezeTimer = 0
            e.isFrozen = false
        else
            isFrozen = true
            local mult = e.freezeSpeedMult or 0.25
            curSpeed = SPEED * mult
            curDodgeSpeed = (e.dodgeSpeed or 300) * mult
        end
    end

    local eX, eY = e.x, e.y
    local dx = px - eX
    local dy = py - eY
    local dist = math.sqrt(dx * dx + dy * dy) + 0.0001
    local nx, ny = dx / dist, dy / dist

    local MAX_DIST_FROM_PLAYER = SIGHT * 2.5
    if dist > MAX_DIST_FROM_PLAYER then
        local angle = math.random() * math.pi * 2
        local newDist = SIGHT * 0.8
        e.x = px + math.cos(angle) * newDist
        e.y = py + math.sin(angle) * newDist
        dx = px - e.x
        dy = py - e.y
        dist = math.sqrt(dx * dx + dy * dy) + 0.0001
        nx, ny = dx / dist, dy / dist
    end

    if e.dodgeCooldown > 0 then
        e.dodgeCooldown = e.dodgeCooldown - dt
    end

    if e.isDodging then
        e.dodgeTime = e.dodgeTime - dt
        if e.dodgeTime <= 0 then
            e.isDodging = false
            e.dodgeCooldown = DODGE_COOLDOWN
        end
    end

    if not e.isDodging and e.dodgeCooldown <= 0 then
        local closestDistSq = DANGER_THRESHOLD_SQ
        local closestBullet = nil

        for _, b in ipairs(playerBullets) do
            local bx = b.x - eX
            local by = b.y - eY
            local distSq = bx * bx + by * by
            if distSq < closestDistSq then
                if b.dirX and b.dirY then
                    if b.dirX * bx + b.dirY * by > 0 then
                        closestDistSq = distSq
                        closestBullet = b
                    end
                else
                    closestDistSq = distSq
                    closestBullet = b
                end
            end
        end

        if closestBullet then
            local b = closestBullet
            local bx = b.x - eX
            local by = b.y - eY
            local distFactor = 1 - math.sqrt(closestDistSq) / DANGER_THRESHOLD
            local dodgeChance = math.min(0.9, DODGE_CHANCE * (1 + distFactor * 0.5))
            if math.random() < dodgeChance then
                local cross = b.vx * by - b.vy * bx
                if cross > 0 then
                    e.dodgeDirX, e.dodgeDirY = b.vy, -b.vx
                else
                    e.dodgeDirX, e.dodgeDirY = -b.vy, b.vx
                end
                local dLen = math.sqrt(e.dodgeDirX * e.dodgeDirX + e.dodgeDirY * e.dodgeDirY) + 0.0001
                e.dodgeDirX, e.dodgeDirY = e.dodgeDirX / dLen, e.dodgeDirY / dLen
                e.isDodging = true
                e.dodgeTime = MAX_DODGE_TIME
                e.dodgeCooldown = DODGE_COOLDOWN
                e.strafeDir = math.random() > 0.5 and 1 or -1
            end
        end
    end

    if e.isDodging then
        e.state = "dodge"
        e.x = e.x + e.dodgeDirX * curDodgeSpeed * dt
        e.y = e.y + e.dodgeDirY * curDodgeSpeed * dt
    else
        if dist < SIGHT then
            if dist < KEEP_DIST then
                e.state = "retreat"
            elseif dist < SHOOT_RANGE then
                e.state = "attack"
            else
                e.state = "chase"
            end
        else
            e.state = "wander"
        end

        if e.state == "chase" then
            e.x = e.x + nx * curSpeed * dt
            e.y = e.y + ny * curSpeed * dt
        elseif e.state == "retreat" then
            e.x = e.x - nx * curSpeed * dt
            e.y = e.y - ny * curSpeed * dt
        elseif e.state == "attack" then
            local sDx = -ny * e.strafeDir
            local sDy =  nx * e.strafeDir
            e.x = e.x + sDx * curSpeed * 0.4 * dt
            e.y = e.y + sDy * curSpeed * 0.4 * dt

            local shootDt = isFrozen and (dt * 0.4) or dt
            e.shootT = e.shootT - shootDt
            if e.shootT <= 0 then
                e.shootT = SHOOT_CD
                local spread = (math.random() - 0.5) * 0.2
                local angle = math.atan2(dy, dx) + spread
                local sDx = math.cos(angle)
                local sDy = math.sin(angle)
                spawnBullet(e.x, e.y, sDx, sDy)
                if math.random() > 0.7 then e.strafeDir = -e.strafeDir end
            end
        elseif e.state == "wander" then
            e.wanderT = e.wanderT - dt
            if e.wanderT <= 0 then
                e.wanderT = 1.5 + math.random() * 2.5
                local a = math.random() * math.pi * 2
                e.wanderDX = math.cos(a)
                e.wanderDY = math.sin(a)
            end
            e.x = e.x + e.wanderDX * curSpeed * 0.25 * dt
            e.y = e.y + e.wanderDY * curSpeed * 0.25 * dt
        end
    end

    e.angle = math.atan2(dy, dx) + math.pi / 2
    e.hit = math.max(0, e.hit - dt * 3)

    local eHP = e.hp
    for i = #playerBullets, 1, -1 do
        local b = playerBullets[i]
        local bx = b.x - e.x
        local by = b.y - e.y
        if bx * bx + by * by <= (SIZE * 0.55) ^ 2 then
            local dmg = b.damage or 1
            eHP = eHP - dmg
            e.hit = 1
            if _G.playHitSound then _G.playHitSound() end
            table.remove(playerBullets, i)
            if eHP <= 0 then
                e = nil
                return true
            end
        end
    end
    e.hp = eHP
    return false
end

function enemy.draw()
    if not e then return end
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.push()
    love.graphics.translate(e.x + 6, e.y + 8)
    love.graphics.rotate(e.angle)
    love.graphics.draw(img, -SIZE / 2, -SIZE / 2)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(e.x, e.y)
    love.graphics.rotate(e.angle)
    local t = e.hit
    if e.freezeTimer and e.freezeTimer > 0 then
        -- Заморозка: синий цвет
        love.graphics.setColor(0.3, 0.65, 1.0, 1)
    else
        love.graphics.setColor(1, 1 - t * 0.8, 1 - t * 0.8, 1)
    end
    love.graphics.draw(img, -SIZE / 2, -SIZE / 2)

    -- Визуальный эффект заморозки (ледяная рамка и мерцание)
    if e.freezeTimer and e.freezeTimer > 0 then
        love.graphics.setColor(0.4, 0.8, 1.0, 0.4 + 0.2 * math.sin(love.timer.getTime() * 6))
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", -SIZE/2 - 3, -SIZE/2 - 3, SIZE + 6, SIZE + 6, 8, 8)
        love.graphics.setColor(0.7, 0.9, 1.0, 0.8)
        love.graphics.circle("fill", -SIZE/2, -SIZE/2, 4)
        love.graphics.circle("fill", SIZE/2, -SIZE/2, 4)
        love.graphics.circle("fill", -SIZE/2, SIZE/2, 4)
        love.graphics.circle("fill", SIZE/2, SIZE/2, 4)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function enemy.drawBullets()
    love.graphics.setColor(0, 0, 0, 1)
    for _, b in ipairs(eBullets) do
        love.graphics.circle("fill", b.x, b.y, 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return enemy
