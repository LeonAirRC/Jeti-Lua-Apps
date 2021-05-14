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

local labelsKey = "ps_lab"
local upSwitchKey = "ps_up"
local downSwitchKey = "ps_down"
local neutralKey = "ps_neu"
local enabledKey = "ps_act"
local delaysKey = "ps_del"

local labels
local upSwitches, downSwitches
local neutralPoints
local enabled
local values = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local delays
local lastTime
local controlIndex = 0

local checkboxIndex

local locale = system.getLocale()
local appName = {en = "Proportional Switches", de = "Proportionale Schalter", cz = "proporcionální spínač"}
local labelText = {en = "Label", de = "Bezeichnung", cz = "název"}
local enabledText = {en = "Enabled", de = "Aktiv", cz = "činný"}
local switchText = {en = "Switch", de = "Switch", cz = "vypínač"}
local neutralPointText = {en = "Neutral point", de = "Neutralpunkt", cz = "neutrální bod"}
local delayText = {en = "Delay [s]", de = "Verzögerung [s]", cz = "Zpoždění [s]"}
local registerErrorText = {en = "Control %d is already in use", de = "Geber %d wird bereits verwendet", cz = "ovládání %d se již používá"}

local function getTranslation(table)
    return table[locale] or table["en"]
end

local function onLabelChanged(value)
    labels[controlIndex] = value
    system.pSave(labelsKey, labels)
end

local function onEnableChanged(value)
    if value then
        system.unregisterControl(controlIndex)
        enabled[controlIndex] = 0
    else
        if system.registerControl(controlIndex, labels[controlIndex], "C" .. tostring(controlIndex)) ~= nil then
            enabled[controlIndex] = 1
        else
            enabled[controlIndex] = 0
            system.messageBox(string.format(getTranslation(registerErrorText), controlIndex))
        end
    end
    form.reinit()
    form.setValue(checkboxIndex, enabled[controlIndex] == 1)
    system.pSave(enabledKey, enabled)
end

local function onUpSwitchChanged(value)
    upSwitches[controlIndex] = value
    system.pSave(upSwitchKey .. tostring(controlIndex), value)
end

local function onDownSwitchChanged(value)
    downSwitches[controlIndex] = value
    system.pSave(downSwitchKey .. tostring(controlIndex), value)
end

local function onNeutralPointChanged(value)
    neutralPoints[controlIndex] = value
    system.pSave(neutralKey, neutralPoints)
end

local function onDelayChanged(value)
    delays[controlIndex] = value
    system.pSave(delaysKey, delays)
end

local function onKeyPressed(keyCode)
    if controlIndex ~= 0 and (keyCode == KEY_ESC or keyCode == KEY_5) then
        form.preventDefault()
        controlIndex = 0
        form.reinit()
    end
end

local function loop()
    local time = system.getTimeCounter()
    for i = 1, 10 do
        if upSwitches[i] and downSwitches[i] then
            local total = (system.getInputsVal(upSwitches[i]) - neutralPoints[i]) / (1 - neutralPoints[i]) - (system.getInputsVal(downSwitches[i]) - neutralPoints[i]) / (1 - neutralPoints[i])
            values[i] = values[i] + total * (time - lastTime) / (100 * delays[i])
            if values[i] > 1 then       values[i] = 1
            elseif values[i] < -1 then  values[i] = -1
            end
            if system.setControl(i, values[i], 0) == nil then
                enabled[i] = 0
                system.messageBox(string.format(getTranslation(registerErrorText), i))
            end
        end
    end
    lastTime = time
end

local function printForm(width, height)
    if controlIndex ~= 0 and enabled[controlIndex] == 1 then
        local x = width // 2
        local str = string.format("%.2f", values[controlIndex])
        lcd.drawText(x - lcd.getTextWidth(FONT_NORMAL, str) // 2, height - 40, str)
        lcd.drawRectangle(x - 60, height - 20, 120, 20)
        lcd.drawLine(x, height - 20, x, height - 1)
        local rectWidth = math.floor(values[controlIndex] * 60 + 0.5)
        lcd.drawFilledRectangle(math.min(rectWidth, 0) + x, height - 20, math.abs(rectWidth), 20)
    end
end

local function initForm()
    if controlIndex == 0 then
        for i = 1, 10 do
            form.addRow(4)
            form.addLabel({ label = "C" .. tostring(i), font = FONT_BOLD, width = 60 })
            form.addLabel({ label = labels[i], width = 180 })
            form.addCheckbox(enabled[i] == 1, nil, { enabled = false, width = 30 })
            form.addLink(function()
                controlIndex = i
                form.reinit()
            end, { label = ">> ", alignRight = true })
        end
    else
        form.setTitle("C" .. tostring(controlIndex))
        form.addRow(4)
        form.addLabel({ label = getTranslation(labelText), font = FONT_BOLD, width = 100 })
        form.addTextbox(labels[controlIndex], 12, onLabelChanged, { font = FONT_BOLD, width = 120 })
        form.addLabel({ label = getTranslation(enabledText), font = FONT_BOLD, width = 70 })
        checkboxIndex = form.addCheckbox(enabled[controlIndex] == 1, onEnableChanged)
        if enabled[controlIndex] == 1 then
            form.addRow(2)
            form.addLabel({ label = getTranslation(switchText) .. " +" })
            form.addInputbox(upSwitches[controlIndex], true, onUpSwitchChanged)
            form.addRow(2)
            form.addLabel({ label = getTranslation(switchText) .. " -" })
            form.addInputbox(downSwitches[controlIndex], true, onDownSwitchChanged)
            form.addRow(2)
            form.addLabel({ label = getTranslation(neutralPointText) })
            form.addIntbox(neutralPoints[controlIndex], -1, 0, -1, 0, 1, onNeutralPointChanged)
            form.addRow(2)
            form.addLabel({ label = getTranslation(delayText) })
            form.addIntbox(delays[controlIndex], 1, 600, 10, 1, 1, onDelayChanged)
        end
    end
    form.setFocusedRow(1)
end

local function init()
    labels = system.pLoad(labelsKey) or {"Control 1", "Control 2", "Control 3", "Control 4", "Control 5", "Control 6", "Control 7", "Control 8", "Control 9", "Control 10"}
    neutralPoints = system.pLoad(neutralKey) or {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1}
    enabled = system.pLoad(enabledKey) or {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    delays = system.pLoad(delaysKey) or {10, 10, 10, 10, 10, 10, 10, 10, 10, 10}
    upSwitches = {}
    downSwitches = {}
    for i = 1, 10 do
        upSwitches[i] = system.pLoad(upSwitchKey .. tostring(i))
        downSwitches[i] = system.pLoad(downSwitchKey .. tostring(i))
    end
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm, onKeyPressed, printForm)
    for i = 1, 10 do
        if enabled[i] == 1 and system.registerControl(i, labels[i], "C" .. tostring(i)) == nil then
            enabled[i] = 0
            system.messageBox(string.format(getTranslation(registerErrorText), i))
        end
    end
    lastTime = system.getTimeCounter()
end

local function destroy()
    for i = 1, 10 do
        if enabled[i] then
            system.unregisterControl(i)
        end
    end
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.01", name = getTranslation(appName) }