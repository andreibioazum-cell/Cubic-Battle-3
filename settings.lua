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

-- Функция для проверки, является ли строка валидным UTF-8
local function isValidUTF8(str)
    -- Простая проверка: попытка сконвертировать в UTF-8 и обратно
    -- В Lua 5.3+ можно использовать utf8.len, но в LÖVE 11.5 используется Lua 5.3, так что есть utf8
    local ok, _ = pcall(utf8.len, str)
    return ok
end

-- Функция для очистки ника (оставляем только буквы, цифры, пробел, подчёркивание, дефис)
local function sanitizeNick(str)
    if not str then return "Player" end
    -- Заменяем все недопустимые символы на пустую строку
    local cleaned = str:gsub("[^%w%s_%-]", "")
    if cleaned == "" then cleaned = "Player" end
    return cleaned
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

    -- Проверяем ник на валидность UTF-8 и очищаем
    local nick = SAVE_DATA.nickname or "Player"
    if not isValidUTF8(nick) then
        nick = "Player"
        SAVE_DATA.nickname = nick
        SAVE_SAVE()
    end
    -- Очищаем от недопустимых символов
    nick = sanitizeNick(nick)
    SAVE_DATA.nickname = nick
    tempNick = nick

    -- IP обычно только цифры и точки, но на всякий случай тоже проверим
    local ip = SAVE_DATA.serverIP or "127.0.0.1"
    if not isValidUTF8(ip) then
        ip = "127.0.0.1"
        SAVE_DATA.serverIP = ip
        SAVE_SAVE()
    end
    tempIP = ip
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

    -- Ник (с очисткой перед отображением)
    local currentNick = SAVE_DATA.nickname or "Player"
    currentNick = sanitizeNick(currentNick)  -- дополнительная защита
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fontBtn)
    -- Используем love.graphics.print с координатами вместо printf, чтобы избежать проблем с UTF-8
    -- Но printf тоже должен работать, если строка валидна
    love.graphics.printf("Nickname: " .. currentNick, 0, btnNick.y - 60*scale, w, "center")

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
        love.graphics.printf("New nick: " .. sanitizeNick(tempNick) .. "|", 0, btnNick.y + 80*scale, w, "center")
    end

    -- IP сервера
    local currentIP = SAVE_DATA.serverIP or "127.0.0.1"
    if not isValidUTF8(currentIP) then currentIP = "127.0.0.1" end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Server IP: " .. currentIP, 0, btnIP.y - 60*scale, w, "center")

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
        love.graphics.printf("New IP: " .. tempIP .. "|", 0, btnIP.y + 80*scale, w, "center")
    end

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
    if enteringNick then
        -- Разрешаем только буквы, цифры, пробел, подчёркивание, дефис
        local filtered = t:gsub("[^%w%s_%-]", "")
        tempNick = tempNick .. filtered
        if #tempNick > 20 then tempNick = tempNick:sub(1, 20) end
    elseif enteringIP then
        -- Для IP разрешаем цифры, точки, двоеточие (для IPv6)
        local filtered = t:gsub("[^%d%.%:]", "")
        tempIP = tempIP .. filtered
        if #tempIP > 15 then tempIP = tempIP:sub(1, 15) end
    end
end

function settings.keypressed(key)
    if enteringNick then
        if key == "return" or key == "kpenter" then
            if #tempNick > 0 then
                local cleaned = sanitizeNick(tempNick)
                SAVE_DATA.nickname = cleaned
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
