--
-- Created by LeonAir RC.
-- Date: 09.01.2021
--

local locale = system.getLocale()
-- translation maps for all text elements
local appName = {en = "Vario Integrator", de = "Vario Integrator"}
local modeName = {en = {"Alt difference", "Vario integrated"}, de = {"Höhendifferenz", "Vario integriert"}}
local modeText = {en = "Mode", de = "Mode"}
local sensorText = {en = "Sensor", de = "Sensor"}
local altValueText = {en = "Altitude EX", de = "Höhe EX"}
local varioValueText = {en = "Vario EX", de = "Vario EX"}
local switchText = {en = "Switch", de = "Schalter"}
local intervalText = {en = "Interval", de = "Intervall"}
local decimalsText = {en = "Decimal places", de = "Dezimalstellen"}
local varioLabelText = {en = "Label", de = "Ankündigung"}

-- get translation from the given map, default is English
local function getTranslation(map)
    return map[locale] or map["en"]
end

local function toBoolean(str)
    if (str == "true") then return true else return false end
end

local switchOff     -- true if a switch is assigned and in off position
local mode          -- current mode (1 or 2)
local sensors       -- list of all sensor labels (sensors with param 0)
local sensorIndex   -- index of the selected sensor within 'sensors' or 0 if none is selected
local interval      -- speech interval in seconds
local decimals
local lastTime      -- time of the last announcement
local lastAltitude  -- altitude during the last announcement, only used for mode 1
local lastTimeMillis        -- time of last loop call, only used for mode 2
local altDifference         -- integreted vario value since the last announcement
local selectedSensorID      -- id of the selected sensor or nil if none isselected
local selectedAltitudeValue -- index of the selected altitude sensor value or 0 if none is selected
local selectedVarioValue    -- index of the selected vario sensor value or 0 if none is selected
local selectedSwitch        -- SwitchItem that describes the selected switch or nil if none is selected
local varioLabelActive     -- true if "vario" should be announced
local altUnit, varUnit      -- units for vario and altitude
local checkboxIndex
local selValueIndex
local labelValueIndex

local NONE = "..."
-- storage keys
local modeKey = "integrator_mode"
local intervalKey = "integrator_interval"
local decimalsKey = "integrator_decimals"
local sensorKey = "integrator_sensorID"
local altValueKey = "integrator_altValue"
local varioValueKey = "integrator_varioValue"
local switchKey = "integrator_switch"
local varioLabelKey = "integrator_varioLabel"
local altUnitKey = "integrator_altUnit"
local varUnitKey = "integrator_varioUnit"

-- resets the required values for the active mode
local function resetValues()
    lastTime = system.getTime()
    lastAltitude = 0
    if (mode == 1 and selectedSensorID and selectedAltitudeValue > 1) then -- if an altitude value is set
        local altitude = system.getSensorValueByID(selectedSensorID, selectedAltitudeValue)
        if (altitude and altitude.valid) then
            lastAltitude = altitude.value -- altitude is set to the current value
        end
    elseif (mode == 2) then
        lastTimeMillis = system.getTimeCounter()
        altDifference = 0
    end
end

-- called when the mode is changed
local function onModeChanged(value)
    mode = value
    system.pSave(modeKey, mode)
    if (sensors and sensorIndex > 0) then -- sensor selected and value selection visible
        if (mode == 1) then -- change label and selectbox value after mode change
            form.setProperties(labelValueIndex, { label = getTranslation(altValueText) })
            form.setValue(selValueIndex, selectedAltitudeValue + 1)
        else
            form.setProperties(labelValueIndex, { label = getTranslation(varioValueText) })
            form.setValue(selValueIndex, selectedVarioValue + 1)
        end
    end
    resetValues()
end

local function onIntervalChanged(newVal)
    interval = newVal
    system.pSave(intervalKey, interval)
    resetValues() -- cancel current interval and restart
end

local function onDecimalsChanged(value)
    decimals = value
    system.pSave(decimalsKey, decimals)
end

