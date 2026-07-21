-- chat.lua - Чат только в онлайне
local chat = {}

local messages = {}
local MAX_MESSAGES = 50
local inputText = ""
local isInputActive = false
local font = nil
local chatHeight = 150
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
    local fontSize = math.max(16, 20 * scale)
    font = love.graphics.newFont("Roboto-Regular.ttf", fontSize)
    messages = {}
    inputText = ""
    isInputActive = false
    isOnline = false
    isGameState = false
    chat.forceClose()
end

function chat.setOnlineMode(online)
    isOnline = online
    if not isOnline then
        chat.forceClose()
    end
end

function chat.setGameState(state)
    isGameState = (state == "game_online")
    if not isGameState then
        chat.forceClose()
    end
end

function chat.resize()
    chat.load()
end

function chat.addMessage(text, sender, color)
    local timestamp = os.date("%H:%M")
    table.insert(messages, {
        text = text,
        sender = sender or "System",
        color = color or colors.player,
        time = timestamp,
    })
    if #messages > MAX_MESSAGES then
        table.remove(messages, 1)
    end
    scrollOffset = 0
end

function chat.addSystemMessage(text)
    chat.addMessage(text, "System", colors.system)
end

function chat.addAdminMessage(text)
    chat.addMessage(text, "Admin", colors.admin)
end

function chat.toggleInput()
    if not isOnline or not isGameState then
        chat.forceClose()
        return
    end
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
    
    if online and online.isConnected() then
        local data = string.format('{"text":"%s","sender":"%s","time":%f}', 
            filtered, sender, love.timer.getTime())
        online.sendRequest("PUT", "chat/" .. os.time() .. "_" .. math.random(1000, 9999), data, function() end)
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
        if ok and res and res ~= "null" then
            for id, data in res:gmatch('"([^"]+)":%s*({[^{}]+})') do
                local text = data:match('"text":%s*"([^"]+)"')
                local sender = data:match('"sender":%s*"([^"]+)"')
                if text and sender then
                    local exists = false
                    for _, msg in ipairs(messages) do
                        if msg.text == text and msg.sender == sender then
                            exists = true
                            break
                        end
                    end
                    if not exists then
                        local color = colors.player
                        if sender == "Admin" then color = colors.admin end
                        if sender == "System" then color = colors.system end
                        chat.addMessage(text, sender, color)
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
        if fetchTimer >= 3 then
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
    
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 10, h - chatHeight - 50, w - 20, chatHeight, 8, 8)
    love.graphics.setColor(0.2, 0.4, 0.8, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 10, h - chatHeight - 50, w - 20, chatHeight, 8, 8)
    
    love.graphics.setFont(font)
    local y = h - chatHeight - 40 + scrollOffset
    local maxMessages = math.floor(chatHeight / 22) - 1
    local startIdx = math.max(1, #messages - maxMessages + 1)
    
    for i = startIdx, #messages do
        local msg = messages[i]
        local alpha = (i == startIdx) and 0.5 or 1
        
        love.graphics.setColor(0.6, 0.6, 0.6, alpha * 0.7)
        love.graphics.print(msg.time .. " ", 20, y)
        local timeW = font:getWidth(msg.time .. " ")
        
        love.graphics.setColor(msg.color[1], msg.color[2], msg.color[3], alpha)
        local senderText = msg.sender .. ": "
        love.graphics.print(senderText, 20 + timeW, y)
        local senderW = font:getWidth(senderText)
        
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(msg.text, 20 + timeW + senderW, y)
        y = y + 22
    end
    
    if isInputActive then
        local inputY = h - 20
        local inputW = w - 40
        love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
        love.graphics.rectangle("fill", 20, inputY - 22, inputW, 28, 6, 6)
        love.graphics.setColor(0.3, 0.5, 0.9, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", 20, inputY - 22, inputW, 28, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
        local displayText = inputText .. ((love.timer.getTime() % 1 < 0.5) and "_" or "")
        love.graphics.print(displayText, 28, inputY - 18)
        love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
        love.graphics.print("Press Enter to send | ESC to close", 28, h - 60)
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.setFont(font)
        love.graphics.print("Press 'T' to chat", 20, h - 20)
    end
end

function chat.keypressed(key)
    if not isOnline or not isGameState then return false end
    
    if key == "t" or key == "т" then
        chat.toggleInput()
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
    local w, h = love.graphics.getDimensions()
    if button == 1 and x >= 10 and x <= w - 10 and y >= h - chatHeight - 50 and y <= h - 50 then
        chat.toggleInput()
        return true
    end
    return false
end

function chat.touchpressed(x, y)
    if not isOnline or not isGameState then return false end
    local w, h = love.graphics.getDimensions()
    if x >= 10 and x <= w - 10 and y >= h - chatHeight - 50 and y <= h - 50 then
        chat.toggleInput()
        return true
    end
    return false
end

return chat
