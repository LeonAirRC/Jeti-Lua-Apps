local modeKey = "int_mode"
local intervalKey = "int_int"
local decimalsKey = "int_dec"
local enableSwitchKey = "int_enable"
local varioLabelActiveKey = "int_varlbl"
local varioSensorIndexKey = "int_vars"
local altitudeSensorIndexKey = "int_alts"

local switchOn
local mode
local interval
local decimals
local varioLabelActive
local lastTime
local lastSpeech
local lastAltitude
local altitudeDifference
local enableSwitch

local checkboxIndex, sensorLabelIndex, sensorSelectboxIndex

local varioSensorIndex
local altitudeSensorIndex
local sensorIDs
local sensorParams
local sensorLabels
local sensorUnits

local locale = system.getLocale()
-- translation maps for all text elements
local appName = {en = "Vario Integrator", de = "Vario Integrator"}
local modeNames = {en = {"Vario integrated", "Alt difference"}, de = {"Vario integriert", "Höhendifferenz"}}
local modeText = {en = "Mode", de = "Mode"}
local varioSensorText = {en = "Vario EX", de = "Vario EX"}
local altitudeSensorText = {en = "Altitude EX", de = "Höhe EX"}
local enableSwitchText = {en = "Switch", de = "Schalter"}
local intervalText = {en = "Interval", de = "Intervall"}
local decimalsText = {en = "Decimal places", de = "Dezimalstellen"}
local varioLabelActiveText = {en = "Label", de = "Ankündigung"}

-- get translation from the given map, default is English
local function getTranslation(map)
    return map[locale] or map["en"]
end

local function reset()
    lastSpeech = system.getTimeCounter()
    if mode == 1 then
        altitudeDifference = 0
        lastTime = lastSpeech
    else
        if altitudeSensorIndex ~= 0 then
            local altitude = system.getSensorValueByID(sensorIDs[altitudeSensorIndex], sensorParams[altitudeSensorIndex])
            lastAltitude = (altitude and altitude.valid) and altitude.value or nil
        else
            lastAltitude = nil
        end
    end
end

local function onModeChanged(value)
    mode = value
    form.setProperties(sensorLabelIndex, { label = getTranslation(mode == 1 and varioSensorText or altitudeSensorText) })
    form.setValue(sensorSelectboxIndex, mode == 1 and varioSensorIndex + 1 or altitudeSensorIndex + 1)
    reset()
    system.pSave(modeKey, mode)
end

local function onSensorIndexChanged(value)
    if mode == 1 then
        varioSensorIndex = value - 1
        system.pSave(varioSensorIndexKey, varioSensorIndex)
    else
        altitudeSensorIndex = value - 1
        system.pSave(altitudeSensorIndexKey, altitudeSensorIndex)
    end
    reset()
end

local function onEnableSwitchChanged(value)
    if system.getInputsVal(value) ~= 0 then
        enableSwitch = value
    else
        enableSwitch = nil
    end
    system.pSave(enableSwitchKey, enableSwitch)
end

local function onIntervalChanged(value)
    interval = value
    reset()
    system.pSave(intervalKey, interval)
end

local function onDecimalsChanged(value)
    decimals = value
    system.pSave(decimalsKey, decimals)
end

local function onVarioLabelActiveChanged(value)
    varioLabelActive = not value
    form.setValue(checkboxIndex, varioLabelActive)
    system.pSave(varioLabelActiveKey, varioLabelActive and "true" or "false")
end

local function loop()
    if enableSwitch and system.getInputsVal(enableSwitch) ~= 1 then
        switchOn = false
    elseif not switchOn then
        switchOn = true
        reset()
    end
    if switchOn and mode == 1 and varioSensorIndex ~= 0 then

        local vario = system.getSensorValueByID(sensorIDs[varioSensorIndex], sensorParams[varioSensorIndex])
        if vario and vario.valid then
            local time = system.getTimeCounter()
            altitudeDifference = altitudeDifference + (time - lastTime) * vario.value * 0.001
            if time >= lastSpeech + interval * 1000 then
                system.playNumber(altitudeDifference / interval, decimals, sensorUnits[varioSensorIndex], varioLabelActive and "Vario" or nil)
                lastSpeech = lastSpeech + interval * 1000
                altitudeDifference = 0
            end
            lastTime = time
        else
            lastTime = system.getTimeCounter()
            lastSpeech = lastTime
            altitudeDifference = 0
        end

    elseif switchOn and mode == 2 and altitudeSensorIndex ~= 0 then

        local time = system.getTimeCounter()
        if lastAltitude and time >= lastSpeech + interval * 1000 then
            local altitude = system.getSensorValueByID(sensorIDs[altitudeSensorIndex], sensorParams[altitudeSensorIndex])
            if altitude and altitude.valid then
                system.playNumber((altitude.value - lastAltitude) / interval, decimals, sensorUnits[altitudeSensorIndex] .. "/s", varioLabelActive and  "Vario" or nil)
                lastAltitude = altitude.value
            else
                lastAltitude = nil
                lastSpeech = time
            end
            lastSpeech = lastSpeech + interval * 1000
        elseif not lastAltitude then
            local altitude = system.getSensorByID(sensorIDs[altitudeSensorIndex], sensorParams[altitudeSensorIndex])
            lastAltitude = (altitude and altitude.valid) and altitude.value or nil
            lastSpeech = time
        end
    end
    collectgarbage()
end

local function initForm()
    form.addRow(2)
    form.addLabel({ label = getTranslation(modeText) })
    form.addSelectbox(getTranslation(modeNames), mode, false, onModeChanged)
    form.addRow(2)
    sensorLabelIndex = form.addLabel({ label = getTranslation(mode == 1 and varioSensorText or altitudeSensorText) })
    sensorSelectboxIndex = form.addSelectbox(sensorLabels, mode == 1 and varioSensorIndex + 1 or altitudeSensorIndex + 1, true, onSensorIndexChanged)
    form.addRow(2)
    form.addLabel({ label = getTranslation(enableSwitchText) })
    form.addInputbox(enableSwitch, false, onEnableSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = getTranslation(intervalText) })
    form.addIntbox(interval, 5, 600, 20, 0, 1, onIntervalChanged)
    form.addRow(2)
    form.addLabel({ label = getTranslation(decimalsText) })
    form.addIntbox(decimals, 0, 2, 1, 0, 1, onDecimalsChanged)
    form.addRow(2)
    form.addLabel({ label = getTranslation(varioLabelActiveText), width = 270 })
    checkboxIndex = form.addCheckbox(varioLabelActive, onVarioLabelActiveChanged)
    collectgarbage()
end

local function init()
    sensorLabels = {"..."}
    sensorIDs = {}
    sensorParams = {}
    sensorUnits = {}
    for _, sensor in ipairs(system.getSensors()) do
        if sensor.param ~= 0 and sensor.type ~= 5 and sensor.type ~= 9 then
            sensorLabels[#sensorLabels+1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
            sensorIDs[#sensorIDs+1] = sensor.id
            sensorParams[#sensorParams+1] = sensor.param
            sensorUnits[#sensorUnits+1] = sensor.unit
        end
    end

    mode = system.pLoad(modeKey, 1)
    interval = system.pLoad(intervalKey, 20)
    decimals = system.pLoad(decimalsKey, 1)
    enableSwitch = system.pLoad(enableSwitchKey)
    varioLabelActive = system.pLoad(varioLabelActiveKey, "false") == "true"
    varioSensorIndex = system.pLoad(varioSensorIndexKey, 0)
    altitudeSensorIndex = system.pLoad(altitudeSensorIndexKey, 0)
    if varioSensorIndex > #sensorIDs then varioSensorIndex = 0 end
    if altitudeSensorIndex > #sensorIDs then altitudeSensorIndex = 0 end
    reset()
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm)
    collectgarbage()
end

return { init = init, loop = loop, author = "LeonAir RC", version = "1.1", name = getTranslation(appName) }