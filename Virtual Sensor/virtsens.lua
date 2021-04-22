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
local units = {"", "Wmi", "F", "°C", "°", "W", "s", "min", "h", "mAh", "Ah", "A", "V", "%", "hPa", "kPa", "psi", "atm", "b", "m/s", "km/h", "kt.", "mph",
                "m", "ft", "km", "mi.", "yd.", "ml", "l", "hl", "floz", "gal", "ml/m", "l/m", "oz/m", "gpm"}
local inputs = {"...", "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10",
                "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SP",
                "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10", "T11", "T12", "T13", "T14", "T15", "T16",
                "CH1", "CH2", "CH3", "CH4", "CH5", "CH6", "CH7", "CH8",
                "O1", "O2", "O3", "O4", "O5", "O6", "O7", "O8", "O9", "O10", "O11", "O12", "O13", "O14", "O15", "O16", "O17", "O18", "O19", "O20", "O21", "O22", "O23", "O24"}
local specialTypes = 3
local twoOpTypes = 9
local refreshInterval = 500
local lastTime = system.getTimeCounter()
local activeTelemetryKey = "vs_acttel"

local sensors
local nodeStack = {}
local valueLabelIndex
local activeTelemetryIndex

local sensorIDs
local sensorParams
local sensorLabels
local logVariableIDs -- Saves the log variable id for all sensor labels that existed at app initialization as a mapping label -> id.
                     -- This approach is required to keep track of all log variables when sensors are deleted and the sensor with a requested log id has to be evaluated.

-- translations
local locale = system.getLocale()
local appName = {en = "Virtual Sensor", de = "Virtueller Sensor", cz = "Virtuální senzor"}
local sensorsTitle = {en = "Sensors", de = "Sensoren", cz = "Senzory"}
local sensorLabelText = {en = "Sensor label", de = "Bezeichner", cz = "název"}
local decimalsText = {en = "Decimals", de = "Dezimalstellen", cz = "Desetinná místa"}
local unitText = {en = "Unit", de = "Einheit", cz = "Jednotka měření"}
local fileInexistentText = {en = "Sensors could not be saved", de = "Speichern fehlgeschlagen", cz = "Uložení se nezdařilo"}
local constantText = {en = "constant", de = "konstant", cz = "konstantní"}
local sensorText = {en = "sensor", de = "Sensor", cz = "senzor"}
local operandText = {en = "Parameter", de = "Parameter", cz = "parametr"}
local inputText = {en = "input", de = "Eingabe", cz = "vstup"}
local valueText = {en = "Value", de = "Wert", cz = "hodnota"}
local levelText = {en = "level", de = "Ebene", cz = "úroveň"}

local function getTranslation(table)
    return table[locale] or table["en"]
end

-- type:           1                             2                           3                           4      5      6      7      8      9      10     11       12       13      14      15     16     17      18     19      20
local nodeTypes = {getTranslation(constantText), getTranslation(sensorText), getTranslation(inputText), "ADD", "SUB", "MUL", "DIV", "MIN", "MAX", "ABS", "ROUND", "FLOOR", "CEIL", "SQRT", "SIN", "COS", "TAN", "ASIN", "ACOS", "ATAN"}

-------------------
-- callback methods
-------------------
local function onSensorLabelChanged(index, value)
    sensors[index]["label"] = value
end

local function onDecimalsChanged(index, value)
    sensors[index]["decimals"] = value
end

local function onSensorUnitChanged(index, value)
    sensors[index]["unit"] = value
end

----------------------------------------------------------------------------------
-- Changes the type of the current node. All properties are set to default values.
----------------------------------------------------------------------------------
local function onNodeTypeChanged(value)
    if nodeStack[1]["type"] ~= value then
        local node = nodeStack[1]
        node["type"] = value
        node["const"] = nil -- delete old attributes
        node["sensor"] = nil
        node["input"] = nil
        node["p1"] = nil
        node["p2"] = nil
        if value == 1 then -- add new default values dependent on type
            node["const"] = 0
        elseif value == 2 then
            node["sensor"] = 0
        elseif value == 3 then
            node["input"] = 1
        else
            if value <= twoOpTypes then
                node["p2"] = {type = 1, const = 0}
            end
            node["p1"] = {type = 1, const = 0}
        end
        form.reinit()
        collectgarbage()
    end
