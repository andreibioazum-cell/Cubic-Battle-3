-- version_check.lua – проверка обновлений (исправлен)
local version_check = {}

local online = require("online")
local VERSION = "13"  -- Текущая версия игры
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local CONFIG_PATH = "config/version"

local showUpdatePopup = false
local latestVersion = ""
local updateChecked = false
local isChecking = false

-- ============================================================
--  ПРОВЕРКА ОБНОВЛЕНИЙ
-- ============================================================
function version_check.check(callback)
    if isChecking then return end
    isChecking = true
    
    print("[VERSION_CHECK] Checking for updates...")
    
    local function onResponse(ok, data)
        isChecking = false
        
        if ok and data then
            -- Убираем кавычки и пробелы
            latestVersion = data:gsub('"', ''):gsub(' ', '')
            updateChecked = true
            
            print("[VERSION_CHECK] Current version: " .. VERSION)
            print("[VERSION_CHECK] Latest version: " .. latestVersion)
            
            -- Сравниваем версии (простое строковое сравнение)
            if latestVersion > VERSION then
                showUpdatePopup = true
                if _G.addDebugMessage then
                    _G.addDebugMessage("New version available: " .. latestVersion, {1, 0.8, 0.2, 1})
                end
                print("[VERSION_CHECK] ✅ New version available!")
            else
                showUpdatePopup = false
                if _G.addDebugMessage then
                    _G.addDebugMessage("Game is up to date (" .. VERSION .. ")", {0.2, 0.8, 0.2, 1})
                end
                print("[VERSION_CHECK] ✅ Game is up to date!")
            end
        else
            -- Нет интернета или Firebase не отвечает
            showUpdatePopup = false
            if _G.addDebugMessage then
                _G.addDebugMessage("Update check failed", {0.5, 0.5, 0.5, 1})
            end
            print("[VERSION_CHECK] ❌ Update check failed!")
        end
        
        if callback then 
            callback(showUpdatePopup, latestVersion) 
        end
    end
    
    -- Используем online.sendRequest (он теперь универсальный)
    -- Пробуем подключиться, если не подключены
    if not online.isConnected() then
        print("[VERSION_CHECK] Not connected, trying to connect...")
        online.connect()
        -- Даем время на подключение (используем таймер)
        local startTime = love.timer.getTime()
        while not online.isConnected() and love.timer.getTime() - startTime < 3 do
            -- Ждем максимум 3 секунды
            love.timer.sleep(0.1)
        end
    end
    
    if online.isConnected() then
        print("[VERSION_CHECK] Sending request...")
        online.sendRequest("GET", CONFIG_PATH, nil, onResponse)
    else
        isChecking = false
        showUpdatePopup = false
        if _G.addDebugMessage then
            _G.addDebugMessage("No internet, skipping update check", {0.5, 0.5, 0.5, 1})
        end
        print("[VERSION_CHECK] ❌ No internet connection!")
        if callback then callback(false, "") end
    end
end

-- ============================================================
--  ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================
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
        print("[VERSION_CHECK] Opening store on Android: " .. url)
    else
        -- На ПК открываем в браузере
        love.system.openURL(url)
        print("[VERSION_CHECK] Opening store on PC: " .. url)
    end
end

-- ============================================================
--  ПРИНУДИТЕЛЬНАЯ ПРОВЕРКА (для отладки)
-- ============================================================
function version_check.forceCheck()
    showUpdatePopup = false
    latestVersion = ""
    updateChecked = false
    isChecking = false
    version_check.check()
end

return version_check
