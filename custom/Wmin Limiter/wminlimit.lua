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

local switch
local energyLimit
local timeLimit
local uSensor
local iSensor
local engineControl
local engineInput
local alarmFile

local lastTime
local lastSwitchVal = -1
local energy = 0
local energyTotal = 0
local runtime = 0
local sensorIDs = {}
local sensorParams = {}
local sensorLabels = {"..."}
local controlIndex
local limited = false
local energyLogID
local energyTotalLogID

local controls = {"...", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10"}

local function onSwitchChanged(value)
    switch = system.getInputsVal(value) ~= 0 and value or nil
    system.pSave("switch", switch)
end

local function onEnergyLimitChanged(value)
    energyLimit = value
    system.pSave("eLim", energyLimit)
end

local function onTimeLimitChanged(value)
    timeLimit = value
    system.pSave("tLim", timeLimit)
end

local function onUSensorChanged(value)
    uSensor = value - 1
    system.pSave("usens", uSensor)
end

local function onISensorChanged(value)
    iSensor = value - 1
    system.pSave("isens", iSensor)
end

local function onEngineControlChanged(value)
    if engineControl ~= value - 1 then
        if value == 1 then
            system.unregisterControl(engineControl)
            engineControl = 0
        else
            if engineControl > 0 then
                system.unregisterControl(engineControl)
            end
            if system.registerControl(value - 1, "Wmin Limiter", controls[value]) ~= nil then
                engineControl = value - 1
            else
                engineControl = 0
                form.setValue(controlIndex, 1)
                system.messageBox("Geber " .. controls[value] .. " konnte nicht registriert werden")
            end
        end
        system.pSave("ctrl", engineControl)
    end
end

local function onEngineInputChanged(value)
    local info = value and system.getSwitchInfo(value) or nil
    engineInput = (info and info.assigned) and value or nil
    system.pSave("input", engineInput)
end

local function onAlarmFileChanged(value)
    alarmFile = value
    system.pSave("alarmaud", alarmFile)
end

local function getLogVariable(id)
    if id == energyLogID then
        return math.floor(energy * 100), 2
    elseif id == energyTotalLogID then
        return math.floor(energyTotal * 100), 2
    end
end

local function printTelemetry(width, height)
    local text = string.format("%.2f", energyTotal)
    if height > 60 then
        lcd.drawText(width - lcd.getTextWidth(FONT_MAXI, text) - 3, (height - lcd.getTextHeight(FONT_MAXI)) // 2, text, FONT_MAXI)
        lcd.drawText(width - lcd.getTextWidth(FONT_NORMAL, "Wmin") - 3, height - 3 - lcd.getTextHeight(FONT_NORMAL), "Wmin")
    else
        local w = lcd.getTextWidth(FONT_NORMAL, "Wmin")
        lcd.drawText(width - w - lcd.getTextWidth(FONT_BIG, text) - 6, (height - lcd.getTextHeight(FONT_BIG)) // 2, text, FONT_BIG)
        lcd.drawText(width - w - 3, (height + lcd.getTextHeight(FONT_BIG)) // 2 - 1 - lcd.getTextHeight(FONT_NORMAL), "Wmin", FONT_NORMAL)
    end
end

local function initForm()
    form.addRow(2)
    form.addLabel({ label = "Switch" })
    form.addInputbox(switch, false, onSwitchChanged)
    form.addLabel({ label = "Limits", font = FONT_BOLD })
    form.addRow(2)
    form.addLabel({ label = "Energie (Wmin)" })
    form.addIntbox(energyLimit, 1, 30000, 100, 0, 1, onEnergyLimitChanged)
    form.addRow(2)
    form.addLabel({ label = "Zeit (s)" })
    form.addIntbox(timeLimit, 10, 3600, 22, 0, 1, onTimeLimitChanged)
    form.addLabel({ label = "Sensoren", font = FONT_BOLD })
    form.addRow(2)
    form.addLabel({ label = "Spannung (V)" })
    form.addSelectbox(sensorLabels, uSensor + 1, true, onUSensorChanged)
    form.addRow(2)
    form.addLabel({ label = "Strom (A)" })
    form.addSelectbox(sensorLabels, iSensor + 1, true, onISensorChanged)
    form.addSpacer(0, 15)
    form.addRow(2)
    form.addLabel({ label = "Alarmsound" })
    form.addAudioFilebox(alarmFile, onAlarmFileChanged)
    form.addRow(2)
    form.addLabel({ label = "Motorlaufzeit Trigger" })
    form.addInputbox(engineInput, true, onEngineInputChanged)
    form.addRow(2)
    form.addLabel({ label = "Gas-Output" })
    controlIndex = form.addSelectbox(controls, engineControl + 1, true, onEngineControlChanged)
end

local function loop()
    local currTime = system.getTimeCounter()
    local switchVal = switch and system.getInputsVal(switch) or -1
    local u = uSensor ~= 0 and system.getSensorValueByID(sensorIDs[uSensor], sensorParams[uSensor]) or nil
    u = (u and u.valid) and u.value or 0
    local i = iSensor ~= 0 and system.getSensorValueByID(sensorIDs[iSensor], sensorParams[iSensor]) or nil
    i = (i and i.valid) and i.value or 0
    local de = (currTime - lastTime) * u * i / 60000
    energy = energy + de
    energyTotal = energyTotal + de
    if engineInput and system.getInputsVal(engineInput) > -1 then
        runtime = runtime + currTime - lastTime
    end
    if switchVal == 1 then
        if lastSwitchVal == -1 then
            energy = 0
            runtime = 0
            limited = false
        end
        if not limited and energy >= energyLimit then
            limited = true
            system.playFile(alarmFile, AUDIO_IMMEDIATE)
            system.playNumber(energy, 2, "Wmi")
        elseif not limited and runtime >= 1000 * timeLimit then
            limited = true
            system.playFile(alarmFile, AUDIO_IMMEDIATE)
            system.playNumber(runtime // 1000, 0, "s")
        end
        if engineControl > 0 then
            system.setControl(engineControl, limited and 1 or -1, 0)
        end
    else
        limited = false
        if engineControl > 0 then
            system.setControl(engineControl, -1, 0)
        end
    end
    lastSwitchVal = switchVal
    lastTime = currTime
end

local function init()
    switch = system.pLoad("switch")
    energyLimit = system.pLoad("eLim", 100)
    timeLimit = system.pLoad("tLim", 22)
    uSensor = system.pLoad("usens", 0)
    iSensor = system.pLoad("isens", 0)
    engineControl = system.pLoad("ctrl", 0)
    engineInput = system.pLoad("input")
    alarmFile = system.pLoad("alarmaud", "")

    for _,sensor in ipairs(system.getSensors()) do
        if sensor.param ~= 0 and sensor.type ~= 5 and sensor.type ~= 9 then
            sensorLabels[#sensorLabels+1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
            sensorIDs[#sensorIDs+1] = sensor.id
            sensorParams[#sensorParams+1] = sensor.param
        end
    end

    system.registerForm(1, MENU_APPS, "Wmin Limiter", initForm)
    system.registerTelemetry(2, "Wmin Limiter", 0, printTelemetry)
    if engineControl ~= 0 then
        system.registerControl(engineControl, "Wmin Limiter", controls[engineControl + 1])
    end
    energyLogID = system.registerLogVariable("Energie", "Wmi", getLogVariable)
    energyTotalLogID = system.registerLogVariable("Energie/Runde", "Wmi", getLogVariable)
    lastTime = system.getTimeCounter()
    collectgarbage()
end

local function destroy()
    if energyLogID then
        system.unregisterLogVariable(energyLogID)
    end
    if energyTotalLogID then
        system.unregisterLogVariable(energyTotalLogID)
    end
    if engineControl ~= 0 then
        system.unregisterControl(engineControl)
    end
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "0.2.0", name = "Wmin Limiter" }