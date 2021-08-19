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

local units = {"", "m", "km", "s", "min", "h", "m/s", "km/h", "V", "A", "mAh", "Ah", "W", "Wmi", "°C", "°", "%", "l", "ml", "hl", "l/m", "ml/m", "hPa", "kPa", "b",
                "ft", "mi.", "yd.", "ft/s", "mph", "kt.", "F", "psi", "atm", "floz", "gal", "oz/m", "gpm"}

local inputs = {"...", "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10", "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SP"}
local controls = {"...", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10"}
local specialTypes = 3
local twoOpTypes = 18

local sensors
local nodeStack = {}
local evalFunctions
local valueLabelIndex
local controlSelectIndex
local activeTelemetryIndex
local integralResetSwitch
local lastTime

local sensorIDs = {}
local sensorParams = {}
local sensorLabels = {"..."}

local lang = json.decode(io.readall("Apps/VirtualSensor/lang.jsn"))
lang = lang[system.getLocale()] or lang["en"]

local nodeTypes = {lang.constantText, lang.sensorText, lang.inputText, "ADD", "SUB", "MUL", "DIV", "MIN", "MAX", "=", "<", ">", "<=", ">=", "AND", "OR", "XOR", "IMPL", "NOT",
"ABS", "ROUND", "FLOOR", "CEIL", "SQRT", "SIN", "COS", "TAN", "ASIN", "ACOS", "ATAN", "Integral"}

local function toNumber(boolean)
    return boolean and 1 or 0
end

local function controlRegistered(controlNo, limit)
    limit = limit or #sensors
    for i = 1, limit do
        if sensors[i].control == controlNo then
            return true
        end
    end
    return false
end

local function onIntegralResetChanged(value)
    integralResetSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave("int_reset", integralResetSwitch)
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

local function onNodeTypeChanged(value)
    if nodeStack[1].type ~= value then
        local node = nodeStack[1]
        node.type = value
        node.const = nil
        node.sensor = nil
        node.input = nil
        node.integral = nil
        if value <= specialTypes then
            node.p1 = nil
            node.p2 = nil
            if value == 1 then
                node.const = 0
            elseif value == 2 then
                node.sensor = 0
            elseif value == 3 then
                node.input = 1
            end
        else
            if value <= twoOpTypes then
                node.p2 = node.p2 or {type = 1, const = 0}
            else
                node.p2 = nil
            end
            node.p1 = node.p1 or {type = 1, const = 0}
            if value == #nodeTypes then
                node.integral = 0
            end
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

local function onControlChanged(value)
    if value ~= nodeStack[1].control + 1 then
        if value == 1 then
            system.unregisterControl(nodeStack[1].control)
            nodeStack[1].control = 0
        else
            if nodeStack[1].control > 0 then
                system.unregisterControl(nodeStack[1].control)
            end
            if (not controlRegistered(value - 1)) and system.registerControl(value - 1, nodeStack[1].label, controls[value]) ~= nil then
                nodeStack[1].control = value - 1
            else
                nodeStack[1].control = 0
                form.setValue(controlSelectIndex, 1)
                system.messageBox(string.format(lang.registerErrorText, value - 1))
            end
        end
    end
end

local function save()
    if sensors then
        local file = io.open("Apps/VirtualSensor/sensors.json", "w")
        if file then
            if not io.write(file, json.encode(sensors)) then
                system.messageBox(lang.fileInexistentText)
            end
            io.close(file)
        else
            system.messageBox(lang.fileInexistentText)
        end
    end
end

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
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and (firstVal + secondVal) or nil
    end,
    function(node) -- SUB
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and (firstVal - secondVal) or nil
    end,
    function(node) -- MUL
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and (firstVal * secondVal) or nil
    end,
    function(node) -- DIV
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal and secondVal ~= 0.0) and (firstVal / secondVal) or nil
    end,
    function(node) -- MIN
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        if firstVal then
            return secondVal and math.min(firstVal, secondVal) or firstVal
        else
            return secondVal
        end
    end,
    function(node) -- MAX
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        if firstVal then
            return secondVal and math.max(firstVal, secondVal) or firstVal
        else
            return secondVal
        end
    end,
    function(node) -- =
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber(firstVal == secondVal) or nil
    end,
    function(node) -- <
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber(firstVal < secondVal) or nil
    end,
    function(node) -- >
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber(firstVal > secondVal) or nil
    end,
    function(node) -- <=
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber(firstVal <= secondVal) or nil
    end,
    function(node) -- >=
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber(firstVal >= secondVal) or nil
    end,
    function(node) -- AND
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber(firstVal >= 1 and secondVal >= 1) or nil
    end,
    function(node) -- OR
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber(firstVal >=1 or secondVal >= 1) or nil
    end,
    function(node) -- XOR
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber((firstVal >= 1) ~= (secondVal >= 1)) or nil
    end,
    function(node) -- IMPL
        local firstVal = evalFunctions[node.p1.type](node.p1)
        local secondVal = evalFunctions[node.p2.type](node.p2)
        return (firstVal and secondVal) and toNumber(firstVal < 1 or secondVal >= 1) or nil
    end,
    function(node) -- NOT
        local val = evalFunctions[node.p1.type](node.p1)
        return val and toNumber(val < 1) or nil
    end,
    function(node) -- ABS
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.abs(val) or nil
    end,
    function(node) -- ROUND
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.floor(val + 0.5) or nil
    end,
    function(node) -- FLOOR
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.floor(val) or nil
    end,
    function(node) -- CEIL
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.ceil(val) or nil
    end,
    function(node) --ROOT
        local val = evalFunctions[node.p1.type](node.p1)
        return (val and val >= 0) and math.sqrt(val) or nil
    end,
    function(node) -- SIN
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.sin(math.rad(val)) or nil
    end,
    function(node) -- COS
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.cos(math.rad(val)) or nil
    end,
    function(node) -- TAN
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.tan(math.rad(val)) or nil
    end,
    function(node) -- ASIN
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.deg(math.asin(val)) or nil
    end,
    function(node) -- ACOS
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.deg(math.acos(val)) or nil
    end,
    function(node) -- ATAN
        local val = evalFunctions[node.p1.type](node.p1)
        return val and math.deg(math.atan(val)) or nil
    end,
    function(node) -- Integral
        return node.integral
    end
}

