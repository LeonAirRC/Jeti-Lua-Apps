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

local poweredClimb = 0
local thermalClimb = 0
local lastAltitude
local lastCapState = -1
local lastAltState = -1

local engineSwitch
local resetSwitch
local altSensorIndex
local energy
local voiceCapSwitch
local voiceAltSwitch
local alarmStep
local alarmControl

local sensorIDs
local sensorParams
local sensorLabels
local alarmControlIndex

local controls = {"...", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10"}

local function toCapacity(climb)
    return 100 * climb / energy
end

local function onEngineSwitchChanged(value)
    engineSwitch = system.getInputsVal(value) ~= 0 and value or nil
    system.pSave("enginesw", engineSwitch)
end

local function onResetSwitchChanged(value)
    resetSwitch = system.getInputsVal(value) ~= 0 and value or nil
    system.pSave("resetsw", resetSwitch)
end

local function onAltSensorIndexChanged(value)
    altSensorIndex = value - 1
    system.pSave("altidx", altSensorIndex)
end

local function onEnergyChanged(value)
    energy = value
    system.pSave("energy", energy)
end

local function onVoiceCapSwitchChanged(value)
    local voiceCapSwitch = system.getInputsVal(value) ~= 0 and value or nil
    system.pSave("voicecapsw", voiceCapSwitch)
end

local function onVoiceAltSwitchChanged(value)
    local voiceAltSwitch = system.getInputsVal(value) ~= 0 and value or nil
    system.pSave("voicealtsw", voiceAltSwitch)
end

local function onAlarmStepChanged(value)
    alarmStep = value
    system.pSave("alarmstp", alarmStep)
end

local function onAlarmControlChanged(value)
    if alarmControl ~= value - 1 then
        if value == 1 then
            system.unregisterControl(alarmControl)
            alarmControl = 0
        else
            if alarmControl > 0 then
                system.unregisterControl(alarmControl)
            end
            if system.registerControl(value - 1, "Altitude Gain", controls[value]) ~= nil then
                alarmControl = value - 1
            else
                alarmControl = 0
                form.setValue(alarmControlIndex, 1)
                system.messageBox("Geber " .. controls[value] .. " konnte nicht registriert werden")
            end
        end
        system.pSave("alarmctrl", alarmControl)
    end
end

local function initForm()
    form.addRow(2)
    form.addLabel({ label = "Engine" })
    form.addInputbox(engineSwitch, false, onEngineSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Altitude sensor" })
    form.addSelectbox(sensorLabels, altSensorIndex + 1, true, onAltSensorIndexChanged)
    form.addRow(3)
    form.addLabel({ label = "100% battery =", width = 180 })
    form.addIntbox(energy, 1, 30000, 500, 0, 1, onEnergyChanged)
    form.addLabel({ label = "m", alignRight = true })
    form.addRow(3)
    form.addLabel({ label = "Alarm step", width = 180 })
    form.addIntbox(alarmStep, 1, 50, 10, 0, 1, onAlarmStepChanged)
    form.addLabel({ label = "%", alignRight = true })
    form.addRow(2)
    form.addLabel({ label = "Announce capacity" })
    form.addInputbox(voiceCapSwitch, false, onVoiceCapSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Announce altitude gain", width = 250 })
    form.addInputbox(voiceAltSwitch, false, onVoiceAltSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Reset" })
    form.addInputbox(resetSwitch, false, onResetSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Alarm output" })
    alarmControlIndex = form.addSelectbox(controls, alarmControl + 1, true, onAlarmControlChanged)
end

local function printTelemetry(width, height)
    local text1 = string.format("%.1fm", poweredClimb)
    local text2 = string.format("%.1fm", thermalClimb)
    local w = math.max(lcd.getTextWidth(FONT_NORMAL, "powered"), lcd.getTextWidth(FONT_NORMAL, "thermal"))
    lcd.drawText(width - 6 - lcd.getTextWidth(FONT_BOLD, text1) - w, 5, text1, FONT_BOLD)
    lcd.drawText(width - 3 - lcd.getTextWidth(FONT_NORMAL, "powered"), 5, "powered", FONT_NORMAL)
    lcd.drawText(width - 6 - lcd.getTextWidth(FONT_BOLD, text2) - w, 10 + lcd.getTextHeight(FONT_NORMAL), text2, FONT_BOLD)
    lcd.drawText(width - 3 - lcd.getTextWidth(FONT_NORMAL, "thermal"), 10 + lcd.getTextHeight(FONT_NORMAL), "thermal", FONT_NORMAL)
end

local function init()
    sensorIDs = {}
    sensorParams = {}
    sensorLabels = {"..."}
    for _,sensor in ipairs(system.getSensors()) do
        if sensor.param ~= 0 and sensor.type ~= 5 and sensor.type ~= 9 then
            sensorIDs[#sensorIDs+1] = sensor.id
            sensorParams[#sensorParams+1] = sensor.param
            sensorLabels[#sensorLabels+1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
        end
    end
    engineSwitch = system.pLoad("enginesw")
    resetSwitch = system.pLoad("resetsw")
    altSensorIndex = system.pLoad("altidx", 0)
    energy = system.pLoad("energy", 500)
    alarmStep = system.pLoad("alarmstp", 10)
    voiceCapSwitch = system.pLoad("voicecapsw")
    voiceAltSwitch = system.pLoad("voicealtsw")
    if altSensorIndex > #sensorIDs then altSensorIndex = 0 end
    alarmControl = system.pLoad("alarmctrl", 0)

    system.registerForm(1, MENU_APPS, "Altitude Gain", initForm)
    system.registerTelemetry(2, "Altitude Gain", 2, printTelemetry)
    if alarmControl ~= 0 and system.registerControl(alarmControl, "Altitude Gain", controls[alarmControl + 1]) == nil then
        alarmControl = 0
        form.setValue(alarmControlIndex, 1)
    end
end

local function loop()
    local capsw = voiceCapSwitch and system.getInputsVal(voiceCapSwitch) or -1
    if capsw == 1 and lastCapState ~= 1 then
        system.playNumber(100 - toCapacity(poweredClimb), 0, "%", "Capacity")
    end
    lastCapState = capsw
    local altsw = voiceAltSwitch and system.getInputsVal(voiceAltSwitch) or -1
    if altsw == 1 and lastAltState ~= 1 then
        system.playNumber(poweredClimb, 0, "m")
        system.playNumber(thermalClimb, 0, "m")
    end
    lastAltState = altsw
    if system.getInputsVal(resetSwitch) == 1 then
        poweredClimb = 0
        thermalClimb = 0
    end
    local altitude = altSensorIndex ~= 0 and system.getSensorValueByID(sensorIDs[altSensorIndex], sensorParams[altSensorIndex]) or nil
    if altitude and altitude.valid and lastAltitude then
        if system.getInputsVal(engineSwitch) == 1 and altitude.value > lastAltitude then
            poweredClimb = poweredClimb + altitude.value - lastAltitude
            if toCapacity(poweredClimb) // alarmStep > toCapacity(poweredClimb + lastAltitude - altitude.value) // alarmStep then -- next step
                -- ALARM
                system.playNumber((100 - toCapacity(poweredClimb + lastAltitude - altitude.value)) // alarmStep * alarmStep, 0, "%", "Capacity")
            end
        elseif system.getInputsVal(engineSwitch) == -1 and altitude.value > lastAltitude then
            thermalClimb = thermalClimb + altitude.value - lastAltitude
        end
    end
    lastAltitude = (altitude and altitude.valid) and altitude.value or nil
    if alarmControl ~= 0 then
        system.setControl(alarmControl, math.max(-1, 1 - 2 * poweredClimb / energy), 0)
    end
end

local function destroy()
    if alarmControl ~= 0 then
        system.unregisterControl(alarmControl)
    end
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.1.2", name = "Altitude Gain" }