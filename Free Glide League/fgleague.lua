--[[
Copyright (c) 2024 LeonAirRC
]]

local IDLE = 0
local ENTRY = 1
local FLIGHT = 2

local enlSensorIndex
local altSensorIndex
local latSensorIndex
local lonSensorIndex
local startSwitch
local resetSwitch
local avgSpeedSwitch
local flightDurationSwitch
local enlAlarmFile
local climbAlarmFile
local startSound
local countdownStart
local entryTime

local lastStartSwVal
local lastResetSwVal
local lastAvgSpeedSwVal
local lastFlightDurationSwVal

local gpsSensorLabels
local otherSensorLabels
local gpsSensorIDs
local gpsSensorParams
local otherSensorIDs
local otherSensorParams

local state
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
    if state ~= IDLE then
        return
    end
    enlSensorIndex = value - 1
    system.pSave("enl", enlSensorIndex)
end

local function onAltSensorChanged(value)
    if state ~= IDLE then
        return
    end
    altSensorIndex = value - 1
    system.pSave("alt", altSensorIndex)
end

local function onLatSensorChanged(value)
    if state ~= IDLE then
        return
    end
    latSensorIndex = value - 1
    system.pSave("lat", latSensorIndex)
end

local function onLonSensorChanged(value)
    if state ~= IDLE then
        return
    end
    lonSensorIndex = value - 1
    system.pSave("lon", lonSensorIndex)
end

local function onStartSwitchChanged(value)
    if state ~= IDLE then
        return
    end
    startSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave("startsw", startSwitch)
end

local function onResetSwitchChanged(value)
    if state ~= IDLE then
        return
    end
    resetSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave("resetsw", resetSwitch)
end

local function onAvgSpeedSwitchChanged(value)
    if state ~= IDLE then
        return
    end
    avgSpeedSwitch = value
    system.pSave("avgspeedsw", avgSpeedSwitch)
end

local function onFlightDurationSwitchChanged(value)
    if state ~= IDLE then
        return
    end
    flightDurationSwitch = value
    system.pSave("flightdurationsw", flightDurationSwitch)
end

local function onEnlAlarmFileChanged(value)
    if state ~= IDLE then
        return
    end
    enlAlarmFile = value
    system.pSave("enlalarm", enlAlarmFile)
end

local function onClimbAlarmFileChanged(value)
    if state ~= IDLE then
        return
    end
    climbAlarmFile = value
    system.pSave("climbalarm", climbAlarmFile)
end

local function onStartSoundChanged(value)
    if state ~= IDLE then
        return
    end
    startSound = value
    system.pSave("startSound", startSound)
end

local function onCountdownStartChanged(value)
    if state ~= IDLE then
        return
    end
    countdownStart = value - 1
    system.pSave("countdownStart", countdownStart)
end

