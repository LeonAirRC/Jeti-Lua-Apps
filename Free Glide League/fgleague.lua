--[[
Copyright (c) 2024 LeonAirRC
]]

local enlSensorIndex
local altSensorIndex
local latSensorIndex
local lonSensorIndex
local startSwitch
local resetSwitch
local enlAlarmFile
local climbAlarmFile
local entryTime

local gpsSensorLabels
local otherSensorLabels
local gpsSensorIDs
local gpsSensorParams
local otherSensorIDs
local otherSensorParams

local lastGpsPoint
local lastAltitude
local lastLoopTime
local startTime
local distance
local firstEnlExceedTime

local langContent = io.readall("Apps/FreeGlideLeague/lang.jsn")
assert(langContent ~= nil, "The file FreeGlideLeague/lang.jsn is missing")
langContent = json.decode(langContent)
local lang = langContent[system.getLocale()] or langContent["en"]
langContent = nil

local ROW_HEIGHT = 24
local TELEM_VALUE_Y_OFFSET = (ROW_HEIGHT - lcd.getTextHeight(FONT_BIG)) // 2
local TELEM_UNIT_Y_OFFSET = (ROW_HEIGHT + lcd.getTextHeight(FONT_BIG)) // 2 - 1 - lcd.getTextHeight(FONT_NORMAL)
local TELEM_UNIT_WIDTH = lcd.getTextWidth(FONT_NORMAL, "km/h")

local function onEnlSensorChanged(value)
    enlSensorIndex = value - 1
    system.pSave("enl", enlSensorIndex)
end

local function onAltSensorChanged(value)
    altSensorIndex = value - 1
    system.pSave("alt", altSensorIndex)
end

local function onLatSensorChanged(value)
    latSensorIndex = value - 1
    system.pSave("lat", latSensorIndex)
end

local function onLonSensorChanged(value)
    lonSensorIndex = value - 1
    system.pSave("lon", lonSensorIndex)
end

local function onStartSwitchChanged(value)
    startSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave("startsw", startSwitch)
end

local function onResetSwitchChanged(value)
    resetSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave("resetsw", resetSwitch)
end

local function onEnlAlarmFileChanged(value)
    enlAlarmFile = value
    system.pSave("enlalarm", enlAlarmFile)
end

local function onClimbAlarmFileChanged(value)
    climbAlarmFile = value
    system.pSave("climbalarm", climbAlarmFile)
end

local function onEntryTimeChanged(value)
    entryTime = value
    system.pSave("entrytime", entryTime)
end

local function printTelemetryRow(row, width, label, value, unit)
    local y = row * ROW_HEIGHT
    value = value or "-"
    lcd.drawText(6, y + TELEM_UNIT_Y_OFFSET, label, FONT_NORMAL)
    lcd.drawText(width - TELEM_UNIT_WIDTH - lcd.getTextWidth(FONT_BIG, value) - 12, y + TELEM_VALUE_Y_OFFSET, value, FONT_BIG)
    if unit then
        lcd.drawText(width - TELEM_UNIT_WIDTH - 6, y + TELEM_UNIT_Y_OFFSET, unit, FONT_NORMAL)
    end
end

