-- game.lua – полный игровой модуль (онлайн + офлайн разделены)
local controls = require("controls")
local enemy = require("enemy")
local online = require("online")

local game = {}

SAVE_DATA = SAVE_DATA or { coins = 0, ownedSkin = "NONE", equippedSkin = "NONE" }
SAVE_SAVE = SAVE_SAVE or function() end

local PLAYER_SIZE = 55
local PLAYER_HP_MAX = 5
local BULLET_SPEED = 340 * 1.15

local cube = { x = 0, y = 0, speed = 260, angle = 0, hp = PLAYER_HP_MAX, hit = 0 }
local bullets = {}
local bg, playerImg, azumImg, nastyaImg, bukImg, font
local cam = { x = 0, y = 0 }
local dead = false

local equippedSkin = "NONE"
local resurrectionUsed = false
local currentDifficulty = "normal"
local isOnlineMode = false  -- <-- ОСНОВНОЙ ФЛАГ!

local laserCooldown = 0
local LASER_COOLDOWN = 15
local laserActive = false
local laserTimer = 0
local LASER_DURATION = 0.15
local laserEndX, laserEndY = 0, 0
local LASER_RANGE = 800
local LASER_DAMAGE = 3

local dashCooldown = 0
local dashTimer = 0
local isDashing = false
local DASH_DURATION = 0.2
local DASH_SPEED_MULT = 4
local DASH_COOLDOWN = 10
local dashDirX, dashDirY = 0, 0

-- ============================================================
--  ОТЛАДКА
-- ============================================================
local debugConsole = {
    messages = {},
    maxMessages = 6,
    visible = true,
    lineHeight = 20,
    padding = 6,
    bgColor = {0, 0, 0, 0.75}
}

function game.addDebugMessage(text, color)
    color = color or {1, 1, 1, 1}
    table.insert(debugConsole.messages, {
        text = text,
        color = color,
        time = love.timer.getTime()
    })
    if #debugConsole.messages > debugConsole.maxMessages then
        table.remove(debugConsole.messages, 1)
    end
    print("[DEBUG] " .. text)
end

local function drawDebugConsole()
    if not debugConsole.visible then return end

    local w = love.graphics.getWidth()
    local totalHeight = #debugConsole.messages * debugConsole.lineHeight + debugConsole.padding * 2

    love.graphics.setColor(debugConsole.bgColor[1], debugConsole.bgColor[2],
                           debugConsole.bgColor[3], debugConsole.bgColor[4])
    love.graphics.rectangle("fill", 0, love.graphics.getHeight() - totalHeight,
                                w, totalHeight)

    love.graphics.setColor(0.3, 0.3, 0.5, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, love.graphics.getHeight() - totalHeight, w, love.graphics.getHeight() - totalHeight)

    love.graphics.setFont(font or love.graphics.newFont(14))
    local y = love.graphics.getHeight() - debugConsole.padding - debugConsole.lineHeight
    for i = #debugConsole.messages, 1, -1 do
        local msg = debugConsole.messages[i]
        local age = love.timer.getTime() - msg.time
        local alpha = age > 10 and (1 - (age - 10) / 5) or 1
        if alpha > 0 then
            love.graphics.setColor(msg.color[1], msg.color[2], msg.color[3], msg.color[4] * alpha)
            love.graphics.print(msg.text, debugConsole.padding + 5, y)
            y = y - debugConsole.lineHeight
        end
    end
end

-- ============================================================
--  СНЕЖИНКИ
-- ============================================================
local function drawRealSnowflake(x, y, size, alpha, rotation, twinkle)
    size = size or 3
    alpha = alpha or 1
    rotation = rotation or 0
    twinkle = twinkle or 1

    love.graphics.setColor(1, 1, 1, alpha * twinkle)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)

    for i = 0, 5 do
        local angle = i * math.pi / 3
        love.graphics.push()
        love.graphics.rotate(angle)
        love.graphics.setLineWidth(1)
        love.graphics.line(0, 0, size * 3, 0)
        for j = 1, 2 do
            local pos = j * (size * 1.5)
            love.graphics.line(pos, -size * 0.8, pos, size * 0.8)
        end
        love.graphics.circle("fill", size * 3, 0, size * 0.6)
        love.graphics.pop()
    end

    love.graphics.circle("fill", 0, 0, size * 0.8)
    love.graphics.pop()
