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

local batteries
local filteredBatteries
local capacitySensor
local currBattery
local selectSwitch
local minCells, maxCells
local minCap, maxCap
local capacity

local battDisplay
local lastSelectVal

local sensorIDs
local sensorParams
local sensorLabels

local lang = io.readall("Apps/BattCounter/locale.jsn")
if not lang then
    return {}
end
lang = json.decode(lang)
lang = lang[system.getLocale()] or lang[lang.default]
collectgarbage()

local function battSelected(value)
    currBattery = value ~= 0 and filteredBatteries[value - 1] or nil
    system.pSave("cbatID", currBattery and currBattery.id or nil)
end

-- filters are not applied immediately but on form initialization
local function minCellsChanged(value)
    if value <= maxCells then
        minCells = value
        system.pSave("minCells", value)
    end
end

local function maxCellsChanged(value)
    if value >= minCells then
        maxCells = value
        system.pSave("maxCells", value)
    end
end

local function minCapaChanged(value)
    if value <= maxCapa then
        minCapa = value
        system.pSave("minCapa", value)
    end
end

local function maxCapaChanged(value)
    if value >= minCapa then
        maxCapa = value
        system.pSave("maxCapa", value)
    end
end

local function filter(battery)
    return battery.cells >= minCells and battery.cells <= maxCells and battery.capacity >= minCapa and battery.capacity <= maxCapa
end

