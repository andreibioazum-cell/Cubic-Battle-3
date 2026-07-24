-- chat.lua - Чат для ПК и телефона с отладкой через game.addDebugMessage
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

function chat.load()
    local scale = getScale()
    local fontSize = math.max(12, 14 * scale)
    -- Используем шрифт Fredoka (как в игре)
    font = love.graphics.newFont("Fredoka-Bold.ttf", fontSize)
    messages = {}
    inputText = ""
    isInputActive = false
    isChatOpen = false
    chat.forceClose()
    if game and game.addDebugMessage then
        game.addDebugMessage("💬 Chat loaded", {0.5, 0.8, 1, 1})
    end
end

function chat.setOnlineMode(online)
    isOnline = online
    if not isOnline then
        chat.forceClose()
        isChatOpen = false
        if game and game.addDebugMessage then
            game.addDebugMessage("💬 Chat offline", {0.8, 0.8, 0.8, 1})
        end
    else
        if game and game.addDebugMessage then
            game.addDebugMessage("💬 Chat online", {0.3, 1, 0.3, 1})
        end
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
    if #safeText > 100 then safeText = safeText:sub(1, 100) end
    
    local safeSender = sanitize_utf8(sender or "System")
    if #safeSender > 20 then safeSender = safeSender:sub(1, 20) end
    
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
    if not isOnline or not isGameState then return
    isChatOpen = not isChatOpen
    if not isChatOpen then chat.forceClose()
end

function chat.toggleInput()
    if not isOnline or not isGameState then return
    if not isChatOpen then return
    
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
    if text == "" then return
    if not isOnline or not isGameState then return
    
    local filtered = sanitize_utf8(text)
    -- Фильтр мата
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
    
    -- Отладка: отправка
    if game and game.addDebugMessage then
        game.addDebugMessage("📤 Sending: " .. filtered, {0.5, 1, 0.5, 1})
    end
    
    -- Отправка в Firebase
    if online and online.isConnected() then
        local chatPath = "chat/" .. os.time() .. "_" .. math.random(1000, 9999)
        local data = string.format('{"text":"%s","sender":"%s","time":%f}', 
            filtered, sender, love.timer.getTime())
        online.sendRequest("PUT", chatPath, data, function(ok, response)
            if ok then
                if game and game.addDebugMessage then
                    game.addDebugMessage("✅ Message sent to Firebase", {0.3, 1, 0.3, 1})
                end
            else
                if game and game.addDebugMessage then
                    game.addDebugMessage("❌ Send failed: " .. tostring(response), {1, 0.3, 0.3, 1})
                end
            end
        end)
    else
        if game and game.addDebugMessage then
            game.addDebugMessage("❌ Not connected to Firebase", {1, 0.3, 0.3, 1})
        end
    end
    
    -- Добавляем локально
    local color = colors.player
    if sender == "Admin" then color = colors.admin end
    if sender == "System" then color = colors.system end
    chat.addMessage(filtered, sender, color)
end

function chat.fetchMessages()
    if not online or not online.isConnected() then return
    if not isOnline or not isGameState then return
    
    if game and game.addDebugMessage then
        game.addDebugMessage("📥 Fetching messages...", {0.5, 0.5, 1, 1})
    end
    
    online.sendRequest("GET", "chat.json", nil, function(ok, res)
        if ok and res and res ~= "null" and res ~= "" then
            if game and game.addDebugMessage then
                game.addDebugMessage("✅ Got messages from Firebase", {0.3, 1, 0.3, 1})
            end
            for id, data in res:gmatch('"([^"]+)":%s*({[^{}]+})') do
                local text = data:match('"text":%s*"([^"]+)"')
                local sender = data:match('"sender":%s*"([^"]+)"')
                if text and sender then
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
                        table.insert(messages, {
                            text = sanitize_utf8(text),
                            sender = sanitize_utf8(sender),
                            color = color,
                            time = os.date("%H:%M"),
                            id = id
                        })
                        if #messages > MAX_MESSAGES then table.remove(messages, 1) end
                    end
                end
            end
        else
            if game and game.addDebugMessage then
                game.addDebugMessage("❌ No messages or error: " .. tostring(res), {1, 0.3, 0.3, 1})
            end
        end
    end)
end

function chat.update(dt)
    if not isOnline or not isGameState then return
    if online and online.isConnected() then
        fetchTimer = fetchTimer + dt
        if fetchTimer >= 2.0 then
            fetchTimer = 0
            chat.fetchMessages()
        end
    end
end

function chat.draw()
    if not isOnline or not isGameState then return
    
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
    
    if not isChatOpen then return
    
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
        if font:getWidth(text) > (chatWidth * scale - 20 - timeW - senderW) then
            while font:getWidth(text .. "...") > (chatWidth * scale - 20 - timeW - senderW) and #text > 1 do
                text = text:sub(1, -2)
            end
            text = text .. "..."
        end
        pcall(love.graphics.print, text, chatX + 4 + timeW + senderW, y)
        y = y + 16
    end
    
    if isInputActive then
        local inputY = chatY + chatHeight * scale - 24
        love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
        love.graphics.rectangle("fill", chatX + 2, inputY, chatWidth * scale - 4, 20, 4 * scale, 4 * scale)
        love.graphics.setColor(0.3, 0.5, 0.9, 0.5)
        love.graphics.setLineWidth(1 * scale)
        love.graphics.rectangle("line", chatX + 2, inputY, chatWidth * scale - 4, 20, 4 * scale, 4 * scale)
        
        love.graphics.setColor(1, 1, 1, 1)
        local displayText = sanitize_utf8(inputText)
        if love.timer.getTime() % 1 < 0.5 then
            displayText = displayText .. "_"
        end
        love.graphics.print(displayText:sub(1, 50), chatX + 6, inputY + 3)
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.print(isMobile and "Tap to chat" or "Press T to chat", chatX + 4, chatY + chatHeight * scale - 18)
    end
end

function chat.keypressed(key)
    if not isOnline or not isGameState then return false
    
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
    if not isOnline or not isGameState then return
    if isInputActive then
        local filtered = sanitize_utf8(t)
        if #inputText + #filtered <= 100 then
            inputText = inputText .. filtered
        end
    end
end

function chat.touchpressed(x, y)
    if not isOnline or not isGameState then return false
    
    -- Кнопка чата
    if chat._btnX and chat._btnY then
        local s = chat._btnSize
        if x >= chat._btnX and x <= chat._btnX + s and
           y >= chat._btnY and y <= chat._btnY + s then
            chat.toggleChat()
            return true
        end
    end
    
    -- Клик по окну чата = открыть клавиатуру
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
    if not isOnline or not isGameState then return false
    if isMobile then return false
    
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

return chat