end

local snowflakes = {}
local function initSnow()
    local w, h = love.graphics.getDimensions()
    snowflakes = {}
    for i = 1, 200 do
        table.insert(snowflakes, {
            x = math.random(-w/2, w/2),
            y = math.random(-h/2, h/2),
            size = 2 + math.random(4),
            speed = 20 + math.random(60),
            wobble = math.random() * 2 - 1,
            phase = math.random() * 2 * math.pi,
            rotSpeed = (math.random() - 0.5) * 1.5,
            rotation = math.random() * 2 * math.pi,
            alpha = 0.6 + math.random() * 0.4,
        })
    end
end

local function updateSnow(dt)
    local w, h = love.graphics.getDimensions()
    for _, f in ipairs(snowflakes) do
        f.y = f.y + f.speed * dt
        f.x = f.x + math.sin(f.phase + love.timer.getTime() * 0.4 + f.wobble) * 25 * dt
        f.rotation = f.rotation + f.rotSpeed * dt

        if f.y > h/2 + 20 then
            f.y = -h/2 - 20
            f.x = math.random(-w/2, w/2)
            f.rotation = math.random() * 2 * math.pi
        end
        if f.x > w/2 + 20 then
            f.x = -w/2 - 20
        elseif f.x < -w/2 - 20 then
            f.x = w/2 + 20
        end
    end
end

local function drawSnow()
    love.graphics.push()
    love.graphics.translate(cam.x, cam.y)
    for _, f in ipairs(snowflakes) do
        local twinkle = 0.7 + 0.3 * math.sin(f.phase + love.timer.getTime() * 1.2)
        drawRealSnowflake(f.x, f.y, f.size, f.alpha, f.rotation, twinkle)
    end
    love.graphics.pop()
end

-- ============================================================
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================
local function spawnBullet(x, y, dx, dy)
    table.insert(bullets, {
        x = x, y = y,
        vx = dx * BULLET_SPEED,
        vy = dy * BULLET_SPEED,
        dirX = dx, dirY = dy,
        life = 3,
        isDash = false,
        damage = 1
    })
    if _G.playShootSound then _G.playShootSound() end
end

local function spawnDashBullet(x, y, dx, dy)
    table.insert(bullets, {
        x = x, y = y,
        vx = dx * BULLET_SPEED,
        vy = dy * BULLET_SPEED,
        dirX = dx, dirY = dy,
        life = 3,
        isDash = true,
        damage = 3
    })
    if _G.playShootSound then _G.playShootSound() end
end

local function drawHPBar(x, y, w, h, hp, max, color)
    if hp < 0 then hp = 0 end
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 6, 6)
    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("fill", x, y, w * (hp / max), h, 4, 4)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
end

local function onHitPlayer(dmg)
    if dead then return end
    cube.hp = cube.hp - dmg
    cube.hit = 1
    if _G.playHitSound then _G.playHitSound() end
    if cube.hp <= 0 then
        cube.hp = 0
        dead = true
        GameState.current = "lobby"
    end
end

local function fireLaser(px, py, aimX, aimY)
    if aimX == 0 and aimY == 0 then
        aimX, aimY = 0, -1
    end
    local len = math.sqrt(aimX*aimX + aimY*aimY)
    if len > 0 then
        aimX, aimY = aimX/len, aimY/len
    end
    if not isOnlineMode then
        local e, _, _ = enemy.get()
        if e then
            local ex, ey = e.x, e.y
            local dx = ex - px
            local dy = ey - py
            local distToEnemy = math.sqrt(dx*dx + dy*dy)
            if distToEnemy <= LASER_RANGE then
                local dot = aimX * dx + aimY * dy
                if dot > 0 then
                    local cross = aimX * dy - aimY * dx
                    if math.abs(cross) < 20 then
                        laserEndX, laserEndY = ex, ey
                        local killed = enemy.takeDamage(LASER_DAMAGE)
                        if killed then
                            local reward = 10
                            if currentDifficulty == "easy" then reward = 5
                            elseif currentDifficulty == "hard" then reward = 50
                            elseif currentDifficulty == "impossible" then reward = 100 end
                            SAVE_DATA.coins = (SAVE_DATA.coins or 0) + reward
                            SAVE_SAVE()
                            GameState.current = "lobby"
                        end
                        return
                    end
                end
            end
        end
    end
    laserEndX = px + aimX * LASER_RANGE
    laserEndY = py + aimY * LASER_RANGE
