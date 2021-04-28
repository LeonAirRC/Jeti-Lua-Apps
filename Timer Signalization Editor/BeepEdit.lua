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

local locale = system.getLocale()
local appName = {en = "Beep Editor", de = "Beep Editor", cz = "Zvukový editor"}
local selectFileText = {en = "Select file", de = "Datei auswählen", cz = "Zvolte soubor"}
local fileErrorText = {en = "The file could not be read", de = "Die Datei konnte nicht gelesen werden", cz = "Soubor nelze přečíst"}
local cannotInsertText = {en = "Cannot insert a row here", de = "Hier kann keine Zeile eingefügt werden", cz = "Nelze vložit řádek zde"}
local saveErrorText = {en = "The changes could\nnot be saved", de = "Die Änderungen konnten nicht\ngespeichert werden", cz = "Změny nelze uložit"}
local restartText = {en = "Restart the transmitter for the\nchanges to take effect", de = "Die Änderungen werden erst nach\neinem Neustart wirksam", cz = "Změny se projeví až po restartu"}
local tableHeader = {en = {"Time", "Type", "Freq", "#", "Length"}, de = {"Zeit", "Typ", "Freq", "#", "Länge"}, cz = {"čas", "typ", "frek", "#", "trvání"}}
local tableHeader2 = {en = "File", de = "Datei", cz = "Soubor"}
local tableHeaderWidth = {60, 50, 75, 45, 80}
local saveChangesText = {en = "Save Changes?", de = "Änderungen speichern?", cz = "uložit změny?"}

local DEFAULT_TIME = 0
local DEFAULT_TYPE = 1
local DEFAULT_FREQ = 4000
local DEFAULT_CNT = 1
local DEFAULT_LENGTH = 500
local DEFAULT_FILE = ""
local MIN_INT = -32768 -- min and max values for intboxes
local MAX_INT = 32767


local files = {"TimerB1.jsn", "TimerB2.jsn", "TimerV.jsn"}
local file -- number of selected file (1-3) or nil if the form shows the file selection
local elements -- list
local changed
local timeIndices

local function getTranslation(table)
    return table[locale] or table["en"]
end

-- forces a value into an allowed range of numbers
-- If 'value' is smaller than 'lowest' then lowest is returned, equivalent for 'highest'. If 'value' is between the limits it is returned
local function toRange(value, lowest, highest)
    return math.min(highest, math.max(lowest, value)) -- returned value is never higher than 'highest' but can be smaller than 'lowest' if lowest > highest
end

