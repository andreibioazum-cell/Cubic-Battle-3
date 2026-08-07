-- chat.lua - Чат для ПК и телефона (Firebase Realtime Database)
local chat = {}

-- ФИКС #1 (главная причина, почему в Firebase не было папки chat):
-- online здесь использовался как глобальная переменная, но в main.lua и game.lua
-- он объявлен через `local online = require("online")` — глобала не существует.
-- В итоге проверка `if online and online.isConnected()` всегда была ложной
-- и сообщения НИКОГДА не уходили в Firebase. Подключаем модуль напрямую:
local online = require("online")

local messages = {}
local MAX_MESSAGES = 20
local inputText = ""
local isInputActive = false
local isChatOpen = false
local font = nil
local chatWidth = 180
local chatHeight = 160
local scrollOffset = 0
local fetchTimer = 0

-- Сколько секунд сообщение хранится в Firebase (чтобы узел chat не рос бесконечно)
local MSG_TTL = 120

-- id сообщений, которые уже попали в локальный список (защита от дублей)
local knownIds = {}
local knownIdsCount = 0

local adminNicknames = {
    ["DimaSaraev"] = true,
    ["DimaGustenov"] = true,
    ["qwertyuiopaj1234"] = true,
}

local colors = {
    system = {0.4, 0.8, 1, 1},
    player = {1, 1, 1, 1},
    admin = {1, 0.8, 0, 1},
}

local isOnline = false
local isGameState = false
local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

-- Логи: в консоль (logcat на Android) + game.addDebugMessage, если он когда-нибудь появится
local function dbg(text)
    print("[CHAT] " .. tostring(text))
    local g = rawget(_G, "game")
    if g and g.addDebugMessage then
        pcall(g.addDebugMessage, tostring(text))
    end
end

local function markKnown(id)
    if knownIdsCount > 400 then
        knownIds = {}
        knownIdsCount = 0
    end
    if id and not knownIds[id] then
        knownIds[id] = true
        knownIdsCount = knownIdsCount + 1
    end
end

-- Уникальный id сообщения: только цифры и "_" (валидный ключ Firebase),
-- лексикографическая сортировка ключей = хронологический порядок.
local function makeMessageId()
    local ms = math.floor((love.timer.getTime() * 1000) % 100000)
    return tostring(os.time()) .. "_" .. ms .. "_" .. math.random(1000, 9999)
end

-- Экранирование строк для JSON (кавычка/бэкслеш в тексте раньше ломали тело
-- запроса -> Firebase отвечал 400 Bad Request и сообщение терялось)
local function jsonEscape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n"):gsub("\r", "\\r")
    return s
end

local function jsonUnescape(s)
    if not s then return "" end
    s = tostring(s)
    s = s:gsub("\\\\", "\001")
    s = s:gsub('\\"', '"'):gsub("\\n", "\n"):gsub("\\r", "\r")
    s = s:gsub("\001", "\\")
    return s
end

-- %f в некоторых локалях даёт десятичную запятую ("1,23") — это невалидный JSON
local function jsonNumber(x)
    local s = string.format("%.3f", tonumber(x) or 0)
    return (s:gsub(",", "."))
end

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

-- Санитайзер UTF-8 (защита от битых символов)
local function sanitize_utf8(str)
    if not str then return "" end
    local result = {}
    local i = 1
    while i <= #str do
        local byte = str:byte(i)
        if byte < 0x80 then
            if byte >= 0x20 and byte < 0x7F then
                table.insert(result, string.char(byte))
            elseif byte == 0x0A or byte == 0x0D then
                table.insert(result, string.char(byte))
            end
            i = i + 1
        elseif byte >= 0xC2 and byte <= 0xDF then
            if i+1 <= #str and str:byte(i+1) >= 0x80 and str:byte(i+1) <= 0xBF then
                table.insert(result, str:sub(i, i+1))
            end
            i = i + 2
        elseif byte >= 0xE0 and byte <= 0xEF then
            if i+2 <= #str and str:byte(i+1) >= 0x80 and str:byte(i+1) <= 0xBF and str:byte(i+2) >= 0x80 and str:byte(i+2) <= 0xBF then
                table.insert(result, str:sub(i, i+2))
            end
            i = i + 3
        elseif byte >= 0xF0 and byte <= 0xF4 then
            if i+3 <= #str and str:byte(i+1) >= 0x80 and str:byte(i+1) <= 0xBF and str:byte(i+2) >= 0x80 and str:byte(i+2) <= 0xBF and str:byte(i+3) >= 0x80 and str:byte(i+3) <= 0xBF then
                table.insert(result, str:sub(i, i+3))
            end
            i = i + 4
        else
            i = i + 1
        end
    end
    return table.concat(result)