local function onSensorChanged(value)
    if (value > 1 and sensors[value - 1]) then -- reduce by 1 to remove offset from ... option
        selectedSensorID = sensors[value - 1].id -- a valid sensor was selected
    else
        selectedSensorID = nil -- no sensor selected
    end
    system.pSave(sensorKey, selectedSensorID)
    selectedAltitudeValue = 0 -- delete selected altitude value
    system.pSave(altValueKey, selectedAltitudeValue)
    selectedVarioValue = 0 -- delete selected vario value
    system.pSave(varioValueKey, selectedVarioValue)
    form.reinit() -- reinit to add or remove the sensor value selection
end

local function onAltitudeValueChanged(value)
    selectedAltitudeValue = value - 1 -- reduce by 1 to remove offset from ... option
    system.pSave(altValueKey, selectedAltitudeValue)
    if (selectedAltitudeValue > 0) then
        local sensor = system.getSensorByID(selectedSensorID, selectedAltitudeValue)
        lastAltitude = sensor.value
        altUnit = sensor.unit
        system.pSave(altUnitKey, altUnit)
    end
    lastTime = system.getTime()
end

local function onVarioValueChanged(value)
    selectedVarioValue = value - 1
    system.pSave(varioValueKey, selectedVarioValue)
    if (selectedVarioValue > 0) then
        local sensorUnit = system.getSensorByID(selectedSensorID, selectedVarioValue).unit
        local slashIndex = string.find(sensorUnit, "/")
        if not (slashIndex) then -- unit string does not contain a slash
            varUnit = sensorUnit
        else
            varUnit = string.sub(sensorUnit, 1, slashIndex - 1) -- get the altitude unit
        end
        system.pSave(varUnitKey, varUnit)
    end
    lastTime = system.getTime()
    lastTimeMillis = system.getTimeCounter()
    altDifference = 0
end

local function onValueChanged(value)
    if (mode == 1) then
        onAltitudeValueChanged(value)
    else
        onVarioValueChanged(value)
    end
end

local function onSwitchChanged(value)
    local switchVal = system.getInputsVal(value)
    if (switchVal and switchVal ~= 0) then -- if the selected switch exists, assign the new value
        selectedSwitch = value
    else -- clear the switch if the switch has a 0 value (inuptbox was cleared)
        selectedSwitch = nil
    end
    system.pSave(switchKey, selectedSwitch)
end

-- vario speech active means that the speech output begins with "vario"
local function onVarioLabelChanged(value)
    varioLabelActive = not value -- invert current value
    form.setValue(checkboxIndex, varioLabelActive) -- set checkbox value
    system.pSave(varioLabelKey, tostring(varioLabelActive))
end




