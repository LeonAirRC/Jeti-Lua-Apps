--
-- Created by LeonAir RC
-- Date: 25.01.2021
--

local previousSwitch
local nextSwitch
local prevSwitchKey = "ap_prevSwitch"
local nextSwitchKey = "ap_nextSwitch"
local files -- ordered table of all audio files
local audioboxIndices -- ordered table of the form indices of the audiofile-boxes
local filesKey = "ap_files"
local topRows = 3 -- rows of the form that are not audiofile-boxes, used as an offset to transfer (form.focusedRow) -> (index of focused audio file)
local currFile -- index of currently selected file or 0 if no files are selected
local audioStartTime -- indicates the millisecond timestamp when the current replay was started. If nil no file is currently played
local lastPrevVal = 0 -- last value of the previousSwitch
local lastNextVal = 0 -- last value of the nextSwitch
local NONE = "" -- empty string constant to represent a not-yet selected file

-- translations
local locale = system.getLocale()
local appName = {en = "Audio Player", de = "Audio Player"}
local previousText = {en = "stop/previous", de = "Stop/zurück"}
local nextText = {en = "play/next", de = "Play/weiter"}
local fileText = {en = "Files", de = "Dateien"}

local function getTranslation(table)
    return table[locale] or table["en"]
end

local function playing()
    return audioStartTime ~= nil
end

local function splitString(str, sep)
    local t = {}
    for substr in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, substr)
    end
    return t
end

local function saveFiles()
    system.pSave(filesKey, table.concat(files, ";"))
end