------------------------------------------------------------------------------
-- Callback function if the timestemp of an element has changed.
-- Change is not applied if the time exceeds the previous or following element
------------------------------------------------------------------------------
local function timeChanged(index, value)
    if (index > 1 and value <= elements[index - 1]["Time"]) then
        form.setValue(timeIndices[index], elements[index]["Time"])
    elseif (index < #elements and value >= elements[index + 1]["Time"]) then
        form.setValue(timeIndices[index], elements[index]["Time"])
    else
        elements[index]["Time"] = value
        changed = true
    end
end

local function typeChanged(index, value)
    elements[index]["Type"] = value
    if (value == 1) then
        elements[index]["File"] = nil
        elements[index]["Freq"] = DEFAULT_FREQ
        elements[index]["Cnt"] = DEFAULT_CNT
        elements[index]["Length"] = DEFAULT_LENGTH
    else
        elements[index]["Freq"] = nil
        elements[index]["Cnt"] = nil
        elements[index]["Length"] = nil
        elements[index]["File"] = DEFAULT_FILE
    end
    changed = true
    collectgarbage()
    form.reinit(form.getFocusedRow())
end

local function frequencyChanged(index, value)
    elements[index]["Freq"] = value
    changed = true
end

local function countChanged(index, value)
    elements[index]["Cnt"] = value
    changed = true
end

local function lengthChanged(index, value)
    elements[index]["Length"] = value
    changed = true
end

local function fileChanged(index, value)
    elements[index]["File"] = value
    changed = true
end

---------------------------------------------------------------------------------------
-- Saves the current file. json.encode is not used to allow a readable multiline output
---------------------------------------------------------------------------------------
local function save()
    if (not file or not changed) then
        return
    end
    local fileObject = io.open("/Config/" .. files[file], "w")
    if (not fileObject) then
        system.messageBox(getTranslation(saveErrorText))
        return
    end

    io.write(fileObject, "[\n")
    for i,element in ipairs(elements) do
        if (element["Type"] == 1) then
            io.write(fileObject, "{\"Time\":", math.floor(element["Time"]), ",\"Type\":1,\"Freq\":", math.floor(element["Freq"]), ",\"Cnt\":", math.floor(element["Cnt"]), ",\"Length\":", math.floor(element["Length"]) .. "}")
        else
            io.write(fileObject, "{\"Time\":", math.floor(element["Time"]), ",\"Type\":2,\"File\":\"", element["File"], "\"}")
        end
        if (i < #elements) then
            io.write(fileObject, ",\n")
        else
            io.write(fileObject, "\n")
        end
    end
    io.write(fileObject, "]")
    io.close(fileObject)
    system.messageBox(getTranslation(restartText))
    collectgarbage()
end

local function keyPressed(keyCode)
    if (file) then -- the list of elements is displayed currently
        form.preventDefault()
        local focused = form.getFocusedRow() - 2
        if (keyCode == KEY_1 and focused > 1) then -- swap focused element with the row above
            local element = elements[focused - 1] -- swap elements
            elements[focused - 1] = elements[focused]
            elements[focused] = element
            local time = elements[focused - 1]["Time"] -- swap times
            elements[focused - 1]["Time"] = elements[focused]["Time"]
            elements[focused]["Time"] = time
            changed = true
            form.reinit(focused + 1) -- go one row up
        elseif (keyCode == KEY_2 and focused > 0 and focused < #elements) then -- swap focused element with the row above
            local element = elements[focused] -- swap elements
            elements[focused] = elements[focused + 1]
            elements[focused + 1] = element
            local time = elements[focused]["Time"] -- swap times
            elements[focused]["Time"] = elements[focused + 1]["Time"]
            elements[focused + 1]["Time"] = time
            changed = true
            form.reinit(focused + 3) -- go one row down
        elseif (keyCode == KEY_3 and (focused > 0 or #elements == 0) and #elements < 100) then -- add element
            local minTime = focused > 0 and (elements[focused]["Time"] + 1) or MIN_INT -- min and max values are calculated to find a default value for the new element
            local maxTime = (focused > 0 and focused < #elements) and (elements[focused + 1]["Time"] - 1) or MAX_INT
            if (minTime <= maxTime) then -- element cannot be added if there is no free "timeslot" between the two adjacent rows
                table.insert(elements, focused < 1 and 1 or (focused + 1), { Time = toRange(DEFAULT_TIME, minTime, maxTime), Type = 1, Freq = DEFAULT_FREQ, Cnt = DEFAULT_CNT, Length = DEFAULT_LENGTH })
                changed = true
                form.reinit(focused + 3)
            else
                system.messageBox(getTranslation(cannotInsertText))
            end
        elseif (keyCode == KEY_4 and focused > 0) then -- remove focused element
            table.remove(elements, focused)
            changed = true
            form.reinit(math.min(#elements, focused) + 2) -- focus row below if the last element was deleted
        elseif (keyCode == KEY_5) then -- OK pressed
            if (changed) then
                save()
            end
            elements = nil
            file = nil
            timeIndices = nil
            form.reinit()
        elseif (keyCode == KEY_ESC) then -- ESC pressed
            if (changed) then
                local result = form.question(getTranslation(saveChangesText), nil, nil, 0, false, 0)
                if (result == 1) then
                    save()
                end
            end
            elements = nil
            file = nil
            timeIndices = nil
            form.reinit()
        end
    end
    collectgarbage()
end

--------------------------------------------------------------------------------
-- list of elements is displayed as a table and the row 'formID' is focused
--------------------------------------------------------------------------------
local function initForm(formID)
    form.setTitle("")
    if (file) then -- a file is selected
        if (not elements) then -- load elements from file if not yet loaded
            local content = io.readall("Config/" .. files[file]) -- read content of file
            if (not content) then
                system.messageBox(getTranslation(fileErrorText))
                file = nil
                form.reinit()
                return
            end
            content = string.gsub(content, "[\r\n]", "")
            elements = json.decode(content) -- remove newline characters and decode

            for i = 2, #elements do -- Sorting the elements by time (ascending). Insertion-sort is used because the table is usually already sorted
                local j = i
                while (j > 1 and elements[j - 1]["Time"] > elements[i]["Time"]) do
                    j = j - 1
                end
                if (j ~= i) then
                    local element = elements[i]
                    table.remove(elements, i)
                    table.insert(elements, j, element)
                end
            end -- insertion-sort end
        end

        form.addRow(5)
        for i, text in ipairs(getTranslation(tableHeader)) do
            form.addLabel({ label = text, font = FONT_BOLD, enabled = false, width = tableHeaderWidth[i] })
        end
        form.addRow(2)
        form.addSpacer(tableHeaderWidth[1] + tableHeaderWidth[2], 0)
        form.addLabel({ label = getTranslation(tableHeader2), font = FONT_BOLD, enabled = false })
        timeIndices = {}
        for i, element in ipairs(elements) do
            form.addRow(element["Type"] == 1 and 5 or 3) -- 5 intboxes for beeps and 3 boxes for audio file entries
            local minTime = i > 1 and (elements[i - 1]["Time"] + 1) or MIN_INT -- calculate minimum and maximum values for the new default value
            local maxTime = i < #elements and (elements[i + 1]["Time"] - 1) or MAX_INT
            timeIndices[i] = form.addIntbox(toRange(element["Time"], minTime, maxTime), MIN_INT, MAX_INT, toRange(DEFAULT_TIME, minTime, maxTime), 0, 1, function (value) timeChanged(i, value) end,
                                            { width = tableHeaderWidth[1] })
            form.addIntbox(element["Type"], 1, 2, DEFAULT_TYPE, 0, 1, function (value) typeChanged(i, value) end, { width = tableHeaderWidth[2] })
            if (element["Type"] == 1) then
                form.addIntbox(element["Freq"], 200, 10000, DEFAULT_FREQ, 0, 1, function (value) frequencyChanged(i, value) end, { width = tableHeaderWidth[3] })
                form.addIntbox(element["Cnt"], 1, 10, DEFAULT_CNT, 0, 1, function (value) countChanged(i, value) end, { width = tableHeaderWidth[4] })
                form.addIntbox(element["Length"], 20, 10000, DEFAULT_LENGTH, 0, 10, function (value) lengthChanged(i, value) end, { width = tableHeaderWidth[5] })
            else
                form.addAudioFilebox(element["File"], function (value) fileChanged(i, value) end, { width = tableHeaderWidth[3]  + tableHeaderWidth[4] + tableHeaderWidth[5] })
            end
        end
        form.setFocusedRow(formID or 1)
        form.setButton(1, ":up", ENABLED)
        form.setButton(2, ":down", ENABLED)
        form.setButton(3, ":add", ENABLED)
        form.setButton(4, ":delete", ENABLED)
    else
        form.addLabel({ label = getTranslation(selectFileText), font = FONT_BOLD })
        for i, filename in ipairs(files) do
            form.addLink(function ()
                file = i
                changed = false
                form.reinit()
            end, { label = filename .. ">>" })
        end
        for i = 1,4 do
            form.setButton(i, "", 3)
        end
        form.setFocusedRow(1)
    end
end

local function init()
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm, keyPressed)
end

local function destroy()
    elements = nil
    collectgarbage()
end

return { init = init, destroy = destroy, author = "LeonAir RC", version = "1.1", name = getTranslation(appName) }