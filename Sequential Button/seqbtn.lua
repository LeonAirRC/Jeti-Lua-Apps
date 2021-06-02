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

local controls = {"...", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10"}
local topRows = 6
local statesKey = "states"
local initialKey = "initial"
local nextSwitchKey = "next"
local prevSwitchKey = "prev"
local controlKey = "ctrl"
local delayKey = "delay"
local smoothKey = "smooth"
local endlessKey = "endless"

local states
local state
local initial
local lastNextVal, lastPrevVal
local nextSwitch
local prevSwitch
local control
local delay
local smooth
local endless

local controlIndex, smoothIndex, endlessIndex

local locale = system.getLocale()
local appName = {en = "Sequential Button", de = "Sequenzieller Taster"}
local switchText = {en = "Switch", de = "Switch"}
local controlText = {en = "Control", de = "Geber"}
local delayText = {en = "Delay [ms]", de = "Verzögerung [ms]"}
local smoothText = {en = "Smooth", de = "Geglättet"}
local endlessText = {en = "Endless", de = "Endlos"}
local statesText = {en = "States", de = "Zustände"}
local registerErrorText = {en = "Control %d is already in use", de = "Geber %d wird bereits verwendet", cz = "ovládání %d se již používá"}

local function getTranslation(table)
    return table[locale] or table["en"]
end

local function onNextSwitchChanged(value)
    nextSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave(nextSwitchKey, nextSwitch)
    lastNextVal = system.getInputsVal(nextSwitch)
end

local function onPrevSwitchChanged(value)
    prevSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave(prevSwitchKey, prevSwitch)
    lastPrevVal = system.getInputsVal(prevSwitch)
end

local function onControlChanged(value)
    if control + 1 ~= value then
        if control > 0 then
            system.unregisterControl(control)
        end
        control = value - 1
        if control > 0 then
            if not system.registerControl(control, "sequential", "C" .. tostring(control)) then
                control = 0
                form.setValue(controlIndex, 1)
                system.messageBox(string.format(getTranslation(registerErrorText), value - 1))
            end
        end
        system.pSave(controlKey, control)
    end
end

local function onInitialChanged(value)
    initial = value
    system.pSave(initialKey, initial)
end

local function onDelayChanged(value)
    delay = value
    system.pSave(delayKey, delay)
end

local function onSmoothChanged(value)
    smooth = not value
    form.setValue(smoothIndex, smooth)
    system.pSave(smoothKey, smooth and 1 or 0)
end

local function onEndlessChanged(value)
    endless = not value
    form.setValue(endlessIndex, endless)
    system.pSave(endlessKey, endless and 1 or 0)
end

local function onKeyPressed(keyCode)
    local focused = form.getFocusedRow() - topRows
    if keyCode == KEY_1 and #states < 20 then
        local index = focused < 1 and #states + 1 or focused
        table.insert(states, index, 0) -- insert 0 in the focused row or at the end if no element is focused
        if initial >= index then onInitialChanged(initial + 1) end
        if state >= index then state = state + 1 end
        system.pSave(statesKey, states)
        form.reinit()
    elseif keyCode == KEY_2 and focused > 0 and #states > 1 then
        table.remove(states, focused)
        if initial > focused or (initial == focused and focused == #states + 1) then onInitialChanged(math.max(math.min(initial - 1, #states), 1)) end
        if state > focused or (state == focused and focused == #states + 1) then state = math.max(math.min(state - 1, #states), 1) end
        system.pSave(statesKey, states)
        form.reinit()
    elseif keyCode == KEY_3 and focused > 0 then
        onInitialChanged(focused)
        form.reinit()
    end
end

local function loop()
    local nextVal = system.getInputsVal(nextSwitch)
    local prevVal = system.getInputsVal(prevSwitch)
    if control > 0 and lastNextVal == -1 and nextVal == 1 then
        if endless then
            state = (state % #states) + 1
        else
            state = math.min(state + 1, #states)
        end
        if not system.setControl(control, states[state] / 100, delay, smooth and 1 or 0) then
            system.messageBox(string.format(getTranslation(registerErrorText), control))
            onControlChanged(1) -- delete control
        end
        form.reinit()
    end
    if control > 0 and lastPrevVal == -1 and prevVal == 1 then
        if endless then
            state = (state + #states - 2) % #states + 1
        else
            state = math.max(state - 1, 1)
        end
        if not system.setControl(control, states[state] / 100, delay, smooth and 1 or 0) then
            system.messageBox(string.format(getTranslation(registerErrorText), control))
            onControlChanged(1)
        end
        form.reinit()
    end
    lastNextVal = nextVal
    lastPrevVal = prevVal
end

local function initForm()
    form.addRow(2)
    form.addLabel({ label = getTranslation(switchText) .. "  >" })
    form.addInputbox(nextSwitch, false, onNextSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = getTranslation(switchText) .. "  <" })
    form.addInputbox(prevSwitch, false, onPrevSwitchChanged)
    form.addRow(2)
    form.addLabel({ label = getTranslation(controlText) })
    controlIndex = form.addSelectbox(controls, control + 1, true, onControlChanged)
    form.addRow(2)
    form.addLabel({ label = getTranslation(delayText) })
    form.addIntbox(delay, 0, 10000, 0, 0, 1, onDelayChanged)
    form.addRow(4)
    form.addLabel({ label = getTranslation(smoothText), width = 100 })
    smoothIndex = form.addCheckbox(smooth, onSmoothChanged)
    form.addLabel({ label = getTranslation(endlessText), width = 100 })
    endlessIndex = form.addCheckbox(endless, onEndlessChanged, { width = 60 })
    form.addLabel({ label = getTranslation(statesText), font = FONT_BOLD, enabled = false })
    for i,s in ipairs(states) do
        local font = (i == state) and FONT_BOLD or FONT_NORMAL
        form.addRow(3)
        form.addLabel({ label = (i == initial) and tostring(i) .. " (init)" or tostring(i), width = 150, font = font })
        form.addIntbox(s, -100, 100, 0, 0, 1, function(value)
            states[i] = value
            system.pSave(statesKey, states)
        end, { width = 130, font = font })
        form.addLabel({ label = "%", font = font })
    end
    form.setButton(1, ":add", #states < 20 and ENABLED or DISABLED)
    form.setButton(2, ":delete", #states > 1 and ENABLED or DISABLED)
    form.setButton(3, ":ok", ENABLED)
end

local function init()
    states = system.pLoad(statesKey, {-100, 0, 100})
    if #states < 1 then states = {-100, 0, 100} end
    initial = system.pLoad(initialKey, 1)
    if initial > #states then initial = 1 end
    nextSwitch = system.pLoad(nextSwitchKey)
    prevSwitch = system.pLoad(prevSwitchKey)
    control = system.pLoad(controlKey, 0)
    delay = system.pLoad(delayKey, 0)
    smooth = (system.pLoad(smoothKey) == 1)
    endless = (system.pLoad(endlessKey, 1) == 1)
    if control > 0 and system.registerControl(control, "sequential", "C" .. tostring(control)) == nil then
        system.messageBox(string.format(getTranslation(registerErrorText), control))
        control = 0
    end
    if control > 0 and not system.setControl(control, states[initial] / 100, 0, 0) then
        system.messageBox(string.format(getTranslation(registerErrorText), control))
        control = 0
    end
    state = initial
    lastNextVal = system.getInputsVal(nextSwitch)
    lastPrevVal = system.getInputsVal(prevSwitch)
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm, onKeyPressed)
end

local function destroy()
    if control > 0 then
        system.unregisterControl(control)
    end
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.0", name = getTranslation(appName) }