local function playFile()
    if (currFile > 0 and currFile <= #files and not playing()) then
        system.playFile(files[currFile], AUDIO_BACKGROUND)
        audioStartTime = system.getTimeCounter()
    end
end

local function stopPlayback()
    system.stopPlayback(AUDIO_BACKGROUND)
    audioStartTime = nil
end

local function swapFiles(index) -- swaps files at indices [index] and [index+1]
    local temp = files[index]
    files[index] = files[index + 1]
    files[index + 1] = temp
    form.setValue(audioboxIndices[index], files[index])
    form.setValue(audioboxIndices[index + 1], files[index + 1])
end

local function onKeyPressed(keyCode)
    local focused = form.getFocusedRow() - topRows -- index of selected file
    if (keyCode == KEY_1 and focused > 1) then -- up: swap focused row with the row above
        if (playing() and (currFile == focused or currFile == focused - 1)) then -- stop playback if one of the swapped files is the current one
            stopPlayback()
        end
        swapFiles(focused - 1)
        form.setFocusedRow(form.getFocusedRow() - 1)
        saveFiles()
    elseif (keyCode == KEY_2 and focused > 0 and focused < #files) then -- down: swap focused row with the row below
        if (playing() and (currFile == focused or currFile == focused + 1)) then -- stop playback if one of the swapped files is the current one
            stopPlayback()
        end
        swapFiles(focused)
        form.setFocusedRow(form.getFocusedRow() + 1)
        saveFiles()
    elseif (keyCode == KEY_3 and (focused > 0 or currFile == 0) and #files < 64) then -- add file below current row
        table.insert(files, currFile == 0 and 1 or focused + 1, NONE) -- insert file below current index or at index 1 when no files are selected yet
        if (currFile > focused or currFile == 0) then -- if no files are selected yet or the current file is below the added row
            currFile = currFile + 1 -- increase currFile
        end
        form.reinit((#files == 1 and 1 or focused + 1) + topRows) -- set focused row
        saveFiles()
    elseif (keyCode == KEY_4 and focused > 0) then -- remove file
        if (playing() and currFile == focused) then -- stop playback if current file was deleted
            stopPlayback()
        end
        if (currFile == focused and focused == #files) then -- if the last file is deleted and is the current file
            currFile = #files == 1 and 0 or 1 -- if no files will be left set current file to 0, otherwise 1
        elseif (currFile > focused) then -- decrease current file if a file above is deleted
            currFile = currFile - 1
        end
        table.remove(files, focused)
        if (focused > #files) then
            form.setFocusedRow(form.getFocusedRow() - 1) -- set focused row to the row above if the last file was deleted
        end
        form.reinit()
        saveFiles()
    end
end

local function onPrevSwitchChanged(value)
    local switchval = system.getInputsVal(value)
    if (switchval and switchval ~= 0) then
        previousSwitch = value
        lastPrevVal = switchval
    else -- inputbox was cleared
        previousSwitch = nil
        lastPrevVal = 0
        stopPlayback()
    end
    system.pSave(prevSwitchKey, previousSwitch)
end

local function onNextSwitchChanged(value)
    local switchval = system.getInputsVal(value)
    if (switchval and switchval ~= 0) then
        nextSwitch = value
        lastNextVal = switchval
    else -- inputbox was cleared
        nextSwitch = nil
        lastNextVal = 0
    end
    system.pSave(nextSwitchKey, nextSwitch)
end

local function onAudiofileChanged(index, file)
    if (playing() and index == currFile) then
        stopPlayback()
    end
    files[index] = file
    saveFiles()
end

---------------------------------------------------------------

local function loop()
    local prevVal = system.getInputsVal(previousSwitch)
    local nextVal = system.getInputsVal(nextSwitch)

    if (playing() and (system.getTimeCounter() - audioStartTime) > 1000 and not system.isPlayback()) then   -- file has ended or was stopped by immediate audio
                                                                                                            -- Audio playback sometimes starts with a big enough delay that the next loop
                                                                                                            -- immediately executes this block, therefore a 1000ms time difference is required.
        audioStartTime = nil
        currFile = currFile == #files and 1 or (currFile + 1) -- go to next file
    end
    if (previousSwitch and prevVal == 1 and lastPrevVal ~= 1) then -- stop-switch was enabled
        if (playing()) then
            stopPlayback()
        else
            currFile = currFile == 1 and #files or (currFile - 1) -- go to previous file
        end
    elseif (nextSwitch and nextVal == 1 and lastNextVal ~= 1) then -- play-switch was enabled
        if (playing()) then
            stopPlayback()
            currFile = currFile == #files and 1 or (currFile + 1) -- go to next file
            playFile()
        elseif (currFile > 0) then
            playFile() -- play current file
        end
    end

    lastPrevVal = prevVal
    lastNextVal = nextVal
end

local function initForm(formID)
    form.addRow(2)
    form.addLabel({ label = getTranslation(previousText) })
    form.addInputbox(previousSwitch, false, onPrevSwitchChanged, { alignRight = true })
    form.addRow(2)
    form.addLabel({ label = getTranslation(nextText) })
    form.addInputbox(nextSwitch, false, onNextSwitchChanged, { alignRight = true })
    form.addLabel({ label = getTranslation(fileText), enabled = false, font = FONT_BOLD })
    audioboxIndices = {}
    for i,file in ipairs(files) do -- add a row for each file
        form.addRow(2)
        form.addLabel({ label = tostring(i) })
        audioboxIndices[i] = form.addAudioFilebox(file, function (f) onAudiofileChanged(i, f) end, { alignRight = true })
    end

    form.setButton(1, ":up", ENABLED)
    form.setButton(2, ":down", ENABLED)
    form.setButton(3, ":add", ENABLED)
    form.setButton(4, ":delete", ENABLED)

    if (formID > topRows) then -- focused row was passed as form id
        form.setFocusedRow(formID)
    end
end

local function init()
    files = splitString(system.pLoad(filesKey, ""), ";")
    previousSwitch = system.pLoad(prevSwitchKey)
    nextSwitch = system.pLoad(nextSwitchKey)
    currFile = #files == 0 and 0 or 1
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm, onKeyPressed)
end

local function destroy()
    stopPlayback()
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.0", name = getTranslation(appName) }