end

local function onConstChanged(value)
    nodeStack[1]["const"] = value
end

local function onSensorChanged(value)
    nodeStack[1]["sensor"] = value - 1
end

local function onInputChanged(value)
    nodeStack[1]["input"] = value
end

local function onOperandSelected(opNum)
    table.insert(nodeStack, 1, opNum == 1 and nodeStack[1]["p1"] or nodeStack[1]["p2"])
    form.reinit()
end

-------------------------------------------------------------------------
-- saves the 'sensors' table in json format
-------------------------------------------------------------------------
local function save()
    if sensors then
        local file = io.open(filepath, "w")
        if file then
            if not io.write(file, json.encode(sensors)) then
                system.messageBox(getTranslation(fileInexistentText))
            end
            io.close(file)
        else
            system.messageBox(getTranslation(fileInexistentText))
        end
    end
end

-- close function registered with the main form
local function close()
    save()
    collectgarbage()
end

-------------------------------------------------------------------------
-- recursively evaluates the specified node, according to it's type
-------------------------------------------------------------------------
local function evaluate(node)
    local type = node["type"]
    if not node then
        return nil
    elseif type == 1 then -- CONST
        return node["const"]
    elseif type == 2 then -- SENSOR
        local id,param = sensorIDs[node["sensor"]], sensorParams[node["sensor"]]
        if id and param then
            local val = system.getSensorValueByID(id, param)
            return (val and val.valid) and val.value or nil
        else
            return nil
        end
    elseif type == 3 then -- INPUT
        return node["input"] ~= 1 and system.getInputs(inputs[node["input"]]) or nil
    elseif type <= twoOpTypes then
        local firstVal = evaluate(node["p1"])
        local secondVal = evaluate(node["p2"])
        if type == 4 then     -- ADD
            return (firstVal and secondVal) and (firstVal + secondVal) or nil
        elseif type == 5 then -- SUB
            return (firstVal and secondVal) and (firstVal - secondVal) or nil
        elseif type == 6 then -- MUL
            return (firstVal and secondVal) and (firstVal * secondVal) or nil
        elseif type == 7 then -- DIV
            return (firstVal and secondVal and secondVal ~= 0.0) and (firstVal / secondVal) or nil
        elseif type == 8 then -- MIN
            if firstVal then
                return secondVal and math.min(firstVal, secondVal) or firstVal
            else
                return secondVal
            end
        else -- MAX (9)
            if firstVal then
                return secondVal and math.max(firstVal, secondVal) or firstVal
            else
                return secondVal
            end
        end
    else
        local val = evaluate(node["p1"])
        if type == 10 then     -- ABS
            return val and math.abs(val) or nil
        elseif type == 11 then -- ROUND
            return val and math.floor(val + 0.5) or nil
        elseif type == 12 then -- FLOOR
            return val and math.floor(val) or nil
        elseif type == 13 then -- CEIL
            return val and math.ceil(val) or nil
        elseif type == 14 then -- ROOT
            return (val and val >= 0) and math.sqrt(val) or nil
        elseif type == 15 then -- SIN
            return val and math.sin(math.rad(val)) or nil
        elseif type == 16 then -- COS
            return val and math.cos(math.rad(val)) or nil
        elseif type == 17 then -- TAN
            return val and math.tan(math.rad(val)) or nil
        elseif type == 18 then -- ASIN
            return val and math.deg(math.asin(val)) or nil
        elseif type == 19 then -- ACOS
            return val and math.deg(math.acos(val)) or nil
        else                   -- ATAN (20)
            return val and math.deg(math.atan(val)) or nil
        end
    end