local function updateFiltered()
    filteredBatteries = {}
    for i=1, #batteries do
        if filter(batteries[i]) then
            filteredBatteries[#filteredBatteries+1] = batteries[i]
        end
    end
end

local function keyPressed(keyCode)
    if battDisplay then
        if (keyCode == KEY_5 or keyCode == KEY_ESC) then
            form.preventDefault()
            battDisplay = nil
            form.reinit(2)
        end
    else
        if keyCode == KEY_1 then
            form.reinit(1)
        elseif keyCode == KEY_2 then
            form.reinit(2)
        elseif keyCode == KEY_3 and #batteries < 128 then
            local id = 0
            for i=1, #batteries do
                if batteries[i].id >= id then
                    id = batteries[i].id + 1
                end
            end
            batteries[#batteries+1] = { id = id, label = lang.defaultLabel, cells = 3, capacity = 1000, cycles = 0 }
            if filter(batteries[#batteries]) then
                filteredBatteries[#filteredBatteries+1] = batteries[#batteries]
            end
            form.reinit(2)
            form.setFocusedRow(#batteries)
        elseif keyCode == KEY_4 and #batteries > 0 and form.question(lang.delete1, lang.delete2, batteries[form.getFocusedRow()].label, 0, false, 1000) == 1 then
            local removed = table.remove(batteries, form.getFocusedRow())
            if removed == currBattery then
                currBattery = nil
            end
            for i=1, #filteredBatteries do
                if filteredBatteries[i].id == removed.id then
                    table.remove(filteredBatteries, i)
                    break
                end
            end
            form.reinit(2)
        end
    end
end

local function printTelemetry(width, height)
    if currBattery then
        lcd.drawText(5, 5, currBattery.label, lcd.getTextWidth(FONT_BIG, currBattery.label) + 10 > width and FONT_NORMAL or FONT_BIG)
        lcd.drawText(5, 30, string.format("%s: %d", lang.cycles, currBattery.cycles), FONT_BIG)
    end
end

local function initForm(formID)
    if formID == 1 then
        form.setTitle(lang.appName)
        updateFiltered()
        local battLabels = {"..."}
        local index = 0
        for i=1, #filteredBatteries do
            battLabels[#battLabels+1] = filteredBatteries[i].label
            if currBattery and filteredBatteries[i].id == currBattery.id then
                index = i
            end
        end
        form.addRow(2)
        form.addLabel({ label = lang.battery })
        form.addSelectbox(battLabels, index + 1, true, battSelected)
        form.addRow(2)
        form.addLabel({ label = lang.capsens })
        form.addSelectbox(sensorLabels, capacitySensor + 1, true, function(value)
            capacitySensor = value - 1
            system.pSave("capsens", capacitySensor)
        end)
        form.addRow(2)
        form.addLabel({ label = lang.selswitch })
        form.addInputbox(selectSwitch, false, function(value)
            selectSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
            system.pSave("selectsw", selectSwitch)
        end)
        form.addRow(3)
        form.addLabel({ label = lang.cellrange, width = 130 })
        form.addIntbox(minCells, 1, 64, 3, 0, 1, minCellsChanged)
        form.addIntbox(maxCells, 1, 64, 3, 0, 1, maxCellsChanged)
        form.addRow(3)
        form.addLabel({ label = lang.caprange, width = 130 })
        form.addIntbox(minCapa, 1, 32000, 1000, 0, 10, minCapaChanged)
        form.addIntbox(maxCapa, 1, 32000, 1000, 0, 10, maxCapaChanged)

        form.setButton(1, "Set", DISABLED)
        form.setButton(2, "Batt", ENABLED)
    elseif formID == 2 then
        if battDisplay then
            form.setTitle(battDisplay.label)
            form.addRow(2)
            form.addLabel({ label = lang.label })
            form.addTextbox(battDisplay.label, 16, function(value)
                battDisplay.label = value
                form.setTitle(value)
            end)
            form.addRow(2)
            form.addLabel({ label = lang.cells })
            form.addIntbox(battDisplay.cells, 1, 64, 3, 0, 1, function(value) battDisplay.cells = value end)
            form.addRow(2)
            form.addLabel({ label = lang.capacity })
            form.addIntbox(battDisplay.capacity, 1, 32000, 1000, 0, 10, function(value) battDisplay.capacity = value end)
            form.addRow(2)
            form.addLabel({ label = lang.cycles })
            form.addIntbox(battDisplay.cycles, 0, 32000, 0, 0, 1, function(value) battDisplay.cycles = value end)
        else
            form.setTitle(lang.batteries)
            for i = 1, #batteries do
                form.addLink(function()
                    battDisplay = batteries[i]
                    form.reinit(2)
                end, { label = batteries[i].label .. ">>" })
            end
            form.setButton(1, "Set", ENABLED)
            form.setButton(2, "Batt", DISABLED)
            form.setButton(3, ":add", ENABLED)
            form.setButton(4, ":delete", ENABLED)
        end
    end
end

local function keyPressedSelect(keyCode)
    if keyCode == KEY_2 and currBattery then
        currBattery.cycles = currBattery.cycles + 1
        form.reinit()
    elseif keyCode == KEY_3 and currBattery then
        currBattery.cycles = math.max(currBattery.cycles - 1, 0)
        form.reinit()
    elseif keyCode == KEY_5 then
        battSelected(form.getFocusedRow())
    end
end

local function initSelectForm()
    updateFiltered()
    form.addRow(1)
    form.addLabel({ label = "..." })
    for i,battery in ipairs(batteries) do
        form.addRow(1)
        form.addLabel({ label = string.format("%s: %d", battery.label, battery.cycles) })
        if currBattery and battery.id == currBattery.id then
            form.setFocusedRow(i + 1)
        end
    end

    form.setButton(1, lang.cycles, ENABLED)
    form.setButton(2, ":up", ENABLED)
    form.setButton(3, ":down", ENABLED)
    form.setButton(5, ":okBig", ENABLED)
end

local function init()
    sensorIDs = {}
    sensorParams = {}
    sensorLabels = {"..."}
    for _,sensor in ipairs(system.getSensors()) do
        if sensor.param ~= 0 and sensor.type ~= 5 then
            sensorLabels[#sensorLabels+1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
            sensorIDs[#sensorIDs+1] = sensor.id
            sensorParams[#sensorParams+1] = sensor.param
        end
    end

    minCells = system.pLoad("minCells", 2)
    maxCells = system.pLoad("maxCells", 3)
    minCapa = system.pLoad("minCapa", 1000)
    maxCapa = system.pLoad("maxCapa", 2000)
    selectSwitch = system.pLoad("selectsw")
    capacitySensor = system.pLoad("capsens", 0)
    local id = system.pLoad("cbatID")

    logfile = io.open("Apps/BattCounter/log.csv", "a")

    batteries = json.decode(io.readall("Apps/BattCounter/batt.jsn"))
    updateFiltered()
    for i=1, #batteries do
        if batteries[i].id == id then
            currBattery = batteries[i]
            break
        end
    end
    system.registerForm(1, MENU_APPS, lang.appName, initForm, keyPressed)
    system.registerTelemetry(1, lang.appName, 2, printTelemetry)
end

local function loop()
    local selectVal = selectSwitch and system.getInputsVal(selectSwitch) or nil
    if lastSelectVal == -1 and selectVal == 1 and form.getActiveForm() ~= 2 then
        system.registerForm(2, 0, lang.batteries, initSelectForm, keyPressedSelect)
    end
    lastSelectVal = selectVal

    local cap = capacitySensor ~= 0 and system.getSensorValueByID(sensorIDs[capacitySensor], sensorParams[capacitySensor]) or nil
    cap = (cap and cap.valid) and cap.value or capacity
    if cap and capacity and cap < capacity and currBattery then
        currBattery.cycles = currBattery.cycles + 1
        local logfile = io.open("Apps/BattCounter/log.csv", "a")
        if logfile then
            io.write(logfile, math.floor(system.getTime()), ",", system.getProperty("Model"), ",", currBattery.label, ",", math.floor(currBattery.cells), ",",
            math.floor(currBattery.capacity), ",", math.floor(currBattery.cycles), ",", math.floor(capacity), "\n")
            io.close(logfile)
        end
    end
    capacity = cap
end

local function destroy()
    local file = io.open("Apps/BattCounter/batt.jsn", "w")
    io.write(file, json.encode(batteries))
    io.close(file)
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "0.0.1", name = lang.appName }