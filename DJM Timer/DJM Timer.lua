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

local appName = "DMFV DJM Timer"

local switchKey = "timer_switch"
local resetSwitchKey = "timer_resetSwitch"
local modeKey = "timer_mode"

local switch
local resetSwitch
local mode

local startTimeMillis
local lastTimeMillis
local time
local running

local function resetTime()
    time = mode == 1 and 150 or 120
end

local function start()
    startTimeMillis = system.getTimeCounter()
    lastTimeMillis = startTimeMillis
    resetTime()
    running = true
end

local function stop()
    running = false
    time = 0
end

local function onSwitchChanged(value)
    local switchVal = system.getInputsVal(value)
    if (switchVal and switchVal ~= 0) then
        switch = value
    else
        switch = nil
    end
    system.pSave(switchKey, switch)
end

local function onResetSwitchChanged(value)
    local switchVal = system.getInputsVal(value)
    if (switchVal and switchVal ~= 0) then
        resetSwitch = value
    else
        resetSwitch = nil
    end
    system.pSave(resetSwitchKey, resetSwitch)
end

local function onModeChanged(value)
    stop()
    mode = value
    resetTime()
    system.pSave(modeKey, mode)
end

local function nextSecond()
    time = time - 1
    if (time >= 60) then
        if (time % 10 == 0) then
            system.playNumber(time // 60, 0, "min")
            if (time % 60 ~= 0) then
                system.playNumber(time % 60, 0, nil)
            end
        end
    elseif (time > 20) then
        if (time % 5 == 0) then
            system.playNumber(time, 0, nil)
        end
    else
        if (time == -11) then
            stop()
            return
        end
        system.playNumber(math.abs(time), 0, nil)
    end
end

local function printTelemetry(width, height)
    local text = time < 0 and "-" or ""
    text = text .. string.format("%02d:%02d", math.max(time, 0) // 60, math.abs(time) % 60)
    lcd.drawText((width - lcd.getTextWidth(FONT_MAXI, text)) // 2, (height - lcd.getTextHeight(FONT_MAXI, text)) // 2, text, FONT_MAXI)
end

---------------------------------------------------------------

local function loop()
    if (resetSwitch and system.getInputsVal(resetSwitch) == 1 and running) then
        stop()
        resetTime()
        system.playBeep(1, 4238, 200)
    elseif ((not running) and switch and system.getInputsVal(switch) == 1) then
        start()
        system.playBeep(0, 4000, 800)
    elseif (running) then
        local currTimeMillis = system.getTimeCounter()
        if ((currTimeMillis - startTimeMillis) // 1000 > (lastTimeMillis - startTimeMillis) // 1000) then
            nextSecond()
        end
        lastTimeMillis = currTimeMillis
    end
end

local function initForm(formID)
    form.addRow(2)
    form.addLabel({ label = "Mode" })
    form.addSelectbox({"F-Schlepp", "Elektrosegelflug"}, mode, false, onModeChanged, { alignRight = true })
    form.addRow(2)
    form.addLabel({ label = "Switch" })
    form.addInputbox(switch, false, onSwitchChanged, { alignRight = true })
    form.addRow(2)
    form.addLabel({ label = "Reset" })
    form.addInputbox(resetSwitch, false, onResetSwitchChanged, { alignRight = true })
end

local function init()
    switch = system.pLoad(switchKey)
    resetSwitch = system.pLoad(resetSwitchKey)
    mode = system.pLoad(modeKey, 1)
    resetTime()
    system.registerForm(1, MENU_APPS, appName, initForm)
    system.registerTelemetry(2, "Timer", 2, printTelemetry)
end

local function destroy()
    system.unregisterTelemetry(2)
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.0", name = appName}