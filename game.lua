local controls = require("controls")
local enemy = require("enemy")
local online = require("online")

local game = {}

local PLAYER_SIZE = 55
local PLAYER_HP_MAX = 5
local cube = { x = 0, y = 0, speed = 260, angle = 0, hp = PLAYER_HP_MAX, hit = 0 }
local bullets = {}
local cam = { x = 0, y = 0 }
local snowflakes = {}
local playerImg, azumImg, nastyaImg, bukImg, bgImg

-- Твоя функция снежинок
local function drawRealSnowflake(x, y, size, alpha, rotation, twinkle)
    love.graphics.setColor(1, 1, 1, alpha * twinkle)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    for i = 0, 5 do
        local angle = i * math.pi / 3
        love.graphics.push()
        love.graphics.rotate(angle)
        love.graphics.line(0, 0, size * 3, 0)
        love.graphics.pop()
    end
    love.graphics.pop()
end

function game.load()
    local w, h = love.graphics.getDimensions()
    cube.x, cube.y = w/2, h/2
    cube.hp = PLAYER_HP_MAX
    bullets = {}
    
    playerImg = love.graphics.newImage("player.png")
    azumImg = love.graphics.newImage("azum.png")
    nastyaImg = love.graphics.newImage("nastya.png")
    bukImg = love.graphics.newImage("buk.png")
    bgImg = love.graphics.newImage("snow.png")
    bgImg:setWrap("repeat", "repeat")

    -- Инициализация снега
    snowflakes = {}
    for i = 1, 100 do
        table.insert(snowflakes, {x = math.random(w), y = math.random(h), size = 2+math.random(3), speed = 30+math.random(50), phase = math.random()*10})
    end

    if not online.isConnected() then
        enemy.setDifficulty(_G.difficulty or "normal")
        enemy.reset()
    end
end

function game.update(dt)
    local dx, dy = controls.getMove()
    cube.x = cube.x + dx * cube.speed * dt
    cube.y = cube.y + dy * cube.speed * dt
    if dx ~= 0 or dy ~= 0 then cube.angle = math.atan2(dy, dx) + math.pi / 2 end

    -- Движение снега
    local w, h = love.graphics.getDimensions()
    for _, s in ipairs(snowflakes) do
        s.y = s.y + s.speed * dt
        if s.y > h then s.y = -10; s.x = math.random(w) end
    end

    -- Камера
    cam.x = cam.x + (cube.x - w/2 - cam.x) * dt * 5
    cam.y = cam.y + (cube.y - h/2 - cam.y) * dt * 5

    -- Пули
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt; b.y = b.y + b.vy * dt
        if math.abs(b.x - cube.x) > 1000 then table.remove(bullets, i) end
    end

    if not online.isConnected() then
        enemy.update(dt, cube.x, cube.y, bullets, function() cube.hp = cube.hp - 1 end)
    end
end

function game.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.translate(-cam.x, -cam.y)

    -- Фон
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.draw(bgImg, cam.x, cam.y, 0, w/bgImg:getWidth()*2, h/bgImg:getHeight()*2)

    -- Снег
    for _, s in ipairs(snowflakes) do
        drawRealSnowflake(cam.x + s.x, cam.y + s.y, s.size, 0.8, 0, 1)
    end

    -- Другие игроки
    if online.isConnected() then
        for id, p in pairs(online.getPlayers()) do
            local img = playerImg
            if p.skin == "AZUM CUBE" then img = azumImg
            elseif p.skin == "NASTYA CUBE" then img = nastyaImg
            elseif p.skin == "BUK CUBE" then img = bukImg end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, p.x - PLAYER_SIZE/2, p.y - PLAYER_SIZE/2)
            love.graphics.printf(p.nickname, p.x - 50, p.y - 45, 100, "center")
        end
    else
        enemy.draw()
    end

    -- Наш игрок
    local myImg = playerImg
    local s = SAVE_DATA.equippedSkin
    if s == "AZUM CUBE" then myImg = azumImg
    elseif s == "NASTYA CUBE" then myImg = nastyaImg
    elseif s == "BUK CUBE" then myImg = bukImg end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(cube.x, cube.y)
    love.graphics.rotate(cube.angle)
    love.graphics.draw(myImg, -PLAYER_SIZE/2, -PLAYER_SIZE/2)
    love.graphics.pop()

    -- Пули
    love.graphics.setColor(0, 0, 0)
    for _, b in ipairs(bullets) do love.graphics.circle("fill", b.x, b.y, 6) end

    love.graphics.pop()

    -- UI
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("HP: " .. cube.hp, 20, 20)
    if online.isConnected() then love.graphics.print("ROOM: " .. (_G.roomCode or ""), 20, 40) end
end

function game.spawnPlayerBullet(dx, dy)
    table.insert(bullets, {x = cube.x, y = cube.y, vx = dx * 550, vy = dy * 550})
    if _G.playShootSound then _G.playShootSound() end
end

function game.getPlayerPosition() return cube.x, cube.y end

return game
