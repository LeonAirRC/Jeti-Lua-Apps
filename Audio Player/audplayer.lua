local prevSwitchKey = "ap_prevSwitch"
local nextSwitchKey = "ap_nextSwitch"
local playlistNamesKey = "ap_playlists"
local playlistFilesKey = "ap_files"
local playedPlaylistIndexKey = "ap_playlist"

local previousSwitch
local nextSwitch
local audioboxIndices
local textboxIndices
local currPlaybackFile -- index of the current file of the current playlist
local audioStartTime -- start time mark of the current audio file or nil if no file is played currently
local lastPrevVal
local lastNextVal
local playedPlaylistIndex -- index of the playlist currently played or nil if no playlist was selected yet. Playlists can be selected with key 3
local openedPlaylistIndex -- index of the playlist currently on display for editing or nil if the playlist and switch selection is currently on display
local playlistNames -- array of all playlist names
local playlistFiles -- array of all files of each playlist. files are joined with semicolons, eg: playlistFiles[1] = "abc.wav;def.wav;10.wav"
local openedFiles -- array of the files of the playlist that is currently on display, contains string as parametrized by the audiofileboxes' callback methods
local playedFiles -- array of the files of the selected playlist, contains string as parametrized by the audiofileboxes' callback methods

-- translations
local locale = system.getLocale()
local appName = {en = "Audio Player", de = "Audio Player"}
local previousText = {en = "stop/previous", de = "Stop/zurück"}
local nextText = {en = "play/next", de = "Play/weiter"}
local playlistsText = {en = "Playlists", de = "Wiedergabelisten"}
local deletePlaylistText = {en = "Delete playlist?", de = "Wirlich löschen?"}
local equalNamesText = {en = "Playlist labels cannot be equal", de = "Bezeichnungen müssen verschieden sein"}
local controlText = {en = "Switches", de = "Schalter"}

local function getTranslation(table)
    return table[locale] or table["en"]
end

local function table_contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local function splitString(str, sep)
    local t = {}
    for substr in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, substr)
    end
    return t
end

local function playing()
    return audioStartTime ~= nil
end

local function savePlaylistNames()
    system.pSave(playlistNamesKey, playlistNames)
end

local function savePlaylistFiles()
    system.pSave(playlistFilesKey, playlistFiles)
end

local function savePlayedPlaylistIndex()
    system.pSave(playedPlaylistIndexKey, playedPlaylistIndex)
end

local function saveOpenedFiles()
    playlistFiles[openedPlaylistIndex] = table.concat(openedFiles, ";")
    savePlaylistFiles()
end