local function onKeyPressed(keyCode)
    if #nodeStack > 0 then
        form.preventDefault()
        if keyCode == KEY_ESC or keyCode == KEY_5 then
            nodeStack = {}
            form.reinit()
        elseif keyCode == KEY_1 then
            table.remove(nodeStack, 1)
            form.reinit()
        elseif keyCode == KEY_2 and nodeStack[1].type > specialTypes then
            onOperandSelected(1)
        elseif keyCode == KEY_3 and nodeStack[1].type > specialTypes and nodeStack[1].type <= twoOpTypes then
            onOperandSelected(2)
        end
    else
        local focused = form.getFocusedRow() - 1
        if keyCode == KEY_1 and #sensors < 8 then

            local defaultSensor = { label = "vsensor " .. tostring(#sensors + 1), unit = 1, decimals = 1, type = 1, const = 0, control = 0 }
            table.insert(sensors, defaultSensor)
            form.reinit()

        elseif keyCode == KEY_2 and focused > 0 and focused <= #sensors then

            if sensors[focused].control > 0 then
                system.unregisterControl(sensors[focused].control)
            end
            table.remove(sensors, focused)
            if activeTelemetryIndex then
                if activeTelemetryIndex == focused then
                    activeTelemetryIndex = nil
                    system.pSave("vs_acttel", activeTelemetryIndex)
                elseif activeTelemetryIndex > focused then
                    activeTelemetryIndex = activeTelemetryIndex - 1
                    system.pSave("vs_acttel", activeTelemetryIndex)
                end
            end
            form.reinit()

        elseif keyCode == KEY_3 and #sensors > 0 and focused > 0 and focused <= #sensors then

            table.insert(nodeStack, sensors[focused])
            form.reinit()

        elseif keyCode == KEY_4 and #sensors > 0 and focused > 0 and focused <= #sensors then

            activeTelemetryIndex = focused
            system.pSave("vs_acttel", activeTelemetryIndex)
            form.reinit()

        end
    end
    collectgarbage()
end

local function printTelemetry(width, height)
    if activeTelemetryIndex then
        local font = height > 30 and FONT_MAXI or FONT_BOLD
        local val = evalFunctions[sensors[activeTelemetryIndex].type](sensors[activeTelemetryIndex])
        local text = val and string.format("%." .. string.format("%d", sensors[activeTelemetryIndex].decimals) .. "f %s", val, units[sensors[activeTelemetryIndex].unit]) or "-"
        lcd.drawText(width - 10 - lcd.getTextWidth(font, text), (height - lcd.getTextHeight(font)) / 2, text, font)
    end
end

local function initForm()
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
        form.addSpacer(0, 20)
        form.addRow(2)
        form.addLabel({ label = lang.integralResetSwitch, width = 220 })
        form.addInputbox(integralResetSwitch, false, onIntegralResetChanged)
        form.setButton(1, ":add", #sensors < 8 and ENABLED or DISABLED)
        form.setButton(2, ":delete", #sensors > 0 and ENABLED or DISABLED)
        form.setButton(3, "Edit", #sensors > 0 and ENABLED or DISABLED)
        form.setButton(4, ":ok", #sensors > 0 and ENABLED or DISABLED)
        valueLabelIndex = nil
    end
    collectgarbage()
end

local function close()
    save()
    collectgarbage()
end

local function updateIntegrals(node, dt)
    if node.type > specialTypes then
        updateIntegrals(node.p1, dt)
        if node.type <= twoOpTypes then
            updateIntegrals(node.p2, dt)
        end
        if node.type == #nodeTypes then
            local p1 = evalFunctions[node.p1.type](node.p1)
            node.integral = node.integral + (p1 and (dt * p1 * 0.001) or 0)
        end
    end
end

local function resetIntegrals(node)
    if node.type > specialTypes then
        resetIntegrals(node.p1)
        if node.type <= twoOpTypes then
            resetIntegrals(node.p2)
        end
        if node.type == #nodeTypes then
            node.integral = 0
        end
    end
end

local function init()
    collectgarbage()
    local telSensors = system.getSensors()
    for _,sensor in ipairs(telSensors) do
        if sensor.param ~= 0 and sensor.type ~= 5 and sensor.type ~= 9 then
            sensorLabels[#sensorLabels+1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
            sensorIDs[#sensorIDs+1] = sensor.id
            sensorParams[#sensorParams+1] = sensor.param
        end
        collectgarbage()
    end

    activeTelemetryIndex = system.pLoad("vs_acttel")
    integralResetSwitch = system.pLoad("int_reset")

    local content = io.readall("Apps/VirtualSensor/sensors.json")
    sensors = (content and json.decode(content) or {}) or {}
    if activeTelemetryIndex and activeTelemetryIndex > #sensors then
        activeTelemetryIndex = nil
    end

    for i,sensor in ipairs(sensors) do
        resetIntegrals(sensor)
        if sensor.control > 0 and (controlRegistered(sensor.control, i - 1) or system.registerControl(sensor.control, sensor.label, controls[sensor.control + 1]) == nil) then
            system.messageBox(string.format(lang.registerErrorText, sensor.control))
            sensor.control = 0
        end
    end
    system.registerForm(1, MENU_APPS, lang.appName, initForm, onKeyPressed, nil, close)
    system.registerTelemetry(2, lang.appName, 0, printTelemetry)
    lastTime = system.getTimeCounter()
    collectgarbage()
end

local function loop()
    local time = system.getTimeCounter()
    if valueLabelIndex and #nodeStack > 0 then
        form.setProperties(valueLabelIndex, { label = tostring(evalFunctions[nodeStack[1].type](nodeStack[1])) })
    end
    for _,sensor in pairs(sensors) do
        updateIntegrals(sensor, time - lastTime)
        if sensor.control > 0 and system.setControl(sensor.control, evalFunctions[sensor.type](sensor) or 0, 0) == nil then
            system.unregisterControl(sensor.control)
            system.messageBox(string.format(lang.registerErrorText, sensor.control))
            sensor.control = 0
        end
    end
    if system.getInputsVal(integralResetSwitch) == 1 then
        for _,sensor in pairs(sensors) do
            resetIntegrals(sensor)
        end
    end
    lastTime = time
    collectgarbage()
end

local function destroy()
    for _,sensor in pairs(sensors) do
        if sensor.control > 0 then
            system.unregisterControl(sensor.control)
        end
    end
    if sensors then
        save()
        sensors = nil
    end
    collectgarbage()
end

collectgarbage()
return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.3.0", name = lang.appName }