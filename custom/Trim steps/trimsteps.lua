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

local voiceSwitch
local upSwitch, downSwitch
local lastUpVal, lastDownVal
local lastVoiceVal
local step
local trim

local trimIntboxIndex

local function upSwitchChanged(value)
    upSwitch = value
    system.pSave("upsw", upSwitch)
    lastUpVal = system.getInputsVal(upSwitch)
end

local function downSwitchChanged(value)
    downSwitch = value
    system.pSave("downsw", downSwitch)
    lastDownVal = system.getInputsVal(downSwitch)
end

local function voiceSwitchChanged(value)
    voiceSwitch = system.getInputsVal(value) ~= 0 and value or nil
    system.pSave("voicesw", voiceSwitch)
    lastVoiceVal = system.getInputsVal(voiceSwitch)
end

local function stepChanged(value)
    step = value
    system.pSave("step", step)
end

local function printTelemetry(width, height)
    local text = tostring(math.floor(trim))
    lcd.drawText((width - lcd.getTextWidth(FONT_MAXI, text)) // 2, (height - lcd.getTextHeight(FONT_MAXI)) // 2, text, FONT_MAXI)
end

local function initForm()
    form.addRow(2)
    form.addLabel({ label = "Trim up" })
    form.addInputbox(upSwitch, false, upSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Trim down" })
    form.addInputbox(downSwitch, false, downSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Announcement switch", width = 200 })
    form.addInputbox(voiceSwitch, false, voiceSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Step" })
    form.addIntbox(step, 1, 100, 1, 0, 1, stepChanged)
    form.addRow(2)
    form.addLabel({ label = "Value" })
    trimIntboxIndex = form.addIntbox(trim, -32000, 32000, 0, 0, 1, function (value)
        trim = value
        system.pSave("trim", trim)
    end)
end

local function init()
    voiceSwitch = system.pLoad("voicesw")
    upSwitch = system.pLoad("upsw")
    downSwitch = system.pLoad("downsw")
    step = system.pLoad("step", 1)
    trim = system.pLoad("trim", 0)
    system.registerForm(1, MENU_APPS, "Trim steps", initForm)
    system.registerTelemetry(2, "Trim steps", 4, printTelemetry)
    lastUpVal = system.getInputsVal(upSwitch)
    lastDownVal = system.getInputsVal(downSwitch)
    lastVoiceVal = system.getInputsVal(voiceSwitch)
end

local function loop()
    local upVal = system.getInputsVal(upSwitch)
    local downVal = system.getInputsVal(downSwitch)
    if upVal == 1 and lastUpVal == -1 then
        trim = trim + step
        system.playNumber(trim, 0, "")
        system.pSave("trim", trim)
        form.setValue(trimIntboxIndex, trim)
    elseif downVal == 1 and lastDownVal == -1 then
        trim = trim - step
        system.playNumber(trim, 0, "")
        system.pSave("trim", trim)
        form.setValue(trimIntboxIndex, trim)
    end
    lastUpVal = upVal
    lastDownVal = downVal
    local voiceVal = system.getInputsVal(voiceSwitch)
    if voiceVal == 1 and lastVoiceVal == -1 then
        system.playNumber(trim, 0, "")
    end
    lastVoiceVal = voiceVal
end

return { init = init, loop = loop, author = "LeonAir RC", version = "0.0.4", name = "Trim steps" }