local function playFile() -- starts playback of the current file as specified by 'playedPlaylistIndex' and 'currPlaybackFile'
    if (playedPlaylistIndex and currPlaybackFile ~= 0 and currPlaybackFile <= #playedFiles and not playing()) then
        system.playFile(playedFiles[currPlaybackFile], AUDIO_BACKGROUND)
        audioStartTime = system.getTimeCounter()
    end
end

local function stopPlayback()
    system.stopPlayback(AUDIO_BACKGROUND)
    audioStartTime = nil
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

local function onAudiofileChanged(index, value)
    if (openedPlaylistIndex == playedPlaylistIndex and currPlaybackFile == index) then
        stopPlayback()
    end
    openedFiles[index] = value
    saveOpenedFiles()
end

local function onPlaylistNameChanged(index, value)
    for i,playlist in ipairs(playlistNames) do
        if (i ~= index and playlist == value) then -- if another playlist has the same name
            form.setValue(textboxIndices[index], playlistNames[index]) -- restore the old name
            system.messageBox(getTranslation(equalNamesText))
            return
        end
    end
    playlistNames[index] = value
    savePlaylistNames()
end

local function swapFiles(index) -- swaps files at indices [index] and [index+1]
    local temp = openedFiles[index]
    openedFiles[index] = openedFiles[index + 1]
    openedFiles[index + 1] = temp
    form.setValue(audioboxIndices[index], openedFiles[index])
    form.setValue(audioboxIndices[index + 1], openedFiles[index + 1])
end

local function selectPlaylist(index)
    stopPlayback()
    playedPlaylistIndex = index
    playedFiles = splitString(playlistFiles[playedPlaylistIndex], ";")
    currPlaybackFile = #playedFiles == 0 and 0 or 1
    savePlayedPlaylistIndex()
end

local function updatePlayingFiles() -- called when the opened playlist is the playing playlist, updates the playedFiles array
    playedFiles = openedFiles
    playlistFiles[playedPlaylistIndex] = table.concat(playedFiles, ";")
    savePlaylistFiles()
end

local function onKeyPressed(keyCode)
    if (openedPlaylistIndex) then
        form.preventDefault()
        if (keyCode == KEY_5 or keyCode == KEY_ESC) then
            openedPlaylistIndex = nil
            openedFiles = nil
            form.reinit(playedPlaylistIndex)
        end
        local focused = form.getFocusedRow()

        if (keyCode == KEY_1 and #openedFiles < 32) then

            table.insert(openedFiles, math.min(focused, #openedFiles) + 1, "")
            saveOpenedFiles()
            if (playedPlaylistIndex == openedPlaylistIndex) then
                if (currPlaybackFile == 0 or currPlaybackFile > focused) then
                    currPlaybackFile = currPlaybackFile + 1
                end
                updatePlayingFiles()
            end
            form.reinit(math.min(focused + 1, #openedFiles))

        elseif (keyCode == KEY_2 and focused > 0) then

            if (playedPlaylistIndex == openedPlaylistIndex and currPlaybackFile == focused) then
                stopPlayback()
            end
            table.remove(openedFiles, focused)
            saveOpenedFiles()
            if (playedPlaylistIndex == openedPlaylistIndex) then
                if (currPlaybackFile == focused and currPlaybackFile == #openedFiles) then
                    currPlaybackFile = (#openedFiles == 0) and 0 or 1
                elseif (currPlaybackFile > focused) then
                    currPlaybackFile = currPlaybackFile - 1
                end
                updatePlayingFiles()
            end
            form.reinit(focused)

        elseif (keyCode == KEY_3 and focused > 1 and #openedFiles > 1) then

            if (playedPlaylistIndex == openedPlaylistIndex and (currPlaybackFile == focused or currPlaybackFile == focused - 1)) then
                stopPlayback()
            end
            swapFiles(focused - 1)
            form.setFocusedRow(focused - 1)
            saveOpenedFiles()
            if (playedPlaylistIndex == openedPlaylistIndex) then
                updatePlayingFiles()
            end

        elseif (keyCode == KEY_4 and focused > 0 and focused < #openedFiles and #openedFiles > 1) then

            if (playedPlaylistIndex == openedPlaylistIndex and (currPlaybackFile == focused or currPlaybackFile == focused + 1)) then
                stopPlayback()
            end
            swapFiles(focused)
            form.setFocusedRow(focused + 1)
            saveOpenedFiles()
            if (playedPlaylistIndex == openedPlaylistIndex) then
                updatePlayingFiles()
            end
        end
    else
        local focused = form.getFocusedRow()
        if (keyCode == KEY_1 and #playlistNames < 32) then

            local n = 1 -- create "playlist *" so that no name collision occurs
            while table_contains(playlistNames, "playlist " .. tostring(n)) do
                n = n + 1
            end
            table.insert(playlistNames, "playlist " .. tostring(n)) -- append new name
            savePlaylistNames()
            table.insert(playlistFiles, "") -- append empty list of files
            savePlaylistFiles()
            form.reinit(#playlistNames)

        elseif (keyCode == KEY_2 and focused > 0 and focused <= #playlistNames) then

            if (form.question(getTranslation(deletePlaylistText), nil, nil, 10000, false, 500) ~= 1) then
                return
            end
            if (playedPlaylistIndex == focused) then -- if the playing playlist is deleted
                stopPlayback()
                playedFiles = nil
                playedPlaylistIndex = nil
                savePlayedPlaylistIndex()
            elseif (playedPlaylistIndex and playedPlaylistIndex > focused) then
                playedPlaylistIndex = playedPlaylistIndex - 1
                savePlayedPlaylistIndex()
            end
            table.remove(playlistNames, focused)
            savePlaylistNames()
            table.remove(playlistFiles, focused)
            savePlaylistFiles()
            form.reinit()

        elseif (keyCode == KEY_3 and focused > 0 and focused <= #playlistNames) then

            if (focused ~= playedPlaylistIndex) then
                selectPlaylist(focused)
                form.reinit(form.getFocusedRow())
            end

        elseif (keyCode == KEY_4 and focused > 0 and focused <= #playlistNames) then

            openedPlaylistIndex = focused
            openedFiles = splitString(playlistFiles[openedPlaylistIndex], ";")
            form.reinit()
        end
    end
end

local function initForm(formID)
    if (openedPlaylistIndex) then
        form.setTitle(playlistNames[openedPlaylistIndex])
        audioboxIndices = {}
        for i,file in ipairs(openedFiles) do
            form.addRow(2)
            form.addLabel({ label = tostring(i) })
            audioboxIndices[i] = form.addAudioFilebox(file, function (f) onAudiofileChanged(i, f) end, { alignRight = true })
        end

        form.setButton(1, ":add", (#openedFiles < 32) and ENABLED or DISABLED)
        form.setButton(2, ":delete", (#openedFiles > 0) and ENABLED or DISABLED)
        form.setButton(3, ":up", ENABLED)
        form.setButton(4, ":down", ENABLED)
    else
        form.setTitle(getTranslation(playlistsText))
        textboxIndices = {}
        for i,playlist in ipairs(playlistNames) do
            form.addRow(1)
            textboxIndices[i] = form.addTextbox(playlist, 32, function (value) onPlaylistNameChanged(i, value) end, { font = (i == playedPlaylistIndex) and FONT_BOLD or FONT_NORMAL }) -- bold font for selected playlist
        end
        -- form.addRow(1)
        form.addLabel({ label = getTranslation(controlText), enabled = false, font = FONT_BOLD })
        form.addRow(2)
        form.addLabel({ label = getTranslation(previousText) })
        form.addInputbox(previousSwitch, false, onPrevSwitchChanged, { alignRight = true })
        form.addRow(2)
        form.addLabel({ label = getTranslation(nextText) })
        form.addInputbox(nextSwitch, false, onNextSwitchChanged, { alignRight = true })

        form.setButton(1, ":add", (#playlistNames < 32) and ENABLED or DISABLED)
        form.setButton(2, ":delete", (#playlistNames > 0) and ENABLED or DISABLED)
        form.setButton(3, ":play", ENABLED)
        form.setButton(4, "Edit", ENABLED)
    end
    form.setFocusedRow(formID)
end

local function loop()
    local prevVal = system.getInputsVal(previousSwitch)
    local nextVal = system.getInputsVal(nextSwitch)

    if (playedPlaylistIndex) then -- playlist selected (and possibly playing)
        if (playing() and (system.getTimeCounter() - audioStartTime) > 1000 and not system.isPlayback()) then   -- file has ended or was stopped by immediate audio
                                                                                                                -- Audio playback sometimes starts with a big enough delay that the next loop
                                                                                                                -- immediately executes this block, therefore a 1000ms time difference is required
                                                                                                                -- to prevent the program thinking that the playback has already stopped
            audioStartTime = nil
            currPlaybackFile = currPlaybackFile == #playedFiles and 1 or (currPlaybackFile + 1) -- go to next file
        end
        if (previousSwitch and prevVal == 1 and lastPrevVal ~= 1) then -- stop-switch was enabled
            if (playing()) then
                stopPlayback()
            else
                currPlaybackFile = currPlaybackFile == 1 and #playedFiles or (currPlaybackFile - 1) -- go to previous file
            end
        elseif (nextSwitch and nextVal == 1 and lastNextVal ~= 1) then -- play-switch was enabled
            if (playing()) then
                stopPlayback()
                currPlaybackFile = currPlaybackFile == #playedFiles and 1 or (currPlaybackFile + 1) -- go to next file
                playFile()
            elseif (currPlaybackFile > 0) then
                playFile() -- play current file
            end
        end
    end

    lastPrevVal = prevVal
    lastNextVal = nextVal
end

local function init()
    playlistNames = system.pLoad(playlistNamesKey, {})
    playlistFiles = system.pLoad(playlistFilesKey, {})
    playedPlaylistIndex = system.pLoad(playedPlaylistIndexKey)
    if (playedPlaylistIndex) then
        selectPlaylist(playedPlaylistIndex)
    end
    previousSwitch = system.pLoad(prevSwitchKey)
    nextSwitch = system.pLoad(nextSwitchKey)
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm, onKeyPressed)
end

local function destroy()
    stopPlayback()
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.1", name = getTranslation(appName) }