end

-- Удаляет ПОСЛЕДНИЙ СИМВОЛ строки (не байт).
-- Любовь к `s:sub(1, -2)` в коде приводила к обрезке многобайтового символа
-- посередине (например, русской "я" = 2 байта), и дальше font:getWidth/print
-- падали с "UTF-8 decoding error: Invalid UTF-8".
local function utf8_chop(s)
    if not s or #s == 0 then return s or "" end
    local last = s:byte(#s)
    if last < 0x80 then
        return s:sub(1, -2)
    end
    -- последний байт — это продолжение многобайтового символа: ищем его начало
    local i = #s
    while i > 1 and s:byte(i) >= 0x80 and s:byte(i) <= 0xBF do
        i = i - 1
    end
    return s:sub(1, i - 1)
end

-- Обрезает строку до maxBytes байт, не разрывая многобайтовый символ.
-- Заменяет опасное `s:sub(1, N)` (оно могло оставить "хвост" символа -> Invalid UTF-8).
local function utf8_truncate(s, maxBytes)
    s = tostring(s or "")
    if #s <= maxBytes then return s end
    local b = s:byte(maxBytes)
    if not b or b < 0x80 then
        -- граница обрезки попала на ASCII-байт — можно резать смело
        return s:sub(1, maxBytes)
    end
    if b >= 0xC2 and b <= 0xF4 then
        -- на позиции maxBytes начинается многобайтовый символ — он не помещается
        return s:sub(1, maxBytes - 1)
    end
    -- мы внутри многобайтового символа: ищем его ведущий байт
    local i = maxBytes
    while i > 1 and s:byte(i) >= 0x80 and s:byte(i) <= 0xBF do
        i = i - 1
    end
    local lead = s:byte(i)
    local charLen = 2
    if lead >= 0xE0 and lead <= 0xEF then
        charLen = 3
    elseif lead >= 0xF0 and lead <= 0xF4 then
        charLen = 4
    end
    if i + charLen - 1 <= maxBytes then
        -- символ закончился ровно на границе обрезки — он поместился целиком
        return s:sub(1, maxBytes)
    end
    return s:sub(1, i - 1)
end

function chat.load()
    local scale = getScale()
    local fontSize = math.max(12, 14 * scale)
    -- Используем шрифт Fredoka (как в игре)
    font = love.graphics.newFont("Fredoka-Bold.ttf", fontSize)
    messages = {}
    knownIds = {}
    knownIdsCount = 0
    inputText = ""
    isInputActive = false
    isChatOpen = false
    chat.forceClose()
    dbg("💬 Chat loaded")
end

function chat.setOnlineMode(onlineMode)
    isOnline = onlineMode
    if not isOnline then
        chat.forceClose()
        isChatOpen = false
        dbg("💬 Chat offline")
    else
        dbg("💬 Chat online")
    end
end

function chat.setGameState(state)
    isGameState = (state == "game_online")
    if not isGameState then
        chat.forceClose()
        isChatOpen = false
    end
end

function chat.resize()
    chat.load()
end

function chat.addMessage(text, sender, color)
    if not text or text == "" then return end

    local safeText = sanitize_utf8(text)
    safeText = utf8_truncate(safeText, 100)

    local safeSender = sanitize_utf8(sender or "System")
    safeSender = utf8_truncate(safeSender, 20)

    local timestamp = os.date("%H:%M")
    table.insert(messages, {
        text = safeText,
        sender = safeSender,
        color = color or colors.player,
        time = timestamp,
        id = os.time() .. "_" .. math.random(1000, 9999)
    })

    if #messages > MAX_MESSAGES then table.remove(messages, 1) end
    scrollOffset = 0
end

function chat.addSystemMessage(text)
    chat.addMessage(text, "System", colors.system)
end

function chat.addAdminMessage(text)
    chat.addMessage(text, "Admin", colors.admin)
end

function chat.toggleChat()
    if not isOnline or not isGameState then return end
    isChatOpen = not isChatOpen
    if not isChatOpen then
        chat.forceClose()
    end
end

function chat.toggleInput()
    if not isOnline or not isGameState then return end
    if not isChatOpen then return end

    isInputActive = not isInputActive
    if isInputActive then
        love.keyboard.setTextInput(true)
        love.keyboard.setKeyRepeat(true)
    else
        love.keyboard.setTextInput(false)
        love.keyboard.setKeyRepeat(false)
        if inputText ~= "" then
            chat.sendMessage(inputText)
            inputText = ""
        end
    end
end

function chat.forceClose()
    if isInputActive then
        isInputActive = false
        love.keyboard.setTextInput(false)
        love.keyboard.setKeyRepeat(false)
        inputText = ""
    end
end

function chat.sendMessage(text)
    if text == "" then return end
    if not isOnline or not isGameState then return end

    local filtered = sanitize_utf8(text)
    -- Фильтр мата
    local badWords = {"хуй", "пизда", "бля", "еба", "сука", "гондон", "пидор", "мудак", "залупа"}
    for _, word in ipairs(badWords) do
        filtered = filtered:gsub(word, "***")
    end

    -- ФИКС: раньше условие `if sender == SAVE_DATA.nickname` было всегда истинным,
    -- и ВСЕ игроки без исключения отправляли сообщения как "Anonymous"
    local sender = sanitize_utf8((SAVE_DATA and SAVE_DATA.nickname) or "Player")
    sender = utf8_truncate(sender, 20)
    if sender == "" then sender = "Player" end
    if adminNicknames[sender] then
        sender = "Admin"
    end

    local color = colors.player
    if sender == "Admin" then color = colors.admin end

    -- Локально показываем сразу
    chat.addMessage(filtered, sender, color)

    if not online or not online.isConnected() then
        dbg("❌ Не отправлено: нет подключения к Firebase")
        chat.addSystemMessage("Нет соединения с чат-сервером")
        return
    end

    local msgId = makeMessageId()
    markKnown(msgId) -- не дублировать собственное сообщение при следующем fetch

    local data = string.format('{"text":"%s","sender":"%s","time":%s}',
        jsonEscape(filtered), jsonEscape(sender), jsonNumber(os.time()))

    dbg("📤 Отправка в chat/" .. msgId .. " body=" .. tostring(data))
    chat.addSystemMessage("Отправка...")
    online.sendRequest("PUT", "chat/" .. msgId, data, function(ok, response)
        if ok then
            dbg("✅ Записано в Firebase: chat/" .. msgId .. " resp=" .. tostring(response))
            chat.addSystemMessage("✅ Отправлено")
        else
            dbg("❌ Firebase отклонил запись: " .. tostring(response))
            chat.addSystemMessage("❌ Ошибка: " .. tostring(response))
        end
    end)
end

function chat.fetchMessages()
    if not online or not online.isConnected() then return end
    if not isOnline or not isGameState then return end

    -- ФИКС: путь "chat", а не "chat.json" — суффикс ".json" сам подставляется
    -- в online.sendRequest, поэтому старый запрос уходил на "chat.json.json"
    -- и всегда возвращал null (чужие сообщения не отображались).
    online.sendRequest("GET", "chat", nil, function(ok, res)
        if not ok then
            dbg("❌ Ошибка чтения чата: " .. tostring(res))
            return
        end
        if not res or res == "null" or res == "" then return end

        local now = os.time()
        for id, data in res:gmatch('"([^"]+)":%s*({[^{}]+})') do
            local ts = tonumber(id:match("^(%d+)")) or now
            if now - ts > MSG_TTL then
                -- Чистим старые сообщения, чтобы узел chat не разрастался бесконечно
                online.sendRequest("DELETE", "chat/" .. id, nil, function() end)
            elseif not knownIds[id] then
                markKnown(id)
                local text = sanitize_utf8(jsonUnescape(data:match('"text":%s*"([^"]*)"')))
                local sender = sanitize_utf8(jsonUnescape(data:match('"sender":%s*"([^"]*)"')))
                text = utf8_truncate(text, 100)
                sender = utf8_truncate(sender, 20)
                if text ~= "" and sender ~= "" then
                    -- Доп. защита от дубля (например, своё сообщение после перезахода)
                    local dup = false
                    for _, m in ipairs(messages) do
                        if m.text == text and m.sender == sender then
                            dup = true
                            break
                        end
                    end
                    if not dup then
                        local color = colors.player
                        if sender == "Admin" then color = colors.admin end
                        if sender == "System" then color = colors.system end
                        table.insert(messages, {
                            text = text,
                            sender = sender,
                            color = color,
                            time = os.date("%H:%M", ts),
                            id = id
                        })
                        if #messages > MAX_MESSAGES then table.remove(messages, 1) end
                        scrollOffset = 0
                    end
                end
            end
        end
    end)
end

function chat.update(dt)
    if not isOnline or not isGameState then return end
    if online and online.isConnected() then
        fetchTimer = fetchTimer + dt
        if fetchTimer >= 2.0 then
            fetchTimer = 0
            chat.fetchMessages()
        end
    end
end

function chat.draw()
    if not isOnline or not isGameState then return end

    local w, h = love.graphics.getDimensions()
    local scale = getScale()
    if not font then chat.load() end

    -- Кнопка чата (правый верхний угол)
    local btnSize = 34 * scale
    local btnX = w - btnSize - 10
    local btnY = 10

    love.graphics.setColor(0.2, 0.4, 0.8, 0.8)
    love.graphics.rectangle("fill", btnX, btnY, btnSize, btnSize, 6 * scale, 6 * scale)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.setLineWidth(2 * scale)
    love.graphics.rectangle("line", btnX, btnY, btnSize, btnSize, 6 * scale, 6 * scale)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    local icon = isChatOpen and "X" or "C"
    local iconW = font:getWidth(icon)
    local iconH = font:getHeight()
    love.graphics.print(icon, btnX + (btnSize - iconW)/2, btnY + (btnSize - iconH)/2)

    chat._btnX = btnX
    chat._btnY = btnY
    chat._btnSize = btnSize

    if not isChatOpen then return end

    local chatX = w - chatWidth * scale - 10
    local chatY = btnY + btnSize + 5

    -- Фон окна чата
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", chatX, chatY, chatWidth * scale, chatHeight * scale, 6 * scale, 6 * scale)
    love.graphics.setColor(0.2, 0.4, 0.8, 0.3)
    love.graphics.setLineWidth(1.5 * scale)
    love.graphics.rectangle("line", chatX, chatY, chatWidth * scale, chatHeight * scale, 6 * scale, 6 * scale)

    love.graphics.setFont(font)
    local y = chatY + 5 + scrollOffset
    local maxMessages = math.floor((chatHeight * scale - 10) / 16)
    local startIdx = math.max(1, #messages - maxMessages + 1)

    for i = startIdx, #messages do
        local msg = messages[i]
        local alpha = (i == startIdx) and 0.5 or 1

        -- Время
        love.graphics.setColor(0.6, 0.6, 0.6, alpha * 0.6)
        local timeText = msg.time .. " "
        love.graphics.print(timeText, chatX + 4, y)
        local timeW = font:getWidth(timeText)

        -- Ник
        love.graphics.setColor(msg.color[1], msg.color[2], msg.color[3], alpha)
        local senderText = msg.sender .. ": "
        love.graphics.print(senderText, chatX + 4 + timeW, y)
        local senderW = font:getWidth(senderText)

        -- Текст
        love.graphics.setColor(1, 1, 1, alpha)
        local text = msg.text or ""
        local maxTextWidth = chatWidth * scale - 20 - timeW - senderW
        if font:getWidth(text) > maxTextWidth then
            -- ФИКС: укорачиваем по ЦЕЛЫМ символам, а не по байтам.
            -- Раньше text:sub(1, -2) резал многобайтовый символ пополам,
            -- и следующий font:getWidth падал с "UTF-8 decoding error".
            while #text > 1 and font:getWidth(text .. "...") > maxTextWidth do
                text = utf8_chop(text)
            end
            text = text .. "..."
        end
        pcall(love.graphics.print, text, chatX + 4 + timeW + senderW, y)
        y = y + 16
    end

    -- Кнопка Send (справа при активном вводе, особенно нужна на мобилках где нет Enter)
    local sendBtnW = 50 * scale
    local sendBtnH = 20
    local sendBtnX = chatX + chatWidth * scale - sendBtnW - 4
    local sendBtnY = chatY + chatHeight * scale - 24
    chat._sendBtn = nil

    if isInputActive then
        local inputY = sendBtnY
        local inputW = chatWidth * scale - 4 - sendBtnW - 4
        love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
        love.graphics.rectangle("fill", chatX + 2, inputY, inputW, 20, 4 * scale, 4 * scale)
        love.graphics.setColor(0.3, 0.5, 0.9, 0.5)
        love.graphics.setLineWidth(1 * scale)
        love.graphics.rectangle("line", chatX + 2, inputY, inputW, 20, 4 * scale, 4 * scale)

        love.graphics.setColor(1, 1, 1, 1)
        local displayText = sanitize_utf8(inputText)
        if love.timer.getTime() % 1 < 0.5 then
            displayText = displayText .. "_"
        end
        love.graphics.print(utf8_truncate(displayText, 50), chatX + 6, inputY + 3)

        -- Кнопка SEND
        local canSend = inputText ~= ""
        love.graphics.setColor(canSend and {0.2, 0.7, 0.3, 0.9} or {0.3, 0.3, 0.3, 0.7})
        love.graphics.rectangle("fill", sendBtnX, sendBtnY, sendBtnW, sendBtnH, 4 * scale, 4 * scale)
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.setLineWidth(1 * scale)
        love.graphics.rectangle("line", sendBtnX, sendBtnY, sendBtnW, sendBtnH, 4 * scale, 4 * scale)
        love.graphics.setColor(1, 1, 1, 1)
        local sendLabel = "SEND"
        local sw = font:getWidth(sendLabel)
        love.graphics.print(sendLabel, sendBtnX + (sendBtnW - sw) / 2, sendBtnY + 3)

        chat._sendBtn = { x = sendBtnX, y = sendBtnY, w = sendBtnW, h = sendBtnH }
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.print(isMobile and "Tap to chat" or "Press T to chat", chatX + 4, chatY + chatHeight * scale - 18)
    end
end

function chat.keypressed(key)
    if not isOnline or not isGameState then return false end

    if key == "t" or key == "т" then
        if not isChatOpen then
            isChatOpen = true
        else
            chat.toggleInput()
        end
        return true
    end

    if isInputActive then
        if key == "return" or key == "kpenter" then
            chat.toggleInput()
            return true
        elseif key == "escape" then
            chat.forceClose()
            return true
        elseif key == "backspace" then
            inputText = utf8_chop(inputText)
        end
    end

    return false
end

function chat.textinput(t)
    if not isOnline or not isGameState then return end
    if isInputActive then
        local filtered = sanitize_utf8(t)
        if #inputText + #filtered <= 100 then
            inputText = inputText .. filtered
        end
    end
end

function chat.touchpressed(x, y)
    if not isOnline or not isGameState then return false end

    -- Кнопка чата (С/X в углу)
    if chat._btnX and chat._btnY then
        local s = chat._btnSize
        if x >= chat._btnX and x <= chat._btnX + s and
           y >= chat._btnY and y <= chat._btnY + s then
            chat.toggleChat()
            return true
        end
    end

    -- Кнопка SEND при активном вводе
    if isInputActive and chat._sendBtn then
        local b = chat._sendBtn
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            if inputText ~= "" then
                chat.sendMessage(inputText)
                inputText = ""
            end
            -- Не закрываем ввод, чтобы можно было написать ещё
            return true
        end
    end

    -- Клик по окну чата = открыть клавиатуру (если ввод ещё не активен)
    if isChatOpen then
        local w, h = love.graphics.getDimensions()
        local scale = getScale()
        local chatX = w - chatWidth * scale - 10
        local chatY = 10 + 34 * scale + 5
        if x >= chatX and x <= chatX + chatWidth * scale and
           y >= chatY and y <= chatY + chatHeight * scale then
            if not isInputActive then
                chat.toggleInput()
            end
            return true
        end
    end

    return false
end

function chat.mousepressed(x, y, button)
    if not isOnline or not isGameState then return false end
    if isMobile then return false end

    if button == 1 then
        -- Кнопка чата
        if chat._btnX and chat._btnY then
            local s = chat._btnSize
            if x >= chat._btnX and x <= chat._btnX + s and
               y >= chat._btnY and y <= chat._btnY + s then
                chat.toggleChat()
                return true
            end
        end
        -- Кнопка SEND (для ПК тоже)
        if isInputActive and chat._sendBtn then
            local b = chat._sendBtn
            if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
                if inputText ~= "" then
                    chat.sendMessage(inputText)
                    inputText = ""
                end
                return true
            end
        end
    end

    return false
end

return chat
