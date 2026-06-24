local mode_select = {}

local fontTitle, fontBtn
local btnCreate = { w = 220, h = 75, x = 0, y = 0 }
local btnJoin   = { w = 220, h = 75, x = 0, y = 0 }
local btnBack   = { w = 140, h = 55, x = 0, y = 0 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

local function drawSpacedText(text, x, y, w, align, font, spacing, alpha)
    alpha = alpha or 1
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    local startX = x
    if align == "center" then
        startX = x + (w - tw) / 2
    elseif align == "right" then
        startX = x + (w - tw)
    end
    local shadow = 2
    love.graphics.setColor(0, 0, 0, alpha * 0.8)
    love.graphics.print(text, startX + shadow, y + shadow)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, startX, y)
end

function mode_select.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    btnCreate.w = 220 * scale
    btnCreate.h = 75 * scale
    btnJoin.w   = 220 * scale
    btnJoin.h   = 75 * scale
    btnBack.w   = 140 * scale
    btnBack.h   = 55 * scale

    btnCreate.x = (w - btnCreate.w) / 2
    btnCreate.y = h/2 - 40 * scale

    btnJoin.x = (w - btnJoin.w) / 2
    btnJoin.y = h/2 + 80 * scale

    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 100 * scale

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function mode_select.resize()
    mode_select.load()
end

function mode_select.draw()
    love.graphics.setColor(0.05, 0.02, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()

    drawSpacedText("MULTIPLAYER", 0, 120 * scale, w, "center", fontTitle, nil, 1)

    -- Кнопка Create Game
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnCreate.x + 5*scale, btnCreate.y + 6*scale, btnCreate.w, btnCreate.h, 16*scale, 16*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnCreate.x, btnCreate.y, btnCreate.w, btnCreate.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnCreate.x, btnCreate.y, btnCreate.w, btnCreate.h, 16*scale, 16*scale)
    drawSpacedText("CREATE GAME", btnCreate.x, btnCreate.y + 22*scale, btnCreate.w, "center", fontBtn, nil, 1)

    -- Кнопка Join Game
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnJoin.x + 5*scale, btnJoin.y + 6*scale, btnJoin.w, btnJoin.h, 16*scale, 16*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnJoin.x, btnJoin.y, btnJoin.w, btnJoin.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnJoin.x, btnJoin.y, btnJoin.w, btnJoin.h, 16*scale, 16*scale)
    drawSpacedText("JOIN GAME", btnJoin.x, btnJoin.y + 22*scale, btnJoin.w, "center", fontBtn, nil, 1)

    -- Back
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4*scale, btnBack.y + 5*scale, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    drawSpacedText("BACK", btnBack.x, btnBack.y + 14*scale, btnBack.w, "center", fontBtn, nil, 1)
end

function mode_select.touchpressed(id, x, y)
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        playButtonSound()
        GameState.current = "lobby"
        return
    end
    if x >= btnCreate.x and x <= btnCreate.x + btnCreate.w and y >= btnCreate.y and y <= btnCreate.y + btnCreate.h then
        playButtonSound()
        GameState.current = "multiplayer"
        GameState.multiplayerMode = "host"
        return
    end
    if x >= btnJoin.x and x <= btnJoin.x + btnJoin.w and y >= btnJoin.y and y <= btnJoin.y + btnJoin.h then
        playButtonSound()
        GameState.current = "multiplayer"
        GameState.multiplayerMode = "client"
        return
    end
end

function mode_select.touchmoved() end
function mode_select.touchreleased() end

return mode_select