end

-- ============================================================
--  ЗАГРУЗКА
-- ============================================================
function game.load()
    -- Определяем режим по GameState
    isOnlineMode = (GameState.current == "game_online")
    
    if isOnlineMode then
        -- ОНЛАЙН
        online.init(SAVE_DATA.nickname or "Player")
        cube.speed = 420
        enemy.reset()
        game.addDebugMessage("ONLINE MODE ACTIVATED", {0.2, 0.8, 0.2, 1})
    else
        -- ОФФЛАЙН
        currentDifficulty = _G.difficulty or "normal"
        enemy.setDifficulty(currentDifficulty)
        enemy.reset()
        cube.speed = 260
        game.addDebugMessage("OFFLINE MODE", {0.5, 0.5, 0.8, 1})
    end

    equippedSkin = SAVE_DATA.equippedSkin or "NONE"
    resurrectionUsed = false
    laserCooldown = 0
    laserActive = false
    laserTimer = 0
    dashCooldown = 0
    dashTimer = 0
    isDashing = false

    local w, h = love.graphics.getDimensions()
    cube.x = w / 2
    cube.y = h / 2
    cube.angle = 0
    cube.hp = PLAYER_HP_MAX
    cube.hit = 0
    dead = false
    bullets = {}
    cam.x, cam.y = -love.graphics.getWidth() / 2, -love.graphics.getHeight() / 2

    bg = bg or love.graphics.newImage("snow.png")
    bg:setWrap("repeat", "repeat")
    playerImg = playerImg or love.graphics.newImage("player.png")
    playerImg:setFilter("nearest", "nearest")
    azumImg = azumImg or love.graphics.newImage("azum.png")
    azumImg:setFilter("nearest", "nearest")
    nastyaImg = nastyaImg or love.graphics.newImage("nastya.png")
    nastyaImg:setFilter("nearest", "nearest")
    bukImg = bukImg or love.graphics.newImage("buk.png")
    bukImg:setFilter("nearest", "nearest")
    font = font or love.graphics.newFont("Fredoka-Bold.ttf", 18)

    controls.load()
    enemy.load()
    initSnow()
end

function game.resize()
    controls.resize()
    initSnow()
end

