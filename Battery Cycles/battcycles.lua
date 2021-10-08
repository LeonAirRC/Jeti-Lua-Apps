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
local displayedBattery
local selectSwitch
local minCells, maxCells
local minCapacity, maxCapacity
local lastSelectVal
local modelOn
local autoDetect
local intboxIndices
local autoDetectIndex
local currForm
local battTypes
local checkboxIndices
local typeIndices   -- list of the selected indices referring to lang.battTypes
local currTypeIndex -- current index of 'typeIndices'

local lang = io.readall("Apps/BattCycles/locale.jsn")
if not lang then
    return {}
end
lang = json.decode(lang)
lang = lang[system.getLocale()] or lang[lang.default]
collectgarbage()

local function minCellsChanged(value)
    if value <= maxCells then
        minCells = value
        system.pSave("minCells", value)
    else
        form.setValue(intboxIndices[1], minCells)
    end
end

local function maxCellsChanged(value)
    if value >= minCells then
        maxCells = value
        system.pSave("maxCells", value)
    else
        form.setValue(intboxIndices[2], maxCells)
    end
end

local function minCapacityChanged(value)
    if value <= maxCapacity then
        minCapacity = value
        system.pSave("minCapa", value)
    else
        form.setValue(intboxIndices[3], minCapacity)
    end
end

local function maxCapacityChanged(value)
    if value >= minCapacity then
        maxCapacity = value
        system.pSave("maxCapa", value)
    else
        form.setValue(intboxIndices[4], maxCapacity)
    end
end

