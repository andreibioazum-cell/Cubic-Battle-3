-- firebase.lua – использует socket.http и ssl.https
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")

local firebase = {}

firebase.config = {
    apiKey = "AIzaSyA0wqqk0gXlqUh6ONmhk2lyFKTx7nd4H38",
    databaseURL = "https://airbas-d929c-default-rtdb.firebaseio.com",
}

firebase.localId = nil
firebase.idToken = nil

-- Анонимная аутентификация
function firebase.signInAnonymously(callback)
    local url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" .. firebase.config.apiKey
    local body = '{"returnSecureToken": true}'
    local response_body = {}
    local res, code, headers, status = http.request{
        url = url,
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response_body)
    }
    if code == 200 then
        local data = json.decode(table.concat(response_body))
        firebase.localId = data.localId
        firebase.idToken = data.idToken
        if callback then callback(true) end
    else
        print("Firebase auth error: " .. tostring(code))
        if callback then callback(false) end
    end
end

-- Загрузка данных пользователя
function firebase.loadUserData(callback)
    if not firebase.localId or not firebase.idToken then
        if callback then callback(false) end
        return
    end
    local url = firebase.config.databaseURL .. "/users/" .. firebase.localId .. ".json?auth=" .. firebase.idToken
    local response_body = {}
    local res, code = http.request{
        url = url,
        method = "GET",
        sink = ltn12.sink.table(response_body)
    }
    if code == 200 then
        local data = json.decode(table.concat(response_body))
        if data and data ~= "" then
            if callback then callback(true, data) end
        else
            if callback then callback(true, {}) end
        end
    else
        if callback then callback(false) end
    end
end

-- Сохранение данных пользователя
function firebase.saveUserData(data, callback)
    if not firebase.localId or not firebase.idToken then
        if callback then callback(false) end
        return
    end
    local url = firebase.config.databaseURL .. "/users/" .. firebase.localId .. ".json?auth=" .. firebase.idToken
    local jsonData = json.encode(data)
    local response_body = {}
    local res, code = http.request{
        url = url,
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        source = ltn12.source.string(jsonData),
        sink = ltn12.sink.table(response_body)
    }
    if code == 200 then
        if callback then callback(true) end
    else
        if callback then callback(false) end
    end
end

-- Отправка очка в лидерборд
function firebase.submitScore(playerName, score, callback)
    if not firebase.idToken then
        if callback then callback(false) end
        return
    end
    local url = firebase.config.databaseURL .. "/scores.json?auth=" .. firebase.idToken
    local data = json.encode({ name = playerName, score = score, timestamp = os.time() })
    local response_body = {}
    local res, code = http.request{
        url = url,
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        source = ltn12.source.string(data),
        sink = ltn12.sink.table(response_body)
    }
    if code == 200 then
        if callback then callback(true) end
    else
        if callback then callback(false) end
    end
end

-- Получение топ-10 лидерборда
function firebase.getLeaderboard(callback)
    local url = firebase.config.databaseURL .. "/scores.json?orderBy=\"score\"&limitToLast=10"
    local response_body = {}
    local res, code = http.request{
        url = url,
        method = "GET",
        sink = ltn12.sink.table(response_body)
    }
    if code == 200 then
        local data = json.decode(table.concat(response_body))
        if data then
            local scores = {}
            for key, val in pairs(data) do
                table.insert(scores, { name = val.name, score = val.score })
            end
            table.sort(scores, function(a,b) return a.score > b.score end)
            if callback then callback(true, scores) end
        else
            if callback then callback(true, {}) end
        end
    else
        if callback then callback(false) end
    end
end

return firebase
