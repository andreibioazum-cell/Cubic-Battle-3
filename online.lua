local firebase = require("firebase")
local online = {}

local myUid = nil
local players = {}
local isConnected = false
local debugText = ""

local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)
end

function online.init()
    firebase.init({
        apiKey = "AIzaSyCe25SaGWfaQsPyje10wi_Wsmr5yHz3HE4",
        dbURL = "https://cubic-battle-3-default-rtdb.firebaseio.com",
        verifySSL = false,
    })
    setDebug("Firebase initialized")
end

function online.connect(callback)
    if isConnected then
        if callback then callback(true) end
        return
    end

    firebase.authAnonymous(function(success, data)
        if success then
            myUid = data.localId
            isConnected = true
            setDebug("Auth OK, UID: " .. myUid)

            firebase.listen("players", function(ok, data)
                if ok then
                    if data then
                        local newPlayers = {}
                        for uid, pos in pairs(data) do
                            if uid ~= myUid and pos.x and pos.y then
                                newPlayers[uid] = { x = pos.x, y = pos.y }
                            end
                        end
                        players = newPlayers
                        setDebug("Players updated: " .. #players)
                    end
                else
                    setDebug("Listener error: " .. tostring(data))
                end
            end)

            if callback then callback(true) end
        else
            setDebug("Auth failed: " .. tostring(data))
            if callback then callback(false) end
        end
    end)
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then return end
    firebase.put("players/" .. myUid, { x = math.floor(x), y = math.floor(y) })
end

function online.getPlayers()
    return players
end

function online.leave()
    if not isConnected or not myUid then return end
    firebase.unlisten("players")
    firebase.delete("players/" .. myUid)
    isConnected = false
    players = {}
end

function online.update(dt)
    if not isConnected then
        online.connect()
        return
    end
    firebase.update()
    if online.onSendPosition then
        local x, y = online.onSendPosition()
        if x and y then
            online.sendPosition(x, y)
        end
    end
end

function online.getDebugText()
    return debugText
end

return online
