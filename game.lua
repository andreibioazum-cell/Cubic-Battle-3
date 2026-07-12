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
local playerImg, azumImg, nastyaImg, bukImg, bgImg, font

local function drawRealSnowflake(x, y, size, alpha, rotation, twinkle)
    love.graphics.setColor(1, 1, 1, alpha * twinkle)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    for i = 0, 5 do
        local angle = i * math.pi / 3
        love.graphics.push()
        love.graphics.rotate(angle)
        love.graphics.line(0, 0, size * 2.5, 0)
        love.graphics.pop()
    end
    love.graphics.pop()
end

function game.load()
    local w, h = love.graphics.getDimensions()
    cube.x, cube.y = w/2, h/2
    cube.hp = PLAYER_HP_MAX
    bullets = {}
    
    -- Безопасная загрузка ресурсов
    local function loadImg(path)
        local ok, img = pcall(love.graphics.newImage, path)
        return ok and img or nil
    end

    playerImg = loadImg("player.png")
    azumImg = loadImg("azum.png")
    nastyaImg = loadImg("nastya.png")
    bukImg = loadImg("buk.png")
    bgImg = loadImg("snow.png")
    if bgImg then bgImg:setWrap("repeat", "repeat") end
    font = love.graphics.newFont(16)

    snowflakes = {}
    for i = 1, 80 do
        table.insert(snowflakes, {x = math.random(w), y = math.random(h), size = math.random(2, 4), speed = math.random(40, 90)})
    end

    if not online.isConnected() then
        enemy.setDifficulty(_G.difficulty or "normal")
        enemy.reset()
    end
end

function game.resize(w, h)
    controls.resize()
end

function game.update(dt)
    local dx, dy = controls.getMove()
    cube.x = cube.x + dx * cube.speed * dt
    cube.y = cube.y + dy * cube.speed * dt
    if dx ~= 0 or dy ~= 0 then cube.angle = math.atan2(dy, dx) + math.pi / 2 end

    local w, h = love.graphics.getDimensions()
    for _, s in ipairs(snowflakes) do
        s.y = s.y + s.speed * dt
        if s.y > h then s.y = -10; s.x = math.random(w) end
    end

    cam.x = cam.x + (cube.x - w/2 - cam.x) * dt * 5
    cam.y = cam.y + (cube.y - h/2 - cam.y) * dt * 5

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt; b.y = b.y + b.vy * dt
        if math.abs(b.x - cube.x) > 1200 then table.remove(bullets, i) end
    end

    if not online.isConnected() then
        enemy.update(dt, cube.x, cube.y, bullets, function() cube.hp = cube.hp - 1 end)
    end
end

function game.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.translate(-cam.x, -cam.y)

    -- Фон (тайловый)
    if bgImg then
        love.graphics.setColor(1, 1, 1, 0.4)
        local tw, th = bgImg:getDimensions()
        for x = -1, 2 do
            for y = -1, 2 do
                love.graphics.draw(bgImg, cam.x + x*tw, cam.y + y*th)
            end
        end
    end

    -- Снег
    for _, s in ipairs(snowflakes) do
        drawRealSnowflake(cam.x + s.x, cam.y + s.y, s.size, 0.7, 0, 1)
    end

    -- Отрисовка других игроков
    if online.isConnected() then
        for id, p in pairs(online.getPlayers()) do
            local img = playerImg
            if p.skin == "AZUM CUBE" then img = azumImg
            elseif p.skin == "NASTYA CUBE" then img = nastyaImg
            elseif p.skin == "BUK CUBE" then img = bukImg end
            
            love.graphics.setColor(1, 1, 1, 1)
            if img then love.graphics.draw(img, p.x - PLAYER_SIZE/2, p.y - PLAYER_SIZE/2) end
            
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", p.x - 40, p.y - 55, 80, 20, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(p.nickname, p.x - 40, p.y - 53, 80, "center")
        end
    else
        enemy.draw()
    end

    -- Наш игрок
    local myImg = playerImg
    local curSkin = SAVE_DATA.equippedSkin
    if curSkin == "AZUM CUBE" then myImg = azumImg
    elseif curSkin == "NASTYA CUBE" then myImg = nastyaImg
    elseif curSkin == "BUK CUBE" then myImg = bukImg end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(cube.x, cube.y)
    love.graphics.rotate(cube.angle)
    if myImg then love.graphics.draw(myImg, -PLAYER_SIZE/2, -PLAYER_SIZE/2) end
    love.graphics.pop()

    -- Пули
    love.graphics.setColor(0, 0, 0)
    for _, b in ipairs(bullets) do love.graphics.circle("fill", b.x, b.y, 7) end

    love.graphics.pop()

    -- UI (HP)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 15, 15, 150, 30, 5)
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", 20, 20, 140 * (cube.hp/PLAYER_HP_MAX), 20, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. cube.hp, 25, 22)
end

function game.spawnPlayerBullet(dx, dy)
    table.insert(bullets, {x = cube.x, y = cube.y, vx = dx * 600, vy = dy * 600})
    if _G.playShootSound then _G.playShootSound() end
end

function game.getPlayerPosition() return cube.x, cube.y end

return game