end

local function onKeyPressed(keyCode)
    if #nodeStack > 0 then
        form.preventDefault()
        if keyCode == KEY_ESC or keyCode == KEY_5 then
            nodeStack = {}
            form.reinit()
        elseif keyCode == KEY_1 then
            table.remove(nodeStack, 1)
            form.reinit()
        elseif keyCode == KEY_2 and nodeStack[1]["type"] > specialTypes then
            onOperandSelected(1)
        elseif keyCode == KEY_3 and nodeStack[1]["type"] > specialTypes and nodeStack[1]["type"] <= twoOpTypes then
            onOperandSelected(2)
        end
    else
        local focused = form.getFocusedRow() - 1
        if keyCode == KEY_1 and #sensors < 8 then

            local defaultSensor = {label = "virtual sensor " .. tostring(#sensors + 1), unit = 1, decimals = 1, type = 1, const = 0}
            table.insert(sensors, defaultSensor)
            form.reinit()

        elseif keyCode == KEY_2 and #sensors > 0 and focused > 0 then

            table.remove(sensors, focused)
            if activeTelemetryIndex then
                if activeTelemetryIndex == focused then
                    activeTelemetryIndex = nil
                    system.pSave(activeTelemetryKey, activeTelemetryIndex)
                elseif activeTelemetryIndex > focused then
                    activeTelemetryIndex = activeTelemetryIndex - 1
                    system.pSave(activeTelemetryKey, activeTelemetryIndex)
                end
            end
            form.reinit()

        elseif keyCode == KEY_3 and #sensors > 0 and focused > 0 then

            table.insert(nodeStack, sensors[focused])
            form.reinit()

        elseif keyCode == KEY_4 and #sensors > 0 and focused > 0 then

            activeTelemetryIndex = focused
            system.pSave(activeTelemetryKey, activeTelemetryIndex)
            form.reinit()

        end
    end
end

--------------------------------------------------------------------------------------------------------
-- Request method for log variables. Evaluates the sensor whose label is mapped to the requested log id.
--------------------------------------------------------------------------------------------------------
local function getLogVariableValue(logVariableID)
    for _,sensor in pairs(sensors) do
        if logVariableIDs[sensor["label"]] == logVariableID then -- if the log variable id registered for the current sensor is equal to the requested id
            -- calculate value
            local value = evaluate(sensor)
            if value then
                return math.floor(value * 10^sensor["decimals"]), sensor["decimals"]
            else
                return nil,0
            end
        end
    end
    return nil,0
end

---------------------------------------------------------------------------------------------------
-- prints the current value of the selected virtual sensor, correspondent to the amount of decimals
---------------------------------------------------------------------------------------------------
local function printTelemetry(width, height)
    if activeTelemetryIndex then
        local font = height > 30 and FONT_MAXI or FONT_BOLD
        local val = evaluate(sensors[activeTelemetryIndex])
        local text = val and string.format("%." .. string.format("%d", sensors[activeTelemetryIndex]["decimals"]) .. "f %s", val, units[sensors[activeTelemetryIndex]["unit"]]) or "-"
        lcd.drawText(width - 10 - lcd.getTextWidth(font, text), (height - lcd.getTextHeight(font)) / 2, text, font)
    end
end

local function initForm()
    if #nodeStack > 0 then
        form.setTitle(string.format("%s - %s %d", nodeStack[#nodeStack]["label"], getTranslation(levelText), #nodeStack))
        form.addRow(1)
        form.addSelectbox(nodeTypes, nodeStack[1]["type"], true, onNodeTypeChanged)
        if nodeStack[1]["type"] == 1 then
            form.addRow(1)
            form.addIntbox(nodeStack[1]["const"], -32768, 32767, 0, 0, 1, onConstChanged)
        elseif nodeStack[1]["type"] == 2 then
            form.addRow(1)
            form.addSelectbox(sensorLabels, nodeStack[1]["sensor"] + 1, true, onSensorChanged)
        elseif nodeStack[1]["type"] == 3 then
            form.addRow(1)
            form.addSelectbox(inputs, nodeStack[1]["input"], true, onInputChanged)
        elseif nodeStack[1]["type"] <=twoOpTypes then
            form.addRow(1)
            form.addLink(function () onOperandSelected(1) end, { label = string.format("%s %d", getTranslation(operandText), 1) .. " >>" })
            form.addRow(1)
            form.addLink(function () onOperandSelected(2) end, { label = string.format("%s %d", getTranslation(operandText), 2) .. " >>" })
            form.setButton(2, "P1", ENABLED)
            form.setButton(3, "P2", ENABLED)
        else
            form.addRow(1)
            form.addLink(function () onOperandSelected(1) end, { label = getTranslation(operandText) .. " >>" })
            form.setButton(2, "P1", ENABLED)
        end
        if nodeStack[1]["type"] > 1 then
            form.addSpacer(300, 30)
            form.addRow(2)
            form.addLabel({ label = getTranslation(valueText), width = 80 })
            valueLabelIndex = form.addLabel({ font = FONT_BOLD, alignRight = true, width = 220 })
        else
            valueLabelIndex = nil
        end

        form.setButton(1, ":left", ENABLED)
    else
        form.setTitle(getTranslation(sensorsTitle))
        form.addRow(3)
        form.addLabel({ label = getTranslation(sensorLabelText), font = FONT_BOLD, width = 120 })
        form.addLabel({ label = getTranslation(decimalsText), font = FONT_BOLD, width = 120 })
        form.addLabel({ label = getTranslation(unitText), font = FONT_BOLD, alignRight = true })
        for i,sensor in ipairs(sensors) do
            form.addRow(3)
            form.addTextbox(sensor["label"], 16, function (value) onSensorLabelChanged(i, value) end, {width = 180, font = i == activeTelemetryIndex and FONT_BOLD or FONT_NORMAL})
            form.addIntbox(sensor["decimals"], 0, 8, 1, 0, 1, function (value) onDecimalsChanged(i, value) end, {width = 60})
            form.addSelectbox(units, sensor.unit, true, function (value) onSensorUnitChanged(i, value) end)
        end

        form.setButton(1, ":add", #sensors < 9 and ENABLED or DISABLED)
        form.setButton(2, ":delete", #sensors > 0 and ENABLED or DISABLED)
        form.setButton(3, "Edit", #sensors > 0 and ENABLED or DISABLED)
        form.setButton(4, ":ok", #sensors > 0 and ENABLED or DISABLED)
        valueLabelIndex = nil
    end
end

local function init()
    activeTelemetryIndex = system.pLoad(activeTelemetryKey)
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
    logVariableIDs = {}
    for _,sensor in pairs(sensors) do
        logVariableIDs[sensor["label"]] = system.registerLogVariable(sensor["label"], units[sensor["unit"]], getLogVariableValue)
    end
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm, onKeyPressed, nil, close)
    system.registerTelemetry(2, getTranslation(appName), 0, printTelemetry)
    system.registerTelemetry(3, getTranslation(appName) .. " 2", 0, printTelemetry)
end

-------------------------------------------------------------------------
-- the loop updates the value preview of node forms
-------------------------------------------------------------------------
local function loop()
    local time = system.getTimeCounter()
    if time >= lastTime + refreshInterval then
        if valueLabelIndex and #nodeStack > 0 then
            form.setProperties(valueLabelIndex, { label = tostring(evaluate(nodeStack[1])) })
        end
        lastTime = lastTime + refreshInterval
    end
end

local function destroy()
    for _,id in pairs(logVariableIDs) do
        system.unregisterLogVariable(id)
    end
    if sensors then
        save()
        sensors = nil
    end
    collectgarbage()
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.0", name = getTranslation(appName) }