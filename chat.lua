-- chat.lua - Маленькое окошко в углу (как в Роблоксе)
local chat = {}

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
local lastMessageTime = 0

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
local chatMessagesCache = {} -- Кэш для сообщений из Firebase

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
        base = 600
    end
    return math.min(w, h) / base
end

function chat.load()
    local scale = getScale()
    local fontSize = math.max(12, 14 * scale)
    font = love.graphics.newFont("Roboto-Regular.ttf", fontSize)
    messages = {}
    inputText = ""
    isInputActive = false
    isChatOpen = false
    chatMessagesCache = {}
    chat.forceClose()
end

function chat.setOnlineMode(online)
    isOnline = online
    if not isOnline then
        chat.forceClose()
        isChatOpen = false
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
    
    -- Безопасная обрезка текста для печати
    local safeText = text
    if #safeText > 100 then
        safeText = safeText:sub(1, 100)
    end
    
    local timestamp = os.date("%H:%M")
    table.insert(messages, {
        text = safeText,
        sender = sender or "System",
        color = color or colors.player,
        time = timestamp,
        id = os.time() .. "_" .. math.random(1000, 9999)
    })
    
    if #messages > MAX_MESSAGES then
        table.remove(messages, 1)
    end
    scrollOffset = 0
    lastMessageTime = love.timer.getTime()
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
    
    -- Фильтр мата
    local filtered = text
    local badWords = {"хуй", "пизда", "бля", "еба", "сука", "гондон", "пидор", "мудак", "залупа"}
    for _, word in ipairs(badWords) do
        filtered = filtered:gsub(word, "***")
    end
    
    local sender = SAVE_DATA.nickname or "Player"
    if adminNicknames[sender] then
        sender = "Admin"
    end
    if sender == SAVE_DATA.nickname then
        sender = "Anonymous"
    end
    
    -- Отправляем в Firebase
    if online and online.isConnected() then
        local chatPath = "chat/" .. os.time() .. "_" .. math.random(1000, 9999)
        local data = string.format('{"text":"%s","sender":"%s","time":%f}', 
            filtered, sender, love.timer.getTime())
        online.sendRequest("PUT", chatPath, data, function(ok, res)
            if ok then
                print("[CHAT] Message sent: " .. filtered)
            else
                print("[CHAT] Failed to send message")
            end
        end)
    end
    
    local color = colors.player
    if sender == "Admin" then color = colors.admin end
    if sender == "System" then color = colors.system end
    chat.addMessage(filtered, sender, color)
end

