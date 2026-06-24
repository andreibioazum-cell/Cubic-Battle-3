local mode_select = {}

local fontTitle, fontBtn
local btnSingle = { w = 220, h = 75, x = 0, y = 0 }
local btnBack   = { w = 140, h = 55, x = 0, y = 0 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

local function sanitize(str)
    if not str then return "" end
    local result = ""
    local i = 1
    while i <= #str do
        local b = str:byte(i)
        if b < 0x80 then
            if b >= 32 and b <= 126 then
                result = result .. string.char(b)
            else
                result = result .. " "
            end
            i = i + 1
        elseif b >= 0xC2 and b <= 0xDF then
            local b2 = str:byte(i+1)
            if b2 and b2 >= 0x80 and b2 <= 0xBF then
                result = result .. string.char(b, b2)
            else
                result = result .. "?"
            end
            i = i + 2
        elseif b >= 0xE0 and b <= 0xEF then
            local b2 = str:byte(i+1)
            local b3 = str:byte(i+2)
            if b2 and b3 and b2 >= 0x80 and b2 <= 0xBF and b3 >= 0x80 and b3 <= 0xBF then
                result = result .. string.char(b, b2, b3)
            else
                result = result .. "?"
            end
            i = i + 3
        elseif b >= 0xF0 and b <= 0xF4 then
            local b2 = str:byte(i+1)
            local b3 = str:byte(i+2)
            local b4 = str:byte(i+3)
            if b2 and b3 and b4 and b2 >= 0x80 and b2 <= 0xBF and b3 >= 0x80 and b3 <= 0xBF and b4 >= 0x80 and b4 <= 0xBF then
                result = result .. string.char(b, b2, b3, b4)
            else
                result = result .. "?"
            end
            i = i + 4
        else
            result = result .. "?"
            i = i + 1
        end
    end
    return result
end

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

local function drawSpacedText(text, x, y, w, align, font, spacing, alpha)
    alpha = alpha or 1
    text = sanitize(text)
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

    btnSingle.w = 220 * scale
    btnSingle.h = 75 * scale
    btnBack.w   = 140 * scale
    btnBack.h   = 55 * scale

    btnSingle.x = (w - btnSingle.w) / 2
    btnSingle.y = h/2 - 40 * scale

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

    drawSpacedText("SELECT MODE", 0, 120 * scale, w, "center", fontTitle, nil, 1)

    -- Кнопка Singleplayer
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnSingle.x + 5*scale, btnSingle.y + 6*scale, btnSingle.w, btnSingle.h, 16*scale, 16*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnSingle.x, btnSingle.y, btnSingle.w, btnSingle.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnSingle.x, btnSingle.y, btnSingle.w, btnSingle.h, 16*scale, 16*scale)
    drawSpacedText("SINGLEPLAYER", btnSingle.x, btnSingle.y + 22*scale, btnSingle.w, "center", fontBtn, nil, 1)

    -- Кнопка Back
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

    if x >= btnSingle.x and x <= btnSingle.x + btnSingle.w and y >= btnSingle.y and y <= btnSingle.y + btnSingle.h then
        playButtonSound()
        GameState.current = "difficulty"   -- теперь выбор сложности
        return
    end
end

function mode_select.touchmoved() end
function mode_select.touchreleased() end

return mode_select
