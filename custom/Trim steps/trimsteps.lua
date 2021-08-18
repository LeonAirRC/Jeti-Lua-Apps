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
local trimSwitch
local lastTrimVal
local lastVoiceVal
local step
local trim
local min, max = 0, 0

local function trimSwitchChanged(value)
    trimSwitch = value
    system.pSave("trimsw", trimSwitch)
    lastTrimVal = system.getInputsVal(trimSwitch)
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
    lcd.drawText((width - lcd.getTextWidth(FONT_MAXI, text)) // 2, (height - lcd.getTextHeight(FONT_MAXI)) // 2 - 5, text, FONT_MAXI)
    local minText, maxText = tostring(math.floor(min)), tostring(math.floor(max))
    lcd.drawText(width - lcd.getTextWidth(FONT_MINI, maxText) - 10, height - lcd.getTextHeight(FONT_MINI) - 5, maxText, FONT_MINI)
    lcd.drawText(width - 40 - lcd.getTextWidth(FONT_MINI, minText), height - lcd.getTextHeight(FONT_MINI) - 5, minText, FONT_MINI)
end

local function initForm()
    form.addRow(2)
    form.addLabel({ label = "Trim switch" })
    form.addInputbox(trimSwitch, true, trimSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Announcement switch", width = 200 })
    form.addInputbox(voiceSwitch, false, voiceSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = "Step" })
    form.addIntbox(step, 1, 100, 1, 0, 1, stepChanged)
end

local function init()
    voiceSwitch = system.pLoad("voicesw")
    trimSwitch = system.pLoad("trimsw")
    step = system.pLoad("step", 1)
    trim = 0
    system.registerForm(1, MENU_APPS, "Trim steps", initForm)
    system.registerTelemetry(2, "Trim steps", 2, printTelemetry)
    lastTrimVal = system.getInputsVal(trimSwitch)
    lastVoiceVal = system.getInputsVal(voiceSwitch)
end

local function loop()
    local trimVal = system.getInputsVal(trimSwitch)
    if trimVal == -1 and lastTrimVal ~= -1 then
        trim = trim - step
    elseif trimVal == 1 and lastTrimVal ~= 1 then
        trim = trim + step
    end
    if trim > max then max = trim end
    if trim < min then min = trim end
    lastTrimVal = trimVal
    local voiceVal = system.getInputsVal(voiceSwitch)
    if voiceVal == 1 and lastVoiceVal == -1 then
        system.playNumber(trim, 0, "")
    end
    lastVoiceVal = voiceVal
end

return { init = init, loop = loop, author = "LeonAir RC", version = "0.0.1", name = "Trim steps" }