local function onEntryTimeChanged(value)
    if state ~= IDLE then
        return
    end
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
    local flightDuration = (state ~= IDLE) and (system.getTimeCounter() - startTime) / 1000 or nil
    local dist = (state == FLIGHT) and string.format("%d", distance) or nil
    local avgSpeed = (state == FLIGHT) and string.format("%.1f", distance * 3.6 / flightDuration) or nil
    local altitude = altSensorIndex ~= 0 and system.getSensorValueByID(otherSensorIDs[altSensorIndex], otherSensorParams[altSensorIndex]) or nil
    altitude = (altitude and altitude.valid) and string.format("%d", altitude.value) or nil
    local time
    if state == FLIGHT then
        time = string.format("%d:%02d:%02d", flightDuration // 3600, (flightDuration // 60) % 60, flightDuration % 60)
    elseif state == ENTRY then
        time = string.format("%d", flightDuration - entryTime)
    end
    printTelemetryRow(0, width, lang.distance, dist, "m")
    printTelemetryRow(1, width, lang.avgSpeed, avgSpeed, "km/h")
    printTelemetryRow(2, width, lang.altitude, altitude, "m")
    printTelemetryRow(3, width, lang.time, time, nil)
end

local function reset()
    distance = 0
    lastAltitude = nil
    lastGpsPoint = nil
    firstEnlExceedTime = nil
    startTime = nil
    state = IDLE
end

local function transitionToEntry(currentTime)
    startTime = currentTime
    distance = 0
    state = ENTRY
end

local function loopIdle(startSwTriggered, currentTime)
    if startSwTriggered then
        transitionToEntry(currentTime)
    end
end

local function transitionToFlight()
    lastGpsPoint = (latSensorIndex ~= 0 and lonSensorIndex ~= 0) and
            gps.getPosition(gpsSensorIDs[latSensorIndex], gpsSensorParams[latSensorIndex], gpsSensorParams[lonSensorIndex])
            or nil
    startTime = startTime + 1000 * entryTime
    state = FLIGHT

    system.playFile(startSound, AUDIO_IMMEDIATE)
end

local function loopEntry(currentTime)
    local enl = enlSensorIndex ~= 0 and system.getSensorValueByID(otherSensorIDs[enlSensorIndex], otherSensorParams[enlSensorIndex]) or nil
    if enl and enl.valid and enl.value > 300 then
        system.playFile(enlAlarmFile, AUDIO_IMMEDIATE)
    end

    local altitude = altSensorIndex ~= 0 and system.getSensorValueByID(otherSensorIDs[altSensorIndex], otherSensorParams[altSensorIndex]) or nil
    if altitude and altitude.valid then
        if lastAltitude and altitude.value > lastAltitude then
            system.playFile(climbAlarmFile, AUDIO_IMMEDIATE)
            lastAltitude = altitude.value
            transitionToEntry(currentTime)
            return
        end
        lastAltitude = altitude.value
    end

    if countdownStart ~= 0 and (currentTime - startTime) // 1000 > (lastLoopTime - startTime) // 1000 then
        local secondsUntilStart = (startTime + 1000 * entryTime - lastLoopTime) // 1000
        if secondsUntilStart <= 5 and secondsUntilStart > 0 then
            if countdownStart == 1 then
                system.playNumber(secondsUntilStart, 0, nil, nil)
            else
                system.playBeep(0, 4186, 200)
            end
        end
    end

    if currentTime >= startTime + 1000 * entryTime then
        transitionToFlight()
    end
end

local function loopFlight(avgSpeedSwTriggered, flightDurationSwTriggered, currentTime)
    local enl = enlSensorIndex ~= 0 and system.getSensorValueByID(otherSensorIDs[enlSensorIndex], otherSensorParams[enlSensorIndex]) or nil
    if enl and enl.valid and enl.value > 300 then
        if firstEnlExceedTime == nil then
            firstEnlExceedTime = currentTime
        elseif currentTime >= firstEnlExceedTime + 5000 then
            system.playFile(enlAlarmFile, AUDIO_IMMEDIATE)
            firstEnlExceedTime = firstEnlExceedTime + 5000
        end
    else
        firstEnlExceedTime = nil
    end

    if (currentTime - startTime) // 1000 > (lastLoopTime - startTime) // 1000 then
        local gpsPoint = (latSensorIndex ~= 0 and lonSensorIndex ~= 0) and
                gps.getPosition(gpsSensorIDs[latSensorIndex], gpsSensorParams[latSensorIndex], gpsSensorParams[lonSensorIndex])
                or nil
        if lastGpsPoint ~= nil and gpsPoint ~= nil then
            local distanceToLastPoint = gps.getDistance(lastGpsPoint, gpsPoint)
            local kmBefore = distance // 1000
            distance = distance + distanceToLastPoint
            local kmNow = distance // 1000
            if kmBefore < kmNow and kmNow >= 5 then
                system.playNumber(kmNow, 0, "km", lang.distanceLabel)
            end
        end

        if gpsPoint ~= nil then
            lastGpsPoint = gpsPoint
        end
    end

    if avgSpeedSwTriggered then
        local avgSpeed = distance * 3600 / (currentTime - startTime)
        system.playNumber(avgSpeed, 0, "km/h", "Speed")
    end

    if flightDurationSwTriggered then
        local flightDuration = (currentTime - startTime) // 1000
        local minutes = flightDuration // 60
        local seconds = flightDuration % 60
        system.playNumber(minutes, 0, "min", "T")
        system.playNumber(seconds, 0, "s")
    end
end

local function loop()
    local startSwVal = startSwitch and system.getInputsVal(startSwitch) or nil
    local startSwTriggered = startSwVal == 1 and lastStartSwVal ~= 1
    lastStartSwVal = startSwVal
    local resetSwVal = resetSwitch and system.getInputsVal(resetSwitch) or nil
    local resetSwTriggered = resetSwVal == 1 and lastResetSwVal ~= 1
    lastResetSwVal = resetSwVal
    local avgSpeedSwVal = avgSpeedSwitch and system.getInputsVal(avgSpeedSwitch) or nil
    local avgSpeedSwTriggered = avgSpeedSwVal == 1 and lastAvgSpeedSwVal ~= 1
    lastAvgSpeedSwVal = avgSpeedSwVal
    local flightDurationSwVal = flightDurationSwitch and system.getInputsVal(flightDurationSwitch) or nil
    local flightDurationSwTriggered = flightDurationSwVal == 1 and lastFlightDurationSwVal ~= 1
    lastFlightDurationSwVal = flightDurationSwVal

    local currentTime = system.getTimeCounter()

    if state == IDLE then
        loopIdle(startSwTriggered, currentTime)
    elseif resetSwTriggered then
        reset()
    elseif state == ENTRY then
        loopEntry(currentTime)
    elseif state == FLIGHT then
        loopFlight(avgSpeedSwTriggered, flightDurationSwTriggered, currentTime)
    end

    lastLoopTime = currentTime
end

local function initForm()
    form.setTitle(lang.appName)
    form.addLabel({ label = lang.sensors, font = FONT_BOLD })
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
    form.addLabel({ label = lang.switches, font = FONT_BOLD })
    form.addRow(2)
    form.addLabel({ label = lang.startSwitch })
    form.addInputbox(startSwitch, false, onStartSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = lang.resetSwitch })
    form.addInputbox(resetSwitch, false, onResetSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = lang.avgSpeedAnnouncementSwitch, width = 240 })
    form.addInputbox(avgSpeedSwitch, false, onAvgSpeedSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = lang.flightDurationAnnouncementSwitch, width = 240 })
    form.addInputbox(flightDurationSwitch, false, onFlightDurationSwitchChanged)
    form.addLabel({ label = lang.audio, font = FONT_BOLD })
    form.addRow(2)
    form.addLabel({ label = lang.enlAlarmFile })
    form.addAudioFilebox(enlAlarmFile, onEnlAlarmFileChanged)
    form.addRow(2)
    form.addLabel({ label = lang.climbAlarmFile })
    form.addAudioFilebox(climbAlarmFile, onClimbAlarmFileChanged)
    form.addRow(2)
    form.addLabel({ label = lang.startSound })
    form.addAudioFilebox(startSound, onStartSoundChanged)
    form.addRow(2)
    form.addLabel({ label = lang.countdownStart })
    form.addSelectbox(lang.countdownStartModes, countdownStart + 1, false, onCountdownStartChanged)
    form.addLabel({ label = lang.parameters, font = FONT_BOLD })
    form.addRow(2)
    form.addLabel({ label = lang.entryTime })
    form.addIntbox(entryTime, 1, 60, 10, 0, 1, onEntryTimeChanged, { label = "s" })
end

local function init()
    state = IDLE
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
    startSound = system.pLoad("startSound", "")
    countdownStart = system.pLoad("countdownStart", 0)
    entryTime = system.pLoad("entrytime", 10)
    avgSpeedSwitch = system.pLoad("avgspeedsw")
    flightDurationSwitch = system.pLoad("flightdurationsw")

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
return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.2.1", name = lang.appName }