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

local sensors
local sensorIndex
local controlSelectIndex
local integralResetSwitch
local lastTime

local sensorIDs = {}
local sensorParams = {}
local sensorLabels = {"..."}

local lang = json.decode(io.readall("Apps/VirtualSensor/lang.jsn"))
lang = lang[system.getLocale()] or lang["en"]

local nodeTypes = {lang.constant, lang.sensor, lang.input, "ADD", "SUB", "MUL", "DIV", "MIN/AND", "MAX/OR", "=", "<", ">", "ABS", "FLOOR", "SQRT", "Integral"}
local specialTypes = 3
local twoOpTypes = 12

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

local function onTypeChanged(value)
    if sensors[sensorIndex].type ~= value then
        local sensor = sensors[sensorIndex]
        sensor.type = value
        sensor.value = 0
        sensor.sensor = nil
        sensor.input = nil
        if value <= specialTypes then
            sensor.p1 = nil
            sensor.p2 = nil
            if value == 2 then
                sensor.sensor = 0
            elseif value == 3 then
                sensor.input = 1
            end
        else
            if value <= twoOpTypes then
                sensor.p2 = sensor.p2 or 0
            else
                sensor.p2 = nil
            end
            sensor.p1 = sensor.p1 or 0
        end
        form.reinit()
        collectgarbage()
    end
end

local function onControlChanged(value)
    if value ~= sensors[sensorIndex].control + 1 then
        if value == 1 then
            system.unregisterControl(sensors[sensorIndex].control)
            sensors[sensorIndex].control = 0
        else
            if sensors[sensorIndex].control > 0 then
                system.unregisterControl(sensors[sensorIndex].control)
            end
            if (not controlRegistered(value - 1)) and system.registerControl(value - 1, sensors[sensorIndex].label, controls[value]) ~= nil then
                sensors[sensorIndex].control = value - 1
            else
                sensors[sensorIndex].control = 0
                form.setValue(controlSelectIndex, 1)
                system.messageBox(string.format(lang.registerError, value - 1))
            end
        end
    end
end

local function save()
    if sensors then
        local file = io.open("Apps/VirtualSensor/sensors.json", "w")
        if file then
            if not io.write(file, json.encode(sensors)) then
                system.messageBox(lang.fileInexistent)
            end
            io.close(file)
        else
            system.messageBox(lang.fileInexistent)
        end
    end
end