-- ============================================================
--  ОБНОВЛЕНИЕ
-- ============================================================
function game.update(dt)
    if dead then return end

    controls.update(dt)

    -- ОНЛАЙН: только если включён
    if isOnlineMode and online.isConnected() then
        online.update(dt)
        online.sendPosition(cube.x, cube.y)
    end

    laserCooldown = math.max(0, laserCooldown - dt)
    if laserActive then
        laserTimer = laserTimer - dt
        if laserTimer <= 0 then
            laserActive = false
        end
    end

    if dashCooldown > 0 then
        dashCooldown = dashCooldown - dt
        if dashCooldown < 0 then dashCooldown = 0 end
    end

    if controls.getAbilityTrigger() then
        if equippedSkin == "AZUM CUBE" and not resurrectionUsed and cube.hp <= 1 then
            cube.hp = 5
            resurrectionUsed = true
            cube.hit = 0
            controls.setAbilityAvailable(false)
            if isOnlineMode and online.isConnected() then
                online.sendAbility("revive", cube.x, cube.y)
                game.addDebugMessage("Revive used", {0.2, 0.8, 0.2, 1})
            end
        elseif equippedSkin == "NASTYA CUBE" and laserCooldown <= 0 then
            local aimX, aimY = controls.getAim()
            fireLaser(cube.x, cube.y, aimX, aimY)
            laserActive = true
            laserTimer = LASER_DURATION
            laserCooldown = LASER_COOLDOWN
            controls.setAbilityAvailable(false)
            if _G.playShootSound then _G.playShootSound() end
            if isOnlineMode and online.isConnected() then
                online.sendAbility("laser", cube.x, cube.y, aimX, aimY)
                game.addDebugMessage("Laser fired", {0.9, 0.2, 0.2, 1})
            end
        elseif equippedSkin == "BUK CUBE" and not isDashing and dashCooldown <= 0 then
            local dx, dy = controls.getMove()
            if dx == 0 and dy == 0 then
                dx, dy = controls.getAim()
            end
            if dx ~= 0 or dy ~= 0 then
                local len = math.sqrt(dx*dx + dy*dy)
                if len > 0 then
                    dashDirX, dashDirY = dx/len, dy/len
                else
                    dashDirX, dashDirY = 0, -1
                end
            else
                dashDirX, dashDirY = 0, -1
            end
            isDashing = true
            dashTimer = DASH_DURATION
            dashCooldown = DASH_COOLDOWN
            controls.setAbilityAvailable(false)
            spawnDashBullet(cube.x, cube.y, dashDirX, dashDirY)
            if isOnlineMode and online.isConnected() then
                online.sendAbility("dash", cube.x, cube.y, dashDirX, dashDirY)
                game.addDebugMessage("Dash", {0.3, 0.6, 0.9, 1})
            end
        end
    end

    if equippedSkin == "AZUM CUBE" then
        controls.setAbilityAvailable(not resurrectionUsed and cube.hp <= 1)
    elseif equippedSkin == "NASTYA CUBE" then
        controls.setAbilityAvailable(laserCooldown <= 0)
    elseif equippedSkin == "BUK CUBE" then
        controls.setAbilityAvailable(not isDashing and dashCooldown <= 0)
    else
        controls.setAbilityAvailable(false)
    end

    local dx, dy = controls.getMove()
    cube.x = cube.x + dx * cube.speed * dt
    cube.y = cube.y + dy * cube.speed * dt
    if dx ~= 0 or dy ~= 0 then
        cube.angle = math.atan2(dy, dx) + math.pi / 2
    end
    cube.hit = math.max(0, cube.hit - dt * 3)

    if isDashing then
        dashTimer = dashTimer - dt
        cube.x = cube.x + dashDirX * cube.speed * DASH_SPEED_MULT * dt
        cube.y = cube.y + dashDirY * cube.speed * DASH_SPEED_MULT * dt
        if dashTimer <= 0 then
            isDashing = false
        end
    end

    local targetX = cube.x - love.graphics.getWidth() / 2
    local targetY = cube.y - love.graphics.getHeight() / 2
    local k = 1 - math.exp(-dt * 7.3)
    cam.x = cam.x + (targetX - cam.x) * k
    cam.y = cam.y + (targetY - cam.y) * k

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        if b.life <= 0 then table.remove(bullets, i) end
    end

    -- ОФФЛАЙН: только если не онлайн
    if not isOnlineMode then
        local enemyKilled = enemy.update(dt, cube.x, cube.y, bullets, onHitPlayer)
        if enemyKilled then
            local reward = 10
            if currentDifficulty == "easy" then reward = 5
            elseif currentDifficulty == "hard" then reward = 50
            elseif currentDifficulty == "impossible" then reward = 100 end
            SAVE_DATA.coins = (SAVE_DATA.coins or 0) + reward
            SAVE_SAVE()
            GameState.current = "lobby"
            return
        end

        local eBullets = enemy.getBullets()
        for i = #eBullets, 1, -1 do
            local b = eBullets[i]
            local bx = b.x - cube.x
            local by = b.y - cube.y
            if bx * bx + by * by <= (PLAYER_SIZE * 0.5) ^ 2 then
                onHitPlayer(1)
                table.remove(eBullets, i)
                if dead then return end
            end
        end
    end

    updateSnow(dt)
end

