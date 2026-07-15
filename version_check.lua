-- version_check.lua – проверка обновлений
local version_check = {}

local online = require("online")
local VERSION = "1.3"  -- Текущая версия игры
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local CONFIG_PATH = "config/version"

local showUpdatePopup = false
local latestVersion = ""
local updateChecked = false
local isChecking = false

function version_check.check(callback)
    if isChecking then return end
    isChecking = true
    
    local url = DB_URL .. CONFIG_PATH .. ".json"
    
    local function onResponse(ok, data)
        isChecking = false
        if ok and data then
            latestVersion = data:gsub('"', ''):gsub(' ', '')
            updateChecked = true
            
            if latestVersion > VERSION then
                showUpdatePopup = true
                if _G.addDebugMessage then
                    _G.addDebugMessage("New version available: " .. latestVersion, {1, 0.8, 0.2, 1})
                end
            else
                showUpdatePopup = false
                if _G.addDebugMessage then
                    _G.addDebugMessage("Game is up to date (" .. VERSION .. ")", {0.2, 0.8, 0.2, 1})
                end
            end
        else
            -- Нет интернета или Firebase не отвечает
            showUpdatePopup = false
            if _G.addDebugMessage then
                _G.addDebugMessage("Update check failed (no internet)", {0.5, 0.5, 0.5, 1})
            end
        end
        
        if callback then callback(showUpdatePopup, latestVersion) end
    end
    
    if online.isConnected() then
        online.sendRequest("GET", CONFIG_PATH, nil, onResponse)
    else
        isChecking = false
        showUpdatePopup = false
        if _G.addDebugMessage then
            _G.addDebugMessage("No internet, skipping update check", {0.5, 0.5, 0.5, 1})
        end
        if callback then callback(false, "") end
    end
end

function version_check.showPopup()
    return showUpdatePopup
end

function version_check.getLatestVersion()
    return latestVersion
end

function version_check.getCurrentVersion()
    return VERSION
end

function version_check.openStore()
    local url = "https://www.rustore.ru/catalog/app/com.CB3"
    
    if love.system.getOS() == "Android" then
        -- На Android открываем через intent
        local os = require("os")
        local cmd = 'am start -a android.intent.action.VIEW -d "' .. url .. '"'
        os.execute(cmd)
    else
        -- На ПК открываем в браузере
        love.system.openURL(url)
    end
end

return version_check