function chat.fetchMessages()
    if not online or not online.isConnected() then return end
    if not isOnline or not isGameState then return end
    
    online.sendRequest("GET", "chat.json", nil, function(ok, res)
        if ok and res and res ~= "null" and res ~= "" then
            -- Парсим сообщения из Firebase
            for id, data in res:gmatch('"([^"]+)":%s*({[^{}]+})') do
                local text = data:match('"text":%s*"([^"]+)"')
                local sender = data:match('"sender":%s*"([^"]+)"')
                local time = data:match('"time":%s*([%d%.]+)')
                
                if text and sender then
                    -- Проверяем, есть ли уже такое сообщение
                    local exists = false
                    for _, msg in ipairs(messages) do
                        if msg.text == text and msg.sender == sender and msg.id == id then
                            exists = true
                            break
                        end
                    end
                    
                    if not exists then
                        local color = colors.player
                        if sender == "Admin" then color = colors.admin end
                        if sender == "System" then color = colors.system end
                        
                        -- Добавляем сообщение с ID для предотвращения дублей
                        table.insert(messages, {
                            text = text,
                            sender = sender,
                            color = color,
                            time = os.date("%H:%M", tonumber(time) or os.time()),
                            id = id
                        })
                        
                        if #messages > MAX_MESSAGES then
                            table.remove(messages, 1)
                        end
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
        -- Проверяем новые сообщения каждые 2 секунды
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
    
    -- КНОПКА ЧАТА (маленькая в углу)
    local btnSize = 40 * scale
    local btnX = w - btnSize - 10
    local btnY = h - btnSize - 10
    
    love.graphics.setColor(0.2, 0.4, 0.8, 0.8)
    love.graphics.rectangle("fill", btnX, btnY, btnSize, btnSize, 8 * scale, 8 * scale)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.setLineWidth(2 * scale)
    love.graphics.rectangle("line", btnX, btnY, btnSize, btnSize, 8 * scale, 8 * scale)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    local icon = isChatOpen and "X" or "C"
    local iconW = font:getWidth(icon)
    local iconH = font:getHeight()
    love.graphics.print(icon, btnX + (btnSize - iconW)/2, btnY + (btnSize - iconH)/2)
    
    -- Сохраняем координаты кнопки для нажатия
    chat._btnX = btnX
    chat._btnY = btnY
    chat._btnSize = btnSize
    
    -- ОКНО ЧАТА (если открыто)
    if not isChatOpen then return end
    
    local chatX = w - chatWidth * scale - 10
    local chatY = btnY - chatHeight * scale - 5
    
    -- Фон чата
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", chatX, chatY, chatWidth * scale, chatHeight * scale, 6 * scale, 6 * scale)
    love.graphics.setColor(0.2, 0.4, 0.8, 0.3)
    love.graphics.setLineWidth(1.5 * scale)
    love.graphics.rectangle("line", chatX, chatY, chatWidth * scale, chatHeight * scale, 6 * scale, 6 * scale)
    
    -- Сообщения
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
        
        -- Текст (безопасный вывод)
        love.graphics.setColor(1, 1, 1, alpha)
        local text = msg.text or ""
        -- Обрезаем длинный текст
        if font:getWidth(text) > (chatWidth * scale - 20 - timeW - senderW) then
            while font:getWidth(text .. "...") > (chatWidth * scale - 20 - timeW - senderW) and #text > 1 do
                text = text:sub(1, -2)
            end
            text = text .. "..."
        end
        love.graphics.print(text, chatX + 4 + timeW + senderW, y)
        
        y = y + 16
    end
    
    -- Поле ввода (если активно)
    if isInputActive then
        local inputY = chatY + chatHeight * scale - 24
        love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
        love.graphics.rectangle("fill", chatX + 2, inputY, chatWidth * scale - 4, 20, 4 * scale, 4 * scale)
        love.graphics.setColor(0.3, 0.5, 0.9, 0.5)
        love.graphics.setLineWidth(1 * scale)
        love.graphics.rectangle("line", chatX + 2, inputY, chatWidth * scale - 4, 20, 4 * scale, 4 * scale)
        
        love.graphics.setColor(1, 1, 1, 1)
        local displayText = inputText
        if love.timer.getTime() % 1 < 0.5 then
            displayText = displayText .. "_"
        end
        -- Безопасный вывод текста ввода
        love.graphics.print(displayText:sub(1, 50), chatX + 6, inputY + 3)
    else
        -- Подсказка
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.print("Enter to chat", chatX + 4, chatY + chatHeight * scale - 18)
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
            inputText = inputText:sub(1, -2)
        end
    end
    
    return false
end

function chat.textinput(t)
    if not isOnline or not isGameState then return end
    if isInputActive then
        -- Фильтруем только безопасные символы
        local filtered = ""
        for i = 1, #t do
            local byte = t:byte(i)
            if (byte >= 32 and byte <= 126) or byte >= 192 then
                filtered = filtered .. string.char(byte)
            end
        end
        if #inputText + #filtered <= 100 then
            inputText = inputText .. filtered
        end
    end
end

function chat.mousepressed(x, y, button)
    if not isOnline or not isGameState then return false end
    
    if button == 1 and chat._btnX and chat._btnY then
        local s = chat._btnSize
        if x >= chat._btnX and x <= chat._btnX + s and
           y >= chat._btnY and y <= chat._btnY + s then
            chat.toggleChat()
            return true
        end
    end
    
    return false
end

function chat.touchpressed(x, y)
    if not isOnline or not isGameState then return false end
    
    if chat._btnX and chat._btnY then
        local s = chat._btnSize
        if x >= chat._btnX and x <= chat._btnX + s and
           y >= chat._btnY and y <= chat._btnY + s then
            chat.toggleChat()
            return true
        end
    end
    
    return false
end

return chat
