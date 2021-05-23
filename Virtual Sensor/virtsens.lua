--[[
Copyright (c) 2021 LeonAirRC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local filepath = "Apps/VirtualSensor/sensors.json"

local units = {"", "m", "km", "s", "min", "h", "m/s", "km/h", "V", "A", "mAh", "Ah", "W", "Wmi", "°C", "°", "%", "l", "ml", "hl", "l/m", "ml/m", "hPa", "kPa", "b",
                "ft", "mi.", "yd.", "ft/s", "mph", "kt.", "F", "psi", "atm", "floz", "gal", "oz/m", "gpm"}

local inputs = {"...", "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10",
                "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SP",
                "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10", "T11", "T12", "T13", "T14", "T15", "T16",
                "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8",
                "O1", "O2", "O3", "O4", "O5", "O6", "O7", "O8", "O9", "O10", "O11", "O12", "O13", "O14", "O15", "O16", "O17", "O18", "O19", "O20", "O21", "O22", "O23", "O24"}
local controls = {"...", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10"}
local specialTypes = 3 -- last sensor type that is 'special' (has no parameters)
local twoOpTypes = 18 -- last sensor type that has two parameters
local refreshInterval = 500 -- interval in ms for the value refresh on display
local lastTime = system.getTimeCounter()
local activeTelemetryKey = "vs_acttel"
local singleSwitchKey = "vs_switch"
local intervalSwitchKey = "va_intswitch"
local intervalKey = "va_int"

local sensors -- list of sensors where each sensor can be a tree of sensor nodes
local nodeStack = {} -- Represents the stack of nodes as the user navigates through the sensor's tree structure. First element is the top element
local evalFunctions
local valueLabelIndex
local controlSelectIndex
local activeTelemetryIndex -- index of the sensor that is currently displayed in the telemetry frame
local currFormID -- id of the current form
local singleSwitch -- switch for single voice announcements
local intervalSwitch -- switch for interval voice announcements
local interval -- interval time in seconds
local lastSingleSwitchVal -- last value of the singleSwitch
local lastAnnouncement -- timestemp of the last interval-announcement

local sensorIDs -- array of the sensor ids, indices corresponding to the sensors listed in sensorLabels
local sensorParams -- array of the sensor params, indices corresponding to the sensors listed in sensorLabels
local sensorLabels -- selection options for the sensor inputs: "<SensorLabel>: <SensorParam><unit>"
local logSensors

local lang

local MAX_PRIO = 5

local nodeTypes

local function toNumber(boolean)
    return boolean and 1 or 0
end

--------------------------------------------------------------------------------------
-- returns true if and only if one of the sensors is assigned to the specified control
-- only respects sensors at indices 1-limit
--------------------------------------------------------------------------------------
local function controlRegistered(controlNo, limit)
    limit = limit or #sensors
    for i = 1, limit do
        if sensors[i].control == controlNo then
            return true
        end
    end
    return false
end

-------------------
-- callback methods
-------------------
local function onSingleSwitchChanged(value)
    singleSwitch = value
    lastSingleSwitchVal = system.getInputsVal(singleSwitch)
    if lastSingleSwitchVal == 0.0 then
        singleSwitch = nil
        lastSingleSwitchVal = nil
    end
    system.pSave(singleSwitchKey, singleSwitch)
end

local function onIntervalChanged(value)
    interval = value
    if lastAnnouncement then
        lastAnnouncement = system.getTimeCounter()
    end
    system.pSave(intervalKey, interval)
end

local function onIntervalSwitchChanged(value)
    intervalSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave(intervalSwitchKey, intervalSwitch)
end

local function onSensorLabelChanged(index, value)
    sensors[index].label = value
end

local function onDecimalsChanged(index, value)
    sensors[index].decimals = value
end

local function onSensorUnitChanged(index, value)
    sensors[index].unit = value
end

----------------------------------------------------------------------------------
-- Changes the type of the current node. All properties are set to default values.
----------------------------------------------------------------------------------
local function onNodeTypeChanged(value)
    if nodeStack[1].type ~= value then
        local node = nodeStack[1]
        node.type = value
        node.const = nil -- delete old attributes
        node.sensor = nil
        node.input = nil
        if value <= specialTypes then -- new type is a special type
            node.p1 = nil -- delete both earlier parameters (if existent)
            node.p2 = nil
            if value == 1 then -- add new default values dependent on type
                node.const = 0
            elseif value == 2 then
                node.sensor = 0
            elseif value == 3 then
                node.input = 1
            end
        else -- the new node requires 1 or 2 parameters
            if value <= twoOpTypes then -- requires 2 parameters
                node.p2 = node.p2 or {type = 1, const = 0} -- add new p2-node if not already existent
            else -- requires 1 parameter
                node.p2 = nil -- delete parameter 2
            end
            node.p1 = node.p1 or {type = 1, const = 0} -- add new p1-node if not already existent
        end
        form.reinit()
        collectgarbage()
    end
end

local function onConstChanged(value)
    nodeStack[1].const = value
end

local function onSensorChanged(value)
    nodeStack[1].sensor = value - 1
end

local function onInputChanged(value)
    nodeStack[1].input = value
end

local function onOperandSelected(opNum)
    table.insert(nodeStack, 1, opNum == 1 and nodeStack[1].p1 or nodeStack[1].p2)
    form.reinit()
end

---------------------------------------------------
-- indices are shifted by +1 due to the ... option
---------------------------------------------------
local function onControlChanged(value)
    if value ~= nodeStack[1].control + 1 then
        if value == 1 then -- control deleted
            system.unregisterControl(nodeStack[1].control)
            nodeStack[1].control = 0
        else
            if nodeStack[1].control > 0 then -- unregister old control
                system.unregisterControl(nodeStack[1].control)
            end
            if (not controlRegistered(value - 1)) and system.registerControl(value - 1, nodeStack[1].label, controls[value]) ~= nil then    -- successfully registered new control
                                                                                                                                            -- fails if other apps or other sensors have registered the same control
                nodeStack[1].control = value - 1
            else
                nodeStack[1].control = 0
                form.setValue(controlSelectIndex, 1)
                system.messageBox(string.format(lang.registerErrorText, value - 1))
            end
        end
    end
end

-------------------------------------------------------------------------
-- saves the 'sensors' table in json format
-------------------------------------------------------------------------
local function save()
    if sensors then
        local file = io.open(filepath, "w")
        if file then
            if not io.write(file, json.encode(sensors)) then
                system.messageBox(lang.fileInexistentText) -- show error text
            end
            io.close(file)
        else
            system.messageBox(lang.fileInexistentText)
        end
    end
end

-------------------------------------------------------------------------
-- recursively evaluates the specified node, according to it's type
-------------------------------------------------------------------------
local function evaluate(node)
    return evalFunctions[node.type](node)
end

-------------------------------------------------------------------------
-- evaluation functions, indexed by node type for high efficiency access
-- each function takes the node as a parameter
-------------------------------------------------------------------------
evalFunctions = {
    function(node) -- CONST
        return node.const
    end,
    function(node) -- SENSOR
        local id,param = sensorIDs[node.sensor], sensorParams[node.sensor]
        if id and param then
            local val = system.getSensorValueByID(id, param)
            return (val and val.valid) and val.value or nil
        else
            return nil
        end
    end,
    function(node) -- INPUT
        return node.input > 1 and system.getInputs(inputs[node.input]) or nil
    end,
    function(node) -- ADD
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and (firstVal + secondVal) or nil
    end,
    function(node) -- SUB
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and (firstVal - secondVal) or nil
    end,
    function(node) -- MUL
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and (firstVal * secondVal) or nil
    end,
    function(node) -- DIV
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal and secondVal ~= 0.0) and (firstVal / secondVal) or nil
    end,
    function(node) -- MIN
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        if firstVal then
            return secondVal and math.min(firstVal, secondVal) or firstVal
        else
            return secondVal
        end
    end,
    function(node) -- MAX
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        if firstVal then
            return secondVal and math.max(firstVal, secondVal) or firstVal
        else
            return secondVal
        end
    end,
    function(node) -- =
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber(firstVal == secondVal) or nil
    end,
    function(node) -- <
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber(firstVal < secondVal) or nil
    end,
    function(node) -- >
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber(firstVal > secondVal) or nil
    end,
    function(node) -- <=
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber(firstVal <= secondVal) or nil
    end,
    function(node) -- >=
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber(firstVal >= secondVal) or nil
    end,
    function(node) -- AND
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber(firstVal >= 1 and secondVal >= 1) or nil
    end,
    function(node) -- OR
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber(firstVal >=1 or secondVal >= 1) or nil
    end,
    function(node) -- XOR
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber((firstVal >= 1) ~= (secondVal >= 1)) or nil
    end,
    function(node) -- IMPL
        local firstVal = evaluate(node.p1)
        local secondVal = evaluate(node.p2)
        return (firstVal and secondVal) and toNumber(firstVal < 1 or secondVal >= 1) or nil
    end,
    function(node) -- NOT
        local val = evaluate(node.p1)
        return val and toNumber(val < 1) or nil
    end,
    function(node) -- ABS
        local val = evaluate(node.p1)
        return val and math.abs(val) or nil
    end,
    function(node) -- ROUND
        local val = evaluate(node.p1)
        return val and math.floor(val + 0.5) or nil
    end,
    function(node) -- FLOOR
        local val = evaluate(node.p1)
        return val and math.floor(val) or nil
    end,
    function(node) -- CEIL
        local val = evaluate(node.p1)
        return val and math.ceil(val) or nil
    end,
    function(node) --ROOT
        local val = evaluate(node.p1)
        return (val and val >= 0) and math.sqrt(val) or nil
    end,
    function(node) -- SIN
        local val = evaluate(node.p1)
        return val and math.sin(math.rad(val)) or nil
    end,
    function(node) -- COS
        local val = evaluate(node.p1)
        return val and math.cos(math.rad(val)) or nil
    end,
    function(node) -- TAN
        local val = evaluate(node.p1)
        return val and math.tan(math.rad(val)) or nil
    end,
    function(node) -- ASIN
        local val = evaluate(node.p1)
        return val and math.deg(math.asin(val)) or nil
    end,
    function(node) -- ACOS
        local val = evaluate(node.p1)
        return val and math.deg(math.acos(val)) or nil
    end,
    function(node) -- ATAN
        local val = evaluate(node.p1)
        return val and math.deg(math.atan(val)) or nil
    end
}

---------------------------------
-- key callback function
---------------------------------
local function onKeyPressed(keyCode)
    if #nodeStack > 0 then -- node stack is not empty
        form.preventDefault()
        if keyCode == KEY_ESC or keyCode == KEY_5 then
            nodeStack = {} -- clear stack to display main page on reinit
            form.reinit()
        elseif keyCode == KEY_1 then
            table.remove(nodeStack, 1) -- go up one level
            form.reinit()
        elseif keyCode == KEY_2 and nodeStack[1].type > specialTypes then
            onOperandSelected(1)
        elseif keyCode == KEY_3 and nodeStack[1].type > specialTypes and nodeStack[1].type <= twoOpTypes then
            onOperandSelected(2)
        end
    elseif currFormID == 2 then -- voice announcement page
        if keyCode == KEY_ESC or keyCode == KEY_5 then
            form.preventDefault()
            form.reinit() -- go back to main page
        end
    else -- main page
        local focused = form.getFocusedRow() - 1
        if keyCode == KEY_1 and #sensors < 8 then -- add new default sensor
            
            local defaultSensor = { label = "vsensor " .. tostring(#sensors + 1), unit = 1, decimals = 1, type = 1, const = 0, prio = 0, voiceLabel = "", control = 0 }
            table.insert(sensors, defaultSensor)
            form.reinit()

        elseif keyCode == KEY_2 and focused > 0 and focused <= #sensors then -- delete focused sensor

            if sensors[focused].control > 0 then
                system.unregisterControl(sensors[focused].control) -- unregister assigned control
            end
            table.remove(sensors, focused)
            if activeTelemetryIndex then
                if activeTelemetryIndex == focused then -- delete the telemetry sensor if the deleted one is selected
                    activeTelemetryIndex = nil
                    system.pSave(activeTelemetryKey, activeTelemetryIndex)
                elseif activeTelemetryIndex > focused then -- reduce telemetry sensor index by 1
                    activeTelemetryIndex = activeTelemetryIndex - 1
                    system.pSave(activeTelemetryKey, activeTelemetryIndex)
                end
            end
            form.reinit()

        elseif keyCode == KEY_3 and #sensors > 0 and focused > 0 then -- put the focused sensor onto the stack and reinit

            table.insert(nodeStack, sensors[focused])
            form.reinit()

        elseif keyCode == KEY_4 and #sensors > 0 and focused > 0 then -- select focused sensor to be displayed in the telemetry frame

            activeTelemetryIndex = focused
            system.pSave(activeTelemetryKey, activeTelemetryIndex)
            form.reinit()

        end
    end
    collectgarbage()
end

--------------------------------------------------------------------------------------------------------
-- Request method for log variables. Evaluates the sensor whose label is mapped to the requested log id.
--------------------------------------------------------------------------------------------------------
local function getLogVariableValue(logVariableID)
    local sensor = logSensors[logVariableID]
    local value = evaluate(sensor)
    if value then
        return math.floor(value * 10^sensor.decimals), sensor.decimals -- return integer value and number of decimals
    else
        return nil,0
    end
end

--------------------------------------------------------------------------------------------------------
-- announces all sensor values according to their priorities
--------------------------------------------------------------------------------------------------------
local function voiceAnnouncement()
    for prio = MAX_PRIO,1,-1 do
        for _,sensor in ipairs(sensors) do
            if sensor.prio == prio then
                local val = evaluate(sensor)
                if val then
                    system.playFile(sensor.voiceLabel, AUDIO_QUEUE)
                    system.playNumber(val, sensor.decimals, units[sensor.unit])
                end
            end
        end
    end
    collectgarbage()
end

---------------------------------------------------------------------------------------------------
-- prints the current value of the selected virtual sensor, correspondent to the amount of decimals
---------------------------------------------------------------------------------------------------
local function printTelemetry(width, height)
    if activeTelemetryIndex then
        local font = height > 30 and FONT_MAXI or FONT_BOLD
        local val = evaluate(sensors[activeTelemetryIndex])
        local text = val and string.format("%." .. string.format("%d", sensors[activeTelemetryIndex].decimals) .. "f %s", val, units[sensors[activeTelemetryIndex].unit]) or "-"
        lcd.drawText(width - 10 - lcd.getTextWidth(font, text), (height - lcd.getTextHeight(font)) / 2, text, font)
    end
end

local function initForm(formID)
    currFormID = formID
    if #nodeStack > 0 then

        form.setTitle(string.format("%s - %s %d", nodeStack[#nodeStack].label, lang.levelText, #nodeStack))
        form.addRow(1)
        form.addSelectbox(nodeTypes, nodeStack[1].type, true, onNodeTypeChanged)
        if nodeStack[1].type == 1 then
            form.addRow(1)
            form.addIntbox(nodeStack[1].const, -32768, 32767, 0, 0, 1, onConstChanged)
        elseif nodeStack[1].type == 2 then
            form.addRow(1)
            form.addSelectbox(sensorLabels, nodeStack[1].sensor + 1, true, onSensorChanged)
        elseif nodeStack[1].type == 3 then
            form.addRow(1)
            form.addSelectbox(inputs, nodeStack[1].input, true, onInputChanged)
        elseif nodeStack[1].type <= twoOpTypes then
            form.addRow(1)
            form.addLink(function () onOperandSelected(1) end, { label = string.format("%s %d", lang.operandText, 1) .. " >>" })
            form.addRow(1)
            form.addLink(function () onOperandSelected(2) end, { label = string.format("%s %d", lang.operandText, 2) .. " >>" })
            form.setButton(2, "P1", ENABLED)
            form.setButton(3, "P2", ENABLED)
        else
            form.addRow(1)
            form.addLink(function () onOperandSelected(1) end, { label = lang.operandText .. " >>" })
            form.setButton(2, "P1", ENABLED)
        end
        if #nodeStack == 1 then
            form.addRow(2)
            form.addLabel({ label = lang.controlText })
            controlSelectIndex = form.addSelectbox(controls, nodeStack[1].control + 1, true, onControlChanged)
        end
        if nodeStack[1].type > 1 then
            form.addSpacer(300, #nodeStack == 1 and 20 or 30)
            form.addRow(2)
            form.addLabel({ label = lang.valueText, width = 80 })
            valueLabelIndex = form.addLabel({ font = FONT_BOLD, alignRight = true, width = 220 })
        else
            valueLabelIndex = nil
        end

        form.setButton(1, ":left", ENABLED)

    elseif formID == 2 then

        form.setTitle(lang.speechLinkText)
        form.addRow(3)
        form.addLabel({ label = lang.intervalText, width = 190 })
        form.addIntbox(interval, 5, 3600, 30, 0, 1, onIntervalChanged, { width = 70 })
        form.addInputbox(intervalSwitch, false, onIntervalSwitchChanged)
        form.addRow(2)
        form.addLabel({ label = lang.singleSwitchText, width = 220 })
        form.addInputbox(singleSwitch, false, onSingleSwitchChanged)
        form.addRow(3)
        form.addLabel({ label = lang.sensorText, font = FONT_BOLD, width = 120 })
        form.addLabel({ label = lang.voiceLabelText, font = FONT_BOLD, width = 110})
        form.addLabel({ label = lang.priorityText, font = FONT_BOLD, alignRight = true, width = 90 })
        for _,sensor in ipairs(sensors) do
            form.addRow(3)
            form.addLabel({ label = sensor.label, width = 140 })
            form.addAudioFilebox(sensor.voiceLabel, function (value) sensor.voiceLabel = value end, { width = 120 })
            form.addIntbox(sensor.prio, 0, MAX_PRIO, 0, 0, 1, function (value) sensor.prio = value end)
        end
        form.setFocusedRow(1)

    else

        form.setTitle(lang.sensorsTitle)
        form.addRow(3)
        form.addLabel({ label = lang.sensorLabelText, font = FONT_BOLD, width = 120 })
        form.addLabel({ label = lang.decimalsText, font = FONT_BOLD, width = 120 })
        form.addLabel({ label = lang.unitText, font = FONT_BOLD, alignRight = true })
        for i,sensor in ipairs(sensors) do
            form.addRow(3)
            form.addTextbox(sensor.label, 10, function (value) onSensorLabelChanged(i, value) end, { width = 180, font = i == activeTelemetryIndex and FONT_BOLD or FONT_NORMAL })
            form.addIntbox(sensor.decimals, 0, 8, 1, 0, 1, function (value) onDecimalsChanged(i, value) end, { width = 60 })
            form.addSelectbox(units, sensor.unit, true, function (value) onSensorUnitChanged(i, value) end)
        end
        form.addLink(function () form.reinit(2) end, { label = lang.speechLinkText .. ">>", font = FONT_BOLD })

        form.setButton(1, ":add", #sensors < 8 and ENABLED or DISABLED)
        form.setButton(2, ":delete", #sensors > 0 and ENABLED or DISABLED)
        form.setButton(3, "Edit", #sensors > 0 and ENABLED or DISABLED)
        form.setButton(4, ":ok", #sensors > 0 and ENABLED or DISABLED)
        valueLabelIndex = nil
    end
    collectgarbage()
end

-- close function registered with the main form
local function close()
    save()
    collectgarbage()
end

local function init()
    collectgarbage()
    activeTelemetryIndex = system.pLoad(activeTelemetryKey)
    singleSwitch = system.pLoad(singleSwitchKey)
    lastSingleSwitchVal = system.getInputsVal(singleSwitch)
    intervalSwitch = system.pLoad(intervalSwitchKey)
    interval = system.pLoad(intervalKey, 30)
    sensorLabels = {"..."}
    sensorIDs = {}
    sensorParams = {}
    for _,sensor in ipairs(system.getSensors()) do
        if sensor.param ~= 0 and sensor.type ~= 5 and sensor.type ~= 9 then
            sensorLabels[#sensorLabels+1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
            sensorIDs[#sensorIDs+1] = sensor.id
            sensorParams[#sensorParams+1] = sensor.param
        end
    end

    local content = io.readall(filepath)
    sensors = (content and json.decode(content) or {}) or {}
    if activeTelemetryIndex and activeTelemetryIndex > #sensors then
        activeTelemetryIndex = nil
    end
    logSensors = {}
    for i,sensor in ipairs(sensors) do
        logSensors[system.registerLogVariable(sensor.label, units[sensor.unit], getLogVariableValue)] = sensor -- save the registered sensor as the value of the returned variable id
        if sensor.control > 0 and (controlRegistered(sensor.control, i - 1) or system.registerControl(sensor.control, sensor.label, controls[sensor.control + 1]) == nil) then
            system.messageBox(string.format(lang.registerErrorText, sensor.control))
            sensor.control = 0 -- control cannot be registered
        end
    end
    nodeTypes = {lang.constantText, lang.sensorText, lang.inputText, "ADD", "SUB", "MUL", "DIV", "MIN", "MAX", "=", "<", ">", "<=", ">=", "AND", "OR", "XOR", "IMPL", "NOT",
            "ABS", "ROUND", "FLOOR", "CEIL", "SQRT", "SIN", "COS", "TAN", "ASIN", "ACOS", "ATAN"}
    system.registerForm(1, MENU_APPS, lang.appName, initForm, onKeyPressed, nil, close)
    system.registerTelemetry(2, lang.appName, 0, printTelemetry)
    collectgarbage()
end

--------------------------------------------------------------------------------
-- the loop updates the value preview of node forms and initiates announcements
--------------------------------------------------------------------------------
local function loop()
    if system.getTimeCounter() >= lastTime + refreshInterval then
        if valueLabelIndex and #nodeStack > 0 then
            form.setProperties(valueLabelIndex, { label = tostring(evaluate(nodeStack[1])) }) -- refresh label of the current form
        end
        lastTime = lastTime + refreshInterval
    end
    local switchVal = system.getInputsVal(singleSwitch)
    if lastSingleSwitchVal ~= 1 and switchVal == 1 then
        voiceAnnouncement() -- single voice announcement
    end
    lastSingleSwitchVal = switchVal
    if system.getInputsVal(intervalSwitch) == 1 then
        if lastAnnouncement and system.getTimeCounter() >= lastAnnouncement + 1000 * interval then
            voiceAnnouncement()
            lastAnnouncement = lastAnnouncement + 1000 * interval
        elseif not lastAnnouncement then
            lastAnnouncement = system.getTimeCounter()
        end
    else
        lastAnnouncement = nil
    end
    for _,sensor in pairs(sensors) do
        if sensor.control > 0 and system.setControl(sensor.control, evaluate(sensor) or 0, 0) == nil then
            system.unregisterControl(sensor.control)
            system.messageBox(string.format(lang.registerErrorText, sensor.control))
            sensor.control = 0
        end
    end
    collectgarbage()
end

local function destroy()
    for id,_ in pairs(logSensors) do
        system.unregisterLogVariable(id) -- unregister all log variables
    end
    for _,sensor in pairs(sensors) do
        if sensor.control > 0 then
            system.unregisterControl(sensor.control) -- unregister all virtual controls
        end
    end
    if sensors then
        save()
        sensors = nil
    end
    collectgarbage()
end

local text = json.decode(io.readall("Apps/VirtualSensor/lang.json"))
lang = text[system.getLocale()] or text["en"]
collectgarbage()
return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.21", name = lang.appName }