local function onKeyPressed(keyCode)
    if not sensorIndex then
        local focused = form.getFocusedRow()
        if keyCode == KEY_1 and #sensors < 8 then

            table.insert(sensors, { label = "vsensor " .. tostring(#sensors + 1), type = 1, unit = 1, decimals = 1, value = 0, control = 0, tel = false })
            form.reinit()

        elseif keyCode == KEY_2 and focused > 0 and focused <= #sensors then

            if sensors[focused].control > 0 then
                system.unregisterControl(sensors[focused].control)
            end
            for _,sensor in pairs(sensors) do
                if sensor.p1 and sensor.p1 == focused then
                    sensor.p1 = 0
                elseif sensor.p1 and sensor.p1 > focused then
                    sensor.p1 = sensor.p1 - 1
                end
                if sensor.p2 and sensor.p2 == focused then
                    sensor.p2 = 0
                elseif sensor.p2 and sensor.p2 > focused then
                    sensor.p2 = sensor.p2 - 1
                end
            end
            table.remove(sensors, focused)
            form.reinit()

        elseif keyCode == KEY_3 and focused > 0 and focused <= #sensors then

            sensors[focused].tel = not sensors[focused].tel
            form.reinit()

        end
    elseif keyCode == KEY_5 or keyCode == KEY_ESC then
        form.preventDefault()
        sensorIndex = nil
        form.reinit()
    end
    collectgarbage()
end

local function printTelemetry(width, height)
    if width < 160 then
        for i = 1, #sensors do
            if sensors[i].tel then
                local font = height > 30 and FONT_MAXI or FONT_BOLD
                local text = sensors[i].value and string.format("%." .. string.format("%d", sensors[i].decimals) .. "f %s", sensors[i].value, units[sensors[i].unit]) or "-"
                lcd.drawText(width - 10 - lcd.getTextWidth(font, text), (height - lcd.getTextHeight(font)) // 2, text, font)
                return
            end
        end
    else
        local count = 0
        for i = 1, #sensors do
            if sensors[i].tel and count < 6 then
                local text = sensors[i].value and string.format("%." .. string.format("%d", sensors[i].decimals) .. "f %s", sensors[i].value, units[sensors[i].unit]) or "-"
                local x = (count < 3 and width or width // 2) - 10
                local y = 51 * (count % 3) + 5
                local font = lcd.getTextWidth(FONT_MAXI, text) > width // 2 - 10 and FONT_BIG or FONT_MAXI
                lcd.drawText(x - lcd.getTextWidth(font, text), y + 8, text, font)
                lcd.drawText(x - lcd.getTextWidth(FONT_MINI, sensors[i].label), y, sensors[i].label, FONT_MINI)

                count = count + 1
            end
        end
    end
end

local function initForm()
    if sensorIndex then

        local sensor = sensors[sensorIndex]
        form.setTitle(sensor.label)
        form.addRow(2)
        form.addLabel({ label = lang.type })
        form.addSelectbox(nodeTypes, sensor.type, true, onTypeChanged)
        if sensor.type == 1 then
            form.addRow(1)
            form.addIntbox(sensor.value, -32768, 32767, 0, 0, 1, function (value) sensor.value = value end)
        elseif sensor.type == 2 then
            form.addRow(1)
            form.addSelectbox(sensorLabels, sensor.sensor + 1, true, function (value) sensor.sensor = value - 1 end)
        elseif sensor.type == 3 then
            form.addRow(1)
            form.addSelectbox(inputs, sensor.input, true, function (value) sensor.input = value end)
        else
            local virtualSensorLabels = {"..."}
            for i = 1, #sensors do
                virtualSensorLabels[#virtualSensorLabels+1] = sensors[i].label
            end
            if sensor.type <= twoOpTypes then
                form.addRow(2)
                form.addLabel({ label = lang.operand .. " 1" })
                form.addSelectbox(virtualSensorLabels, sensor.p1 + 1, true, function (value) sensor.p1 = value - 1 end)
                form.addRow(2)
                form.addLabel({ label = lang.operand .. " 2" })
                form.addSelectbox(virtualSensorLabels, sensor.p2 + 1, true, function (value) sensor.p2 = value - 1 end)
            else
                form.addRow(2)
                form.addLabel({ label = lang.operand })
                form.addSelectbox(virtualSensorLabels, sensor.p1 + 1, true, function (value) sensor.p1 = value - 1 end)
            end
        end
        form.addSpacer(0, 15)
        form.addRow(2)
        form.addLabel({ label = lang.sensorLabel, font = FONT_BOLD })
        form.addTextbox(sensor.label, 20, function (value)
            sensor.label = value
            form.setTitle(sensor.label)
        end, { font = FONT_BOLD })
        form.addRow(2)
        form.addLabel({ label = lang.unit })
        form.addSelectbox(units, sensor.unit, true, function (value) sensor.unit = value end)
        form.addRow(2)
        form.addLabel({ label = lang.decimals })
        form.addIntbox(sensor.decimals, 0, 8, 1, 0, 1, function (value) sensor.decimals = value end)
        form.addRow(2)
        form.addLabel({ label = lang.control })
        controlSelectIndex = form.addSelectbox(controls, sensor.control + 1, true, onControlChanged)
        form.setFocusedRow(1)

    else

        form.setTitle(lang.sensorsTitle)
        for i = 1, #sensors do
            form.addRow(1)
            form.addLink(function ()
                sensorIndex = i
                form.reinit()
            end, { label = sensors[i].label .. " >>", font = sensors[i].tel and FONT_BOLD or FONT_NORMAL })
        end
        form.addSpacer(0, 20)
        form.addRow(2)
        form.addLabel({ label = lang.integralResetSwitch, width = 220 })
        form.addInputbox(integralResetSwitch, false, onIntegralResetChanged)
        form.setButton(1, ":add", #sensors < 16 and ENABLED or DISABLED)
        form.setButton(2, ":delete", #sensors > 0 and ENABLED or DISABLED)
        form.setButton(3, ":graphBig", #sensors > 0 and ENABLED or DISABLED)
    end
    collectgarbage()
end

local function close()
    save()
    collectgarbage()
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

    integralResetSwitch = system.pLoad("int_reset")

    sensors = io.readall("Apps/VirtualSensor/sensors.json")
    sensors = (sensors and json.decode(sensors) or {}) or {}

    local telCount = 0
    for i,sensor in ipairs(sensors) do
        if sensor.type ~= 1 then sensor.value = 0 end
        if sensor.control > 0 and (controlRegistered(sensor.control, i - 1) or system.registerControl(sensor.control, sensor.label, controls[sensor.control + 1]) == nil) then
            system.messageBox(string.format(lang.registerError, sensor.control))
            sensor.control = 0
        end
        if sensor.tel then
            telCount = telCount + 1
        end
    end
    system.registerForm(1, MENU_APPS, lang.appName, initForm, onKeyPressed, nil, close)
    system.registerTelemetry(1, lang.appName, telCount > 1 and 4 or 0, printTelemetry)
    lastTime = system.getTimeCounter()
    collectgarbage()
end

local function loop()
    local time = system.getTimeCounter()

    for _,sensor in ipairs(sensors) do
        if sensor.type == 2 then
            local id,param = sensorIDs[sensor.sensor], sensorParams[sensor.sensor]
            if id and param then
                local val = system.getSensorValueByID(id, param)
                sensor.value = (val and val.valid) and val.value or nil
            else
                sensor.value = nil
            end
        elseif sensor.type == 3 then
            sensor.value = sensor.input > 1 and system.getInputs(inputs[sensor.input]) or nil
        elseif sensor.type == #nodeTypes then
            local p1 = sensor.p1 > 0 and sensors[sensor.p1].value or nil
            if p1 then
                sensor.value = sensor.value + (time - lastTime) * p1 * 0.001
            end
        elseif sensor.type > specialTypes then
            local p1 = sensor.p1 > 0 and sensors[sensor.p1].value or nil
            local p2 = sensor.p2 and sensor.p2 > 0 and sensors[sensor.p2].value or nil
            if not p1 or (sensor.type <= twoOpTypes and not p2) then
                sensor.value = nil
            elseif sensor.type == 4 then
                sensor.value = p1 + p2
            elseif sensor.type == 5 then
                sensor.value = p1 - p2
            elseif sensor.type == 6 then
                sensor.value = p1 * p2
            elseif sensor.type == 7 then
                sensor.value = p2 ~= 0.0 and p1 / p2 or nil
            elseif sensor.type == 8 then
                sensor.value = math.min(p1, p2)
            elseif sensor.type == 9 then
                sensor.value = math.max(p1, p2)
            elseif sensor.type == 10 then
                sensor.value = (p1 == p2) and 1 or 0
            elseif sensor.type == 11 then
                sensor.value = (p1 < p2) and 1 or 0
            elseif sensor.type == 12 then
                sensor.value = (p1 > p2) and 1 or 0
            elseif sensor.type == 13 then
                sensor.value = math.abs(p1)
            elseif sensor.type == 14 then
                sensor.value = math.floor(p1)
            elseif sensor.type == 15 then
                sensor.value = math.sqrt(p1)
            end
        end
        if sensor.control > 0 and system.setControl(sensor.control, math.max(math.min(sensor.value or 0, 1), -1), 0) == nil then
            system.unregisterControl(sensor.control)
            system.messageBox(string.format(lang.registerError, sensor.control))
            sensor.control = 0
        end
    end
    if system.getInputsVal(integralResetSwitch) == 1 then
        for i = 1, #sensors do
            if sensors[i].type == #nodeTypes then sensors[i].value = 0 end
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
    system.unregisterTelemetry(2)
    if sensors then
        save()
        sensors = nil
    end
    collectgarbage()
end

collectgarbage()
return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.4.0", name = lang.appName }