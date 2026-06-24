local settings = {}

local fontTitle, fontBtn
local btnBack = { w = 140, h = 55, x = 0, y = 30 }
local btnNick = { w = 300, h = 60, x = 0, y = 0 }
local btnIP = { w = 300, h = 60, x = 0, y = 0 }
local enteringNick = false
local enteringIP = false
local tempNick = ""
local tempIP = ""

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

-- ===== ФУНКЦИЯ ОЧИСТКИ UTF-8 (без внешних зависимостей) =====
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

function settings.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    btnBack.w = 140 * scale
    btnBack.h = 55 * scale
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 80 * scale

    btnNick.w = 300 * scale
    btnNick.h = 60 * scale
    btnNick.x = (w - btnNick.w) / 2
    btnNick.y = h/2 - 60 * scale

    btnIP.w = 300 * scale
    btnIP.h = 60 * scale
    btnIP.x = (w - btnIP.w) / 2
    btnIP.y = h/2 + 60 * scale

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)

    if SAVE_DATA.nickname then
        SAVE_DATA.nickname = sanitize(SAVE_DATA.nickname)
    end
    tempNick = SAVE_DATA.nickname or "Player"
    tempIP = SAVE_DATA.serverIP or "127.0.0.1"
end

function settings.resize()
    settings.load()
end

function settings.draw()
    love.graphics.setColor(0.05, 0.02, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local scale = getScale()

    drawSpacedText("SETTINGS", 0, 80*scale, w, "center", fontTitle, nil, 1)

    local currentNick = SAVE_DATA.nickname or "Player"
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fontBtn)
    love.graphics.printf("Nickname: " .. sanitize(currentNick), 0, btnNick.y - 60*scale, w, "center")

    local label = enteringNick and "Press ENTER to save" or "Change Nickname"
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnNick.x + 5*scale, btnNick.y + 6*scale, btnNick.w, btnNick.h, 16*scale, 16*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnNick.x, btnNick.y, btnNick.w, btnNick.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnNick.x, btnNick.y, btnNick.w, btnNick.h, 16*scale, 16*scale)
    drawSpacedText(label, btnNick.x, btnNick.y + 18*scale, btnNick.w, "center", fontBtn, nil, 1)

    if enteringNick then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf("New nick: " .. sanitize(tempNick) .. "|", 0, btnNick.y + 80*scale, w, "center")
    end

    local currentIP = SAVE_DATA.serverIP or "127.0.0.1"
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Server IP: " .. sanitize(currentIP), 0, btnIP.y - 60*scale, w, "center")

    local labelIP = enteringIP and "Press ENTER to save" or "Change Server IP"
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnIP.x + 5*scale, btnIP.y + 6*scale, btnIP.w, btnIP.h, 16*scale, 16*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnIP.x, btnIP.y, btnIP.w, btnIP.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnIP.x, btnIP.y, btnIP.w, btnIP.h, 16*scale, 16*scale)
    drawSpacedText(labelIP, btnIP.x, btnIP.y + 18*scale, btnIP.w, "center", fontBtn, nil, 1)

    if enteringIP then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf("New IP: " .. sanitize(tempIP) .. "|", 0, btnIP.y + 80*scale, w, "center")
    end

    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4*scale, btnBack.y + 5*scale, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    drawSpacedText("BACK", btnBack.x, btnBack.y + 14*scale, btnBack.w, "center", fontBtn, nil, 1)
end

function settings.touchpressed(id, x, y)
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        playButtonSound()
        GameState.current = "lobby"
        return
    end

    if x >= btnNick.x and x <= btnNick.x + btnNick.w and y >= btnNick.y and y <= btnNick.y + btnNick.h then
        playButtonSound()
        if not enteringNick then
            enteringNick = true
            tempNick = SAVE_DATA.nickname or ""
            love.keyboard.setTextInput(true)
        end
        return
    end

    if x >= btnIP.x and x <= btnIP.x + btnIP.w and y >= btnIP.y and y <= btnIP.y + btnIP.h then
        playButtonSound()
        if not enteringIP then
            enteringIP = true
            tempIP = SAVE_DATA.serverIP or "127.0.0.1"
            love.keyboard.setTextInput(true)
        end
        return
    end
end

function settings.textinput(t)
    t = sanitize(t)
    if enteringNick then
        tempNick = tempNick .. t
        if #tempNick > 20 then tempNick = tempNick:sub(1, 20) end
    elseif enteringIP then
        t = t:gsub("[^%d%.]", "")
        tempIP = tempIP .. t
        if #tempIP > 15 then tempIP = tempIP:sub(1, 15) end
    end
end

function settings.keypressed(key)
    if enteringNick then
        if key == "return" or key == "kpenter" then
            if #tempNick > 0 then
                SAVE_DATA.nickname = sanitize(tempNick)
                SAVE_SAVE()
            end
            enteringNick = false
            love.keyboard.setTextInput(false)
            playButtonSound()
        elseif key == "backspace" then
            tempNick = tempNick:sub(1, -2)
        elseif key == "escape" then
            enteringNick = false
            love.keyboard.setTextInput(false)
            playButtonSound()
        end
        return
    end

    if enteringIP then
        if key == "return" or key == "kpenter" then
            if #tempIP > 0 then
                SAVE_DATA.serverIP = tempIP
                SAVE_SAVE()
            end
            enteringIP = false
            love.keyboard.setTextInput(false)
            playButtonSound()
        elseif key == "backspace" then
            tempIP = tempIP:sub(1, -2)
        elseif key == "escape" then
            enteringIP = false
            love.keyboard.setTextInput(false)
            playButtonSound()
        end
        return
    end

    if key == "escape" then
        GameState.current = "lobby"
        playButtonSound()
    end
end

function settings.touchmoved() end
function settings.touchreleased() end

return settings