-- sets filteredBatteries to the list of all batteries in consistent order that fit all criteria
local function updateFiltered()
    filteredBatteries = {}
    for _,battery in ipairs(batteries) do
        if battery.cells >= minCells and battery.cells <= maxCells and battery.capacity >= minCapacity and battery.capacity <= maxCapacity then
            filteredBatteries[#filteredBatteries+1] = battery
        end
    end
end

-- returns an array filled with zeros of the size #lang.battTypes execpt of the first element being a one
local function getDefaultTypeSelection()
    local arr = {1}
    for i = 2, #lang.battTypes do
        arr[#arr+1] = 0
    end
    return arr
end

local function keyPressed(keyCode)
    if keyCode == KEY_1 then -- go to settings page
        form.reinit(1)
    elseif currForm == 2 and not displayedBattery then
        if keyCode == KEY_2 and #batteries < 512 then -- add new battery
            batteries[#batteries+1] = { label = lang.defaultLabel, cycles = 0, capacity = 1000, cells = 3 }
            form.reinit(2)
        elseif keyCode == KEY_3 and #batteries > 0 and form.question(lang.delete1, nil, batteries[form.getFocusedRow()].label, 0, false, 1000) == 1 then -- delete focused battery
            table.remove(batteries, form.getFocusedRow())
            form.reinit(2)
        elseif keyCode == KEY_4 and #batteries > 0 and form.getFocusedRow() > 1 then -- swap focused battery and the one above
            local index = form.getFocusedRow()
            local batt = batteries[index]
            batteries[index] = batteries[index - 1]
            batteries[index - 1] = batt
            form.reinit(2)
            form.setFocusedRow(index - 1)
        elseif keyCode == KEY_5 then -- swap focused battery and the one below
            form.preventDefault()
            if form.getFocusedRow() < #batteries then
                local index = form.getFocusedRow()
                local batt = batteries[index]
                batteries[index] = batteries[index + 1]
                batteries[index + 1] = batt
                form.reinit(2)
                form.setFocusedRow(index + 1)
            end
        end
    elseif currForm == 2 and (keyCode == KEY_ESC or keyCode == KEY_5) and displayedBattery then -- close the battery details and show the list
            form.preventDefault()
            displayedBattery = nil
            form.reinit(2)
    elseif keyCode == KEY_2 then -- go to battery list
        form.reinit(2)
    end
end

local function initForm(formID)
    currForm = formID
    if formID == 1 then
        form.setTitle(lang.appName)
        form.addRow(2)
        form.addLabel({ label = lang.selswitch })
        form.addInputbox(selectSwitch, false, function(value)
            selectSwitch = system.getInputsVal(value) ~= 0 and value or nil
            system.pSave("selectsw", selectSwitch)
        end)
        intboxIndices = {}
        form.addRow(3)
        form.addLabel({ label = lang.cellrange, width = 170 })
        intboxIndices[1] = form.addIntbox(minCells, 1, 64, 3, 0, 1, minCellsChanged, { width = 70 })
        intboxIndices[2] = form.addIntbox(maxCells, 1, 64, 3, 0, 1, maxCellsChanged, { width = 70 })
        form.addRow(3)
        form.addLabel({ label = lang.caprange, width = 170 })
        intboxIndices[3] = form.addIntbox(minCapacity, 1, 32000, 1000, 0, 10, minCapacityChanged, { width = 70 })
        intboxIndices[4] = form.addIntbox(maxCapacity, 1, 32000, 1000, 0, 10, maxCapacityChanged, { width = 70 })
        form.addRow(2)
        form.addLabel({ label = lang.autoDetect, width = 280 })
        autoDetectIndex = form.addCheckbox(autoDetect, function(value)
            autoDetect = not value
            form.setValue(autoDetectIndex, autoDetect)
            system.pSave("autodec", autoDetect and 1 or 0)
        end)
        form.addRow(1)
        form.addLabel({ label = lang.battTypesTitle, font = FONT_BOLD })
        checkboxIndices = {}
        for i,type in ipairs(lang.battTypes) do
            form.addRow(2)
            form.addLabel({ label = type, width = 280 })
            checkboxIndices[i] = form.addCheckbox(battTypes[i] == 1, function(value)
                battTypes[i] = value and 0 or 1
                form.setValue(checkboxIndices[i], not value)
                system.pSave("batttypes", battTypes)
            end)
        end

        form.setButton(1, ":tools", DISABLED)
        form.setButton(2, ":edit", ENABLED)
    else
        if displayedBattery then
            form.setTitle(displayedBattery.label)
            form.addRow(2)
            form.addLabel({ label = lang.label })
            form.addTextbox(displayedBattery.label, 16, function(value)
                displayedBattery.label = value
                form.setTitle(value)
            end)
            form.addRow(2)
            form.addLabel({ label = lang.cells })
            form.addIntbox(displayedBattery.cells, 1, 64, 3, 0, 1, function(value) displayedBattery.cells = value end)
            form.addRow(2)
            form.addLabel({ label = lang.capacity })
            form.addIntbox(displayedBattery.capacity, 1, 32000, 1000, 0, 10, function(value) displayedBattery.capacity = value end)
            form.addRow(2)
            form.addLabel({ label = lang.cycles })
            form.addIntbox(displayedBattery.cycles, 0, 32000, 0, 0, 1, function(value) displayedBattery.cycles = value end)
        else
            form.setTitle(lang.batteries)
            for i = 1, #batteries do
                form.addLink(function()
                    displayedBattery = batteries[i]
                    form.reinit(2)
                end, { label = batteries[i].label .. ">>" })
            end
            form.setButton(1, ":tools", ENABLED)
            form.setButton(2, ":add", #batteries < 512 and ENABLED or DISABLED)
            form.setButton(3, ":delete", #batteries > 0 and ENABLED or DISABLED)
            form.setButton(4, ":up", ENABLED)
            form.setButton(5, ":down", ENABLED)
        end
    end
end

local function keyPressedSelect(keyCode)
    if keyCode == KEY_1 and #filteredBatteries > 0 then -- add one cycle to the focused battery
        filteredBatteries[form.getFocusedRow()].cycles = filteredBatteries[form.getFocusedRow()].cycles + 1
        form.reinit()
    elseif keyCode == KEY_2 and #filteredBatteries > 0 then -- subtract one cycle from the focused battery
        filteredBatteries[form.getFocusedRow()].cycles = math.max(filteredBatteries[form.getFocusedRow()].cycles - 1, 0)
        form.reinit()
    elseif keyCode == KEY_3 and currTypeIndex > 1 then -- go to previous battery type
        currTypeIndex = currTypeIndex - 1
        form.reinit()
    elseif keyCode == KEY_4 and currTypeIndex < #typeIndices then -- skip current battery type
        currTypeIndex = currTypeIndex + 1
        form.reinit()
    elseif (keyCode == KEY_5 or keyCode == KEY_ENTER) and #filteredBatteries > 0 then -- select focused battery and either go to the next type or close the form
        filteredBatteries[form.getFocusedRow()].cycles = filteredBatteries[form.getFocusedRow()].cycles + 1
        form.preventDefault()
        currTypeIndex = currTypeIndex + 1
        if currTypeIndex > #typeIndices then
            form.close()
        else
            form.reinit()
        end
    end
end

local function initSelectForm()
    form.setTitle(lang.battTypes[typeIndices[currTypeIndex]])
    for i = 1, #filteredBatteries do
        form.addRow(2)
        form.addLabel({ label = filteredBatteries[i].label })
        form.addLabel({ label = tostring(math.floor(filteredBatteries[i].cycles)), alignRight = true })
    end
    form.setButton(1, ":inc", ENABLED)
    form.setButton(2, ":dec", ENABLED)
    if #typeIndices > 0 then
        form.setButton(3, ":backward", currTypeIndex > 1 and ENABLED or DISABLED)
        form.setButton(4, ":forward", currTypeIndex < #typeIndices and ENABLED or DISABLED)
    end
    form.setButton(5, ":okBig", ENABLED)
end

local function init()
    minCells = system.pLoad("minCells", 2)
    maxCells = system.pLoad("maxCells", 3)
    minCapacity = system.pLoad("minCapa", 1000)
    maxCapacity = system.pLoad("maxCapa", 2000)
    selectSwitch = system.pLoad("selectsw")
    autoDetect = system.pLoad("autodec", 1) == 1
    battTypes = system.pLoad("batttypes") or getDefaultTypeSelection()
    local content = io.readall("Apps/BattCycles/batteries.jsn")
    if content then
        batteries = json.decode(content)
    else
        io.close(io.open("Apps/BattCycles/batteries.jsn", "w"))
        batteries = {}
    end
    updateFiltered()
    system.registerForm(1, MENU_APPS, lang.appName, initForm, keyPressed, nil, updateFiltered) -- updateFiltered is passed as the close-form callback
end

local function loop()
    local selectVal = selectSwitch and system.getInputsVal(selectSwitch) or nil
    local txTel = system.getTxTelemetry()
    local on = txTel.rx1Percent > 0 or txTel.RSSI[1] > 0 or txTel.RSSI[2] > 0
    -- show selection form if it is not already active and the switch was enabled or the receiver voltage is positive
    if autoDetect and form.getActiveForm() ~= 2 and ((selectVal == 1 and lastSelectVal == -1) or (on and not modelOn)) then
        typeIndices = {}
        for i = 1, #battTypes do
            if battTypes[i] == 1 then
                typeIndices[#typeIndices+1] = i
            end
        end
        if #typeIndices == 0 then
            system.messageBox(lang.noTypesSelected)
        else
            currTypeIndex = 1
            system.registerForm(2, 0, lang.selectTitle, initSelectForm, keyPressedSelect)
        end
    end
    lastSelectVal = selectVal
    modelOn = on
end

local function destroy()
    local file = io.open("Apps/BattCycles/batteries.jsn", "w")
    if file then
        io.write(file, json.encode(batteries))
        io.close(file)
    end
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.0.4", name = lang.appName }