-- ============================================================
--  ОТРИСОВКА
-- ============================================================
function game.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(-cam.x, -cam.y)

    local w, h = love.graphics.getDimensions()
    local tw, th = bg:getWidth(), bg:getHeight()
    local sX = math.floor(cam.x / tw) * tw
    local sY = math.floor(cam.y / th) * th
    for x = sX, sX + w + tw, tw do
        for y = sY, sY + h + th, th do
            love.graphics.draw(bg, x, y)
        end
    end

    drawSnow()

    for _, b in ipairs(bullets) do
        if b.isDash then
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.circle("fill", b.x, b.y, 12)
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.circle("line", b.x, b.y, 12)
        else
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.circle("fill", b.x, b.y, 8)
        end
    end

    -- ОНЛАЙН: пули других игроков
    if isOnlineMode then
        for id, b in pairs(online.getBullets()) do
            if b.owner ~= online.getMyUid() then
                love.graphics.setColor(1, 0.2, 0.2, 1)
                love.graphics.circle("fill", b.x, b.y, 6)
            end
        end
    end

    -- ОНЛАЙН: способности
    if isOnlineMode then
        local onlineAbilities = online.getAbilities() or {}
        for aid, ab in pairs(onlineAbilities) do
            if ab.type == "laser" then
                love.graphics.setColor(1, 0, 0, 0.6)
                love.graphics.setLineWidth(5)
                love.graphics.line(ab.x, ab.y, ab.x + ab.dirX * 800, ab.y + ab.dirY * 800)
            elseif ab.type == "dash" then
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.circle("fill", ab.x, ab.y, 30)
            elseif ab.type == "revive" then
                love.graphics.setColor(0, 1, 0, 0.3)
                love.graphics.circle("fill", ab.x, ab.y, 40)
            end
        end
    end

    -- ВРАГ: только офлайн
    if not isOnlineMode then
        enemy.drawBullets()
        enemy.draw()
    end

    -- ОНЛАЙН: другие игроки
    if isOnlineMode then
        for id, p in pairs(online.getPlayers()) do
            if id ~= online.getMyUid() then
                local imgToDraw
                if p.skin == "AZUM CUBE" then
                    imgToDraw = azumImg
                elseif p.skin == "NASTYA CUBE" then
                    imgToDraw = nastyaImg
                elseif p.skin == "BUK CUBE" then
                    imgToDraw = bukImg
                else
                    imgToDraw = playerImg
                end

                love.graphics.setColor(0, 0, 0, 0.3)
                love.graphics.draw(imgToDraw, p.x - PLAYER_SIZE/2 + 4, p.y - PLAYER_SIZE/2 + 6, 0, 1, 1)

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(imgToDraw, p.x - PLAYER_SIZE/2, p.y - PLAYER_SIZE/2, 0, 1, 1)

                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.setFont(font)
                local nick = p.nickname or "???"
                local nickW = font:getWidth(nick)
                love.graphics.rectangle("fill", p.x - nickW/2 - 4, p.y - 40, nickW + 8, 22, 4, 4)

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(nick, p.x - nickW/2, p.y - 38)
            end
        end
    end

    if controls.isAiming() then
        local ax, ay = controls.getAim()
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.setLineWidth(16)
        love.graphics.line(cube.x, cube.y, cube.x + ax * 180, cube.y + ay * 180)
    end

    if laserActive then
        love.graphics.setLineWidth(8)
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.line(cube.x, cube.y, laserEndX, laserEndY)
        love.graphics.setLineWidth(3)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.line(cube.x, cube.y, laserEndX, laserEndY)
        love.graphics.setLineWidth(18)
        love.graphics.setColor(1, 0, 0, 0.2)
        love.graphics.line(cube.x, cube.y, laserEndX, laserEndY)
        love.graphics.setLineWidth(1)
    end

    local imgToDraw
    if equippedSkin == "AZUM CUBE" then
        imgToDraw = azumImg
    elseif equippedSkin == "NASTYA CUBE" then
        imgToDraw = nastyaImg
    elseif equippedSkin == "BUK CUBE" then
        imgToDraw = bukImg
    else
        imgToDraw = playerImg
    end

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.push()
    love.graphics.translate(cube.x + 6, cube.y + 8)
    love.graphics.rotate(cube.angle)
    love.graphics.draw(imgToDraw, -PLAYER_SIZE / 2, -PLAYER_SIZE / 2)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(cube.x, cube.y)
    love.graphics.rotate(cube.angle)
    local t = cube.hit
    love.graphics.setColor(1, 1 - t * 0.6, 1 - t * 0.6, 1)
    love.graphics.draw(imgToDraw, -PLAYER_SIZE / 2, -PLAYER_SIZE / 2)
    love.graphics.pop()

    if isDashing then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.circle("fill", cube.x, cube.y, PLAYER_SIZE * 1.2)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", cube.x, cube.y, PLAYER_SIZE * 1.2)
    end

    love.graphics.pop()

    -- HUD
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    local barW, barH = 200, 18
    local px, py = 20, 20

    drawHPBar(px, py, barW, barH, cube.hp, PLAYER_HP_MAX, {0.3, 0.85, 0.35})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("HP " .. math.max(0, cube.hp) .. " / " .. PLAYER_HP_MAX, px, py + 22, barW, "left")

    if not isOnlineMode then
        local diffText = "NORMAL"
        if currentDifficulty == "easy" then diffText = "EASY" end
        if currentDifficulty == "hard" then diffText = "HARD" end
        if currentDifficulty == "impossible" then diffText = "IMPOSSIBLE" end
        love.graphics.printf("DIFFICULTY: " .. diffText, px, py + 44, 200, "left")
    else
        love.graphics.printf("ONLINE PVP", px, py + 44, 200, "left")
        local playerCount = 0
        for _ in pairs(online.getPlayers()) do
            playerCount = playerCount + 1
        end
        love.graphics.printf("Players: " .. playerCount, px, py + 66, 200, "left")
    end

    if equippedSkin == "BUK CUBE" then
        local cd = math.max(0, dashCooldown)
        if isDashing then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("DASH!", px, py + 88, 200, "left")
        elseif cd > 0 then
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
            love.graphics.printf("DASH CD: " .. math.ceil(cd) .. "s", px, py + 88, 200, "left")
        else
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("DASH READY", px, py + 88, 200, "left")
        end
    elseif equippedSkin == "NASTYA CUBE" then
        local cd = math.max(0, laserCooldown)
        if cd > 0 then
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
            love.graphics.printf("LASER CD: " .. math.ceil(cd) .. "s", px, py + 88, 200, "left")
        else
            love.graphics.setColor(1, 0.2, 0.2, 0.8)
            love.graphics.printf("LASER READY", px, py + 88, 200, "left")
        end
    end

    if not isOnlineMode then
        local e, _, enemyMaxHP = enemy.get()
        if e then
            local epx = love.graphics.getWidth() - barW - 20
            local epy = 20
            drawHPBar(epx, epy, barW, barH, e.hp, enemyMaxHP, {0.9, 0.2, 0.2})
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("ENEMY " .. math.max(0, e.hp) .. " / " .. enemyMaxHP, epx, epy + 22, barW, "right")
        end
    end

    if isOnlineMode then
        local debugText = online.getDebugText()
        if debugText then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(font)
            love.graphics.printf(debugText, 20, love.graphics.getHeight() - 120, love.graphics.getWidth() - 40, "left")
        end
    end

    drawDebugConsole()
    controls.draw()
end

-- ============================================================
--  ОБРАБОТКА КАСАНИЙ
-- ============================================================
function game.touchpressed(id, x, y)
    controls.touchpressed(id, x, y)
end

function game.touchmoved(id, x, y)
    controls.touchmoved(id, x, y)
end

function game.touchreleased(id, x, y)
    local shot, dx, dy = controls.touchreleased(id)
    if shot then
        spawnBullet(cube.x, cube.y, dx, dy)
        if isOnlineMode and online.isConnected() then
            online.sendBullet(cube.x, cube.y, dx, dy)
        end
    end
end

function game.spawnPlayerBullet(dx, dy)
    if dead then return end
    spawnBullet(cube.x, cube.y, dx, dy, false)
    if isOnlineMode and online.isConnected() then
        online.sendBullet(cube.x, cube.y, dx, dy)
    end
end

function game.getPlayerPosition()
    return cube.x, cube.y
end

return game
