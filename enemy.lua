local enemy = {}

local SIZE = 55
local SPEED = 140
local SIGHT = 650
local SHOOT_RANGE = 450 -- Дальнобойная атака
local KEEP_DIST = 150   -- Дистанция, на которой враг убегает
local MAX_HP = 10       -- Чуть больше ХП, так как он уворачивается
local RESPAWN = 2
local SHOOT_CD = 1.2
local BULLET_SPEED = 220
local DODGE_RADIUS = 140 -- Радиус реагирования на пули игрока
local DODGE_SPEED = 320  -- Скорость рывка уклонения

local e
local timer = 0
local img
local eBullets = {} -- Пули врага

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
        shootT = SHOOT_CD * 0.5, -- Начальная задержка перед выстрелом
        strafeDir = math.random() > 0.5 and 1 or -1 -- Направление стрейфа
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

    -- ЛОГИКА УКЛОНЕНИЯ ОТ ПУЛЬ ИГРОКА
    local dodging = false
    local dodgeDx, dodgeDy = 0, 0
    
    for _, b in ipairs(playerBullets) do
        local bx = b.x - e.x
        local by = b.y - e.y
        local distToBullet = math.sqrt(bx*bx + by*by)
        
        if distToBullet < DODGE_RADIUS then
            -- Проверяем, летит ли пуля в нашу сторону
            local dot = bx*b.vx + by*b.vy
            if dot < 0 then -- Пуля летит к нам
                dodging = true
                -- Вычисляем перпендикуляр для уклонения
                -- Вектор пули (b.vx, b.vy). Перпендикуляр: (-b.vy, b.vx) или (b.vy, -b.vx)
                local cross = b.vx * by - b.vy * bx
                if cross > 0 then
                    dodgeDx, dodgeDy = b.vy, -b.vx
                else
                    dodgeDx, dodgeDy = -b.vy, b.vx
                end
                local dLen = math.sqrt(dodgeDx*dodgeDx + dodgeDy*dodgeDy) + 0.0001
                dodgeDx, dodgeDy = dodgeDx/dLen, dodgeDy/dLen
                break -- Уклоняемся от ближайшей угрозы
            end
        end
    end

    if dodging then
        e.state = "dodge"
        e.x = e.x + dodgeDx * DODGE_SPEED * dt
        e.y = e.y + dodgeDy * DODGE_SPEED * dt
    else
        -- ОСНОВНАЯ ЛОГИКА СОСТОЯНИЙ
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
            -- Стрейф вокруг игрока
            local sDx = -ny * e.strafeDir
            local sDy =  nx * e.strafeDir
            e.x = e.x + sDx * SPEED * 0.5 * dt
            e.y = e.y + sDy * SPEED * 0.5 * dt

            -- Стрельба
            e.shootT = e.shootT - dt
            if e.shootT <= 0 then
                e.shootT = SHOOT_CD
                spawnBullet(e.x, e.y, nx, ny)
                -- Меняем направление стрейфа после выстрела
                if math.random() > 0.6 then e.strafeDir = -e.strafeDir end
            end
        elseif e.state == "wander" then
            e.wanderT = e.wanderT - dt
            if e.wanderT <= 0 then
                e.wanderT = 1 + math.random() * 2
                local a = math.random() * math.pi * 2
                e.wanderDX = math.cos(a)
                e.wanderDY = math.sin(a)
            end
            e.x = e.x + e.wanderDX * SPEED * 0.35 * dt
            e.y = e.y + e.wanderDY * SPEED * 0.35 * dt
        end
    end

    e.angle = math.atan2(dy, dx) + math.pi/2
    e.hit = math.max(0, e.hit - dt*3)

    -- Коллизия пуль игрока с врагом
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
                return true -- Враг убит
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
    -- Слегка меняем цвет врага, чтобы отличался от игрока (красноватый оттенок при получении урона)
    love.graphics.setColor(1, 1 - t*0.8, 1 - t*0.8, 1)
    love.graphics.draw(img, -SIZE/2, -SIZE/2)
    love.graphics.pop()

    love.graphics.setColor(1,1,1,1)
end

function enemy.drawBullets()
    -- Отрисовка пуль врага (красные)
    love.graphics.setColor(1, 0.2, 0.2, 1)
    for _, b in ipairs(eBullets) do
        love.graphics.circle("fill", b.x, b.y, 8)
    end
    love.graphics.setColor(1,1,1,1)
end

return enemy
