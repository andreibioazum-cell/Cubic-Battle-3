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
        dodgeSpeed = 300
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
        e.x = e.x + e.dodgeDirX * e.dodgeSpeed * dt
        e.y = e.y + e.dodgeDirY * e.dodgeSpeed * dt
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
            e.x = e.x + nx * SPEED * dt
            e.y = e.y + ny * SPEED * dt
        elseif e.state == "retreat" then
            e.x = e.x - nx * SPEED * dt
            e.y = e.y - ny * SPEED * dt
        elseif e.state == "attack" then
            local sDx = -ny * e.strafeDir
            local sDy =  nx * e.strafeDir
            e.x = e.x + sDx * SPEED * 0.4 * dt
            e.y = e.y + sDy * SPEED * 0.4 * dt

            e.shootT = e.shootT - dt
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
            e.x = e.x + e.wanderDX * SPEED * 0.25 * dt
            e.y = e.y + e.wanderDY * SPEED * 0.25 * dt
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
            local dmg = b.damage or 1   -- ★ Учитываем урон
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
    love.graphics.setColor(1, 1 - t * 0.8, 1 - t * 0.8, 1)
    love.graphics.draw(img, -SIZE / 2, -SIZE / 2)
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