local function printTelemetry(width, _)
    local flightDuration = startTime and (system.getTimeCounter() - startTime) / 1000 - entryTime or nil
    local dist = startTime and string.format("%d", distance) or nil
    local avgSpeed = (startTime and flightDuration > 0) and string.format("%.1f", distance * 3.6 / flightDuration) or nil
    local altitude = altSensorIndex ~= 0 and system.getSensorValueByID(otherSensorIDs[altSensorIndex], otherSensorParams[altSensorIndex]) or nil
    altitude = (altitude and altitude.valid) and string.format("%d", altitude.value) or nil
    local time
    if startTime and flightDuration >= 0 then
        time = string.format("%d:%02d:%02d", flightDuration // 3600, (flightDuration // 60) % 60, flightDuration % 60)
    elseif startTime then
        time = string.format("%d", flightDuration)
    end
    printTelemetryRow(0, width, lang.distance, dist, "m")
    printTelemetryRow(1, width, lang.avgSpeed, avgSpeed, "km/h")
    printTelemetryRow(2, width, lang.altitude, altitude, "m")
    printTelemetryRow(3, width, lang.time, time, nil)
end

local function loop()
    if resetSwitch and system.getInputsVal(resetSwitch) == 1 then
        distance = 0
        lastAltitude = nil
        lastGpsPoint = nil
        firstEnlExceedTime = nil
        startTime = nil
        lastLoopTime = nil
        return
    end
    if startTime == nil then
        if startSwitch and system.getInputsVal(startSwitch) == 1 then
            distance = 0
            lastAltitude = nil
            lastGpsPoint = nil
            firstEnlExceedTime = nil
            startTime = system.getTimeCounter()
            lastLoopTime = startTime
        else
            return
        end
    end
    local enl = enlSensorIndex ~= 0 and system.getSensorValueByID(otherSensorIDs[enlSensorIndex], otherSensorParams[enlSensorIndex]) or nil
    enl = (enl and enl.valid) and enl.value or nil
    local altitude = altSensorIndex ~= 0 and system.getSensorValueByID(otherSensorIDs[altSensorIndex], otherSensorParams[altSensorIndex]) or nil
    altitude = (altitude and altitude.valid) and altitude.value or nil

    local currentTime = system.getTimeCounter()

    if currentTime < startTime + 1000 * entryTime then
        -- before start
        if enl and enl > 300 then
            system.playFile(enlAlarmFile, AUDIO_IMMEDIATE)
        end
        if lastAltitude and altitude and altitude > lastAltitude then
            system.playFile(climbAlarmFile, AUDIO_IMMEDIATE)
        end
    else
        -- after start
        if enl and enl > 300 then
            if firstEnlExceedTime == nil then
                firstEnlExceedTime = currentTime
            elseif currentTime >= firstEnlExceedTime + 5000 then
                system.playFile(enlAlarmFile, AUDIO_IMMEDIATE)
                firstEnlExceedTime = firstEnlExceedTime + 5000
            end
        else
            firstEnlExceedTime = nil
        end
        if lastLoopTime ~= nil and currentTime // 1000 > lastLoopTime // 1000 then
            local gpsPoint = (latSensorIndex ~= 0 and lonSensorIndex ~= 0) and
                    gps.getPosition(gpsSensorIDs[latSensorIndex], gpsSensorParams[latSensorIndex], gpsSensorParams[lonSensorIndex])
                    or nil
            if lastGpsPoint == nil then
                lastGpsPoint = gpsPoint
            elseif gpsPoint ~= nil then
                local distanceToLastPoint = gps.getDistance(lastGpsPoint, gpsPoint)
                local kmBefore = distance // 1000
                distance = distance + distanceToLastPoint
                local kmNow = distance // 1000
                if kmBefore < kmNow and kmNow >= 5 then
                    system.playNumber(kmNow, 0, "km", lang.distanceLabel)
                end
                lastGpsPoint = gpsPoint
            end
        end
    end

    lastAltitude = altitude
    lastLoopTime = currentTime
end

local function initForm()
    form.setTitle(lang.appName)
    form.addRow(2)
    form.addLabel({ label = lang.enlSensor })
    form.addSelectbox(otherSensorLabels, enlSensorIndex + 1, true, onEnlSensorChanged)
    form.addRow(2)
    form.addLabel({ label = lang.altSensor })
    form.addSelectbox(otherSensorLabels, altSensorIndex + 1, true, onAltSensorChanged)
    form.addRow(2)
    form.addLabel({ label = lang.gpsLatitude })
    form.addSelectbox(gpsSensorLabels, latSensorIndex + 1, true, onLatSensorChanged)
    form.addRow(2)
    form.addLabel({ label = lang.gpsLongitude })
    form.addSelectbox(gpsSensorLabels, lonSensorIndex + 1, true, onLonSensorChanged)
    form.addRow(2)
    form.addLabel({ label = lang.startSwitch })
    form.addInputbox(startSwitch, false, onStartSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = lang.resetSwitch })
    form.addInputbox(resetSwitch, false, onResetSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = lang.enlAlarmFile })
    form.addAudioFilebox(enlAlarmFile, onEnlAlarmFileChanged)
    form.addRow(2)
    form.addLabel({ label = lang.climbAlarmFile })
    form.addAudioFilebox(climbAlarmFile, onClimbAlarmFileChanged)
    form.addRow(2)
    form.addLabel({ label = lang.entryTime })
    form.addIntbox(entryTime, 1, 60, 10, 0, 1, onEntryTimeChanged, { label = "s" })
end

local function init()
    gpsSensorLabels = { "..." }
    otherSensorLabels = { "..." }
    gpsSensorIDs = {}
    gpsSensorParams = {}
    otherSensorIDs = {}
    otherSensorParams = {}
    local sensors = system.getSensors()
    for _, sensor in ipairs(sensors) do
        if sensor.param ~= 0 and sensor.type == 9 then
            gpsSensorLabels[#gpsSensorLabels + 1] = string.format("%s: %s", sensor.sensorName, sensor.label)
            gpsSensorIDs[#gpsSensorIDs + 1] = sensor.id
            gpsSensorParams[#gpsSensorParams + 1] = sensor.param
        elseif sensor.param ~= 0 and sensor.type ~= 5 then
            otherSensorLabels[#otherSensorLabels + 1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
            otherSensorIDs[#otherSensorIDs + 1] = sensor.id
            otherSensorParams[#otherSensorParams + 1] = sensor.param
        end
    end

    enlSensorIndex = system.pLoad("enl", 0)
    altSensorIndex = system.pLoad("alt", 0)
    latSensorIndex = system.pLoad("lat", 0)
    lonSensorIndex = system.pLoad("lon", 0)
    startSwitch = system.pLoad("startsw")
    resetSwitch = system.pLoad("resetsw")
    enlAlarmFile = system.pLoad("enlalarm", "")
    climbAlarmFile = system.pLoad("climbalarm", "")
    entryTime = system.pLoad("entrytime", 10)

    if enlSensorIndex > #otherSensorIDs then
        enlSensorIndex = 0
    end
    if altSensorIndex > #otherSensorIDs then
        altSensorIndex = 0
    end
    if latSensorIndex > #gpsSensorIDs then
        latSensorIndex = 0
    end
    if lonSensorIndex > #gpsSensorIDs then
        lonSensorIndex = 0
    end

    system.registerForm(1, MENU_APPS, lang.appName, initForm)
    system.registerTelemetry(1, "Free Glide League", 4, printTelemetry)
end

local function destroy()
    system.unregisterTelemetry(1)
end

collectgarbage()
return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.0.0", name = lang.appName }