local function initForm(formId)
    sensorIndex = 0 -- index of selected sensor
    local sensorLabels = {NONE} -- sensor names, offset by one for the ... option
    sensors = {} -- list of all sensors, used to find the ID of a sensor when it is selected
    local sensorValues = {} -- list of all values of all sensors
    local allSensors = system.getSensors()
    for i, sensor in ipairs(allSensors) do
        if not (sensor.type == 5 or sensor.type == 9) then
            if (sensor.param == 0) then
                sensorLabels[#sensorLabels + 1] = sensor.label -- add new sensor label
                sensors[#sensors + 1] = sensor
                if (sensor.id == selectedSensorID) then
                    sensorIndex = #sensors
                end
                sensorValues[#sensorValues + 1] = { NONE } -- first value option is ...
            else
                sensorValues[#sensorValues][sensor.param + 1] = sensor.label .. " [" .. sensor.unit .. "]"; -- param + 1 due to the offset
            end
        end
    end

    form.addRow(2)
    form.addLabel({ label = getTranslation(modeText) })
    form.addSelectbox(getTranslation(modeName), mode, false, onModeChanged, { alignRight = true })

    form.addRow(2)
    form.addLabel({ label = getTranslation(sensorText) })
    form.addSelectbox(sensorLabels, sensorIndex + 1, true, onSensorChanged, { alignRight = true }) -- sensorIndex + 1 due to the offset

    if (sensors and sensorIndex > 0) then
        form.addRow(2)
        if (mode == 1) then -- add altitude selection
            labelValueIndex = form.addLabel({ label = getTranslation(altValueText) })
            selValueIndex = form.addSelectbox(sensorValues[sensorIndex], selectedAltitudeValue + 1, true, onValueChanged, { alignRight = true })
        else -- add vario selection
            labelValueIndex = form.addLabel({ label = getTranslation(varioValueText) })
            selValueIndex = form.addSelectbox(sensorValues[sensorIndex], selectedVarioValue + 1, true, onValueChanged, { alignRight = true })
        end
    end

    form.addRow(2)
    form.addLabel({ label = getTranslation(switchText) })
    form.addInputbox(selectedSwitch, false, onSwitchChanged, { alignRight = true })

    form.addRow(2)
    form.addLabel({ label = getTranslation(intervalText) })
    form.addIntbox(interval, 5, 600, 20, 0, 1, onIntervalChanged, { alignRight = true })

    form.addRow(2)
    form.addLabel({ label = getTranslation(decimalsText) })
    form.addIntbox(decimals, 0, 2, 1, 0, 1, onDecimalsChanged, { alignRight = true })

    form.addRow(2)
    form.addLabel({ label = getTranslation(varioLabelText), width = 270 })
    checkboxIndex = form.addCheckbox(varioLabelActive, onVarioLabelChanged)
end


local function init(code)
    mode = system.pLoad(modeKey, 1)             -- default mode: 1
    interval = system.pLoad(intervalKey, 20)    -- default interval: 20s
    decimals = system.pLoad(decimalsKey, 1)     -- default decimal places: 1
    selectedSensorID = system.pLoad(sensorKey)
    selectedAltitudeValue = system.pLoad(altValueKey, 0)    -- default index for sensor values: 0 (NONE)
    selectedVarioValue = system.pLoad(varioValueKey, 0)
    selectedSwitch = system.pLoad(switchKey)
    varioLabelActive = toBoolean(system.pLoad(varioLabelKey, "false"))
    altUnit = system.pLoad(altUnitKey)
    varUnit = system.pLoad(varUnitKey)
    resetValues()
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm)
end


local function loop()
    local time = system.getTime()
    if (selectedSwitch and system.getInputsVal(selectedSwitch) ~= 1) then -- interrupt the current interval when the switch is in off position
        switchOff = true
    elseif (switchOff) then -- switch was just turned on -> start interval
        switchOff = false
        resetValues()
    end

    if (mode == 1) then -- integrator value is calculated after each interval
        if (selectedSensorID and selectedAltitudeValue > 0 and time >= interval + lastTime) then
            local altitude = system.getSensorValueByID(selectedSensorID, selectedAltitudeValue)
            if (lastAltitude and (not (selectedSwitch) or system.getInputsVal(selectedSwitch) == 1) and altitude.valid) then
                if (varioLabelActive) then
                    system.playNumber((altitude.value - lastAltitude) / interval, decimals, altUnit, "Vario")
                else
                    system.playNumber((altitude.value - lastAltitude) / interval, decimals, altUnit)
                end
            end
            lastTime = lastTime + interval
            lastAltitude = altitude.value
        end
    elseif ((not (selectedSwitch) or system.getInputsVal(selectedSwitch) == 1) and selectedSensorID and selectedVarioValue > 0) then -- switch in on position and sensor value selected
        local vario = system.getSensorValueByID(selectedSensorID, selectedVarioValue)
        if (vario and vario.valid) then
            local timeMillis = system.getTimeCounter()
            altDifference = altDifference + (timeMillis - lastTimeMillis) * vario.value * 0.001 -- add the altitude difference since the last loop call
            if (time >= interval + lastTime) then
                if (varioLabelActive) then
                    system.playNumber(altDifference / interval, decimals, varUnit, "Vario")
                else
                    system.playNumber(altDifference / interval, decimals, varUnit)
                end
                lastTime = lastTime + interval
                altDifference = 0
            end
            lastTimeMillis = timeMillis
        end
    end
end

return { init = init, loop = loop, author = "LeonAir RC", version = "1.0", name = getTranslation(appName) }