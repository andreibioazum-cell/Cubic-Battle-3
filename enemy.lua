local enemy = {}

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

-- ========== НОВЫЕ ПАРАМЕТРЫ ДЛЯ УМЕНЬШЕНИЯ СЛОЖНОСТИ ==========
local DODGE_CHANCE = 0.25          -- 25% шанс уклонения (было 100%)
local SHOOT_ACCURACY = 0.6         -- 60% точность стрельбы
local REACTION_DELAY = 0.3         -- Задержка реакции на пули (сек)
local SHOOT_SPREAD = 0.3           -- Разброс при стрельбе (радианы)
local DODGE_COOLDOWN = 1.5         -- Задержка между уклонениями
local MAX_DODGE_TIME = 0.5         -- Максимальное время уклонения

local e
local timer = 0
local img
local eBullets = {}

-- ========== ПЕРЕМЕННЫЕ ДЛЯ СОСТОЯНИЙ ВРАГА ==========
local dodgeTimer = 0
local lastDodgeTime = 0
local reactionTimer = 0
local currentDodgeDir = 1

local function spawnBullet(x, y, dx, dy)
    table.insert(eBullets, {
        x=x, y=y,
        vx=dx*BULLET_SPEED,
        vy=dy*BULLET_SPEED,
        life=3
    })
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
        -- Новые переменные состояния
        dodgeCooldown = 0,
        isDodging = false,
        dodgeTime = 0,
        shootAccuracy = SHOOT_ACCURACY + (math.random() - 0.5) * 0.2
    }
end

function enemy.load()
    img = love.graphics.newImage("player.png")
    img:setFilter("nearest","nearest")
end

function enemy.reset()
    e = nil
    timer = 0
    eBullets = {}
    dodgeTimer = 0
    lastDodgeTime = 0
    reactionTimer = 0
end

function enemy.get()
    return e, SIZE, MAX_HP
end

function enemy.getBullets()
    return eBullets
end

function enemy.update(dt, px, py, playerBullets, onHitPlayer)
    -- Обновление пуль врага
    for i=#eBullets, 1, -1 do
        local b = eBullets[i]
        b.x = b.x + b.vx*dt
        b.y = b.y + b.vy*dt
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

    local dx = px - e.x
    local dy = py - e.y
    local dist = math.sqrt(dx*dx + dy*dy) + 0.0001
    local nx, ny = dx/dist, dy/dist

    -- ========== УМЕНЬШЕННАЯ ЛОГИКА УКЛОНЕНИЯ ==========
    local dodging = false
    local dodgeDx, dodgeDy = 0, 0
    
    -- Обновляем таймеры
    if e.dodgeCooldown > 0 then
        e.dodgeCooldown = e.dodgeCooldown - dt
    end
    
    if e.isDodging then
        e.dodgeTime = e.dodgeTime - dt
        if e.dodgeTime <= 0 then
            e.isDodging = false
        end
    end

    -- Проверяем пули только если не на кулдауне и не уклоняется
    if not e.isDodging and e.dodgeCooldown <= 0 then
        for _, b in ipairs(playerBullets) do
            local bx = b.x - e.x
            local by = b.y - e.y
            local distToBullet = math.sqrt(bx*bx + by*by)
            
            if distToBullet < DODGE_RADIUS then
                local dot = bx*b.vx + by*b.vy
                if dot < 0 then
                    -- ========== ШАНС УКЛОНЕНИЯ ==========
                    if math.random() < DODGE_CHANCE then
                        dodging = true
                        local cross = b.vx * by - b.vy * bx
                        if cross > 0 then
                            dodgeDx, dodgeDy = b.vy, -b.vx
                        else
                            dodgeDx, dodgeDy = -b.vy, b.vx
                        end
                        local dLen = math.sqrt(dodgeDx*dodgeDx + dodgeDy*dodgeDy) + 0.0001
                        dodgeDx, dodgeDy = dodgeDx/dLen, dodgeDy/dLen
                        
                        e.isDodging = true
                        e.dodgeTime = MAX_DODGE_TIME
                        e.dodgeCooldown = DODGE_COOLDOWN
                        
                        -- Меняем направление стрейфа после уклонения
                        e.strafeDir = math.random() > 0.5 and 1 or -1
                        break
                    end
                end
            end
        end
    end

    if e.isDodging then
        e.state = "dodge"
        e.x = e.x + dodgeDx * DODGE_SPEED * dt
        e.y = e.y + dodgeDy * DODGE_SPEED * dt
    else
        -- ========== ОСНОВНАЯ ЛОГИКА СОСТОЯНИЙ ==========
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
            -- Стрейф вокруг игрока (медленнее)
            local sDx = -ny * e.strafeDir
            local sDy =  nx * e.strafeDir
            e.x = e.x + sDx * SPEED * 0.3 * dt  -- Уменьшено с 0.5 до 0.3
            e.y = e.y + sDy * SPEED * 0.3 * dt

            -- ========== СТРЕЛЬБА С НЕТОЧНОСТЬЮ ==========
            e.shootT = e.shootT - dt
            if e.shootT <= 0 then
                e.shootT = SHOOT_CD
                
                -- ========== ДОБАВЛЯЕМ РАЗБРОС ==========
                local spread = (math.random() - 0.5) * SHOOT_SPREAD * 2
                local angle = math.atan2(dy, dx) + spread
                local sDx = math.cos(angle)
                local sDy = math.sin(angle)
                
                -- ========== ШАНС ПРОМАХА ==========
                if math.random() < e.shootAccuracy then
                    spawnBullet(e.x, e.y, sDx, sDy)
                else
                    -- Промах - стреляем в случайном направлении
                    local missAngle = math.random() * math.pi * 2
                    spawnBullet(e.x, e.y, math.cos(missAngle), math.sin(missAngle))
                end
                
                -- Меняем направление стрейфа после выстрела
                if math.random() > 0.7 then e.strafeDir = -e.strafeDir end
            end
        elseif e.state == "wander" then
            e.wanderT = e.wanderT - dt
            if e.wanderT <= 0 then
                e.wanderT = 1.5 + math.random() * 2.5  -- Дольше бродит
                local a = math.random() * math.pi * 2
                e.wanderDX = math.cos(a)
                e.wanderDY = math.sin(a)
            end
            e.x = e.x + e.wanderDX * SPEED * 0.25 * dt  -- Медленнее бродит
            e.y = e.y + e.wanderDY * SPEED * 0.25 * dt
        end
    end

    e.angle = math.atan2(dy, dx) + math.pi/2
    e.hit = math.max(0, e.hit - dt*3)

    -- ========== КОЛЛИЗИЯ ПУЛЬ ИГРОКА С ВРАГОМ ==========
    for i=#playerBullets,1,-1 do
        local b = playerBullets[i]
        local bx = b.x - e.x
        local by = b.y - e.y
        if bx*bx + by*by <= (SIZE*0.55)^2 then
            e.hp = e.hp - 1
            e.hit = 1
            table.remove(playerBullets, i)
            if e.hp <= 0 then
                e = nil
                return true
            end
        end
    end

    return false
end

function enemy.draw()
    if not e then return end

    love.graphics.setColor(0,0,0,0.4)
    love.graphics.push()
    love.graphics.translate(e.x + 6, e.y + 8)
    love.graphics.rotate(e.angle)
    love.graphics.draw(img, -SIZE/2, -SIZE/2)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(e.x, e.y)
    love.graphics.rotate(e.angle)
    local t = e.hit
    love.graphics.setColor(1, 1 - t*0.8, 1 - t*0.8, 1)
    love.graphics.draw(img, -SIZE/2, -SIZE/2)
    love.graphics.pop()

    love.graphics.setColor(1,1,1,1)
end

function enemy.drawBullets()
    love.graphics.setColor(1, 0.2, 0.2, 1)
    for _, b in ipairs(eBullets) do
        love.graphics.circle("fill", b.x, b.y, 8)
    end
    love.graphics.setColor(1,1,1,1)
end

return enemy
