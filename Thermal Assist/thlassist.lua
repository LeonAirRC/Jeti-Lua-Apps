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

local MAIN_FORM = 1
local SENSORS_FORM = 2
local ALGORITHM_FORM = 3
local TELEMETRY_FORM = 4
local currForm

local minSequenceLengthKey = "ta_minsequence"
local maxSequenceLengthKey = "ta_maxsequence"
local bestSequenceLengthKey = "ta_best"
local enableSwitchKey = "ta_enable"
local zoomSwitchKey = "ta_zoom"
local lonSensorIndexKey = "ta_lons"
local latSensorIndexKey = "ta_lats"
local sensorIndicesKey = "ta_sens"
local sensorModeKey = "ta_smode"
local delayKey = "ta_delay"
local algorithmKey = "ta_alg"
local readingInteravlKey = "ta_readingint"
local intervalKey = "ta_interval"
local estimateClimbKey = "ta_eclmb"
local circleRadiusKey = "ta_radius"
local minZoomKey = "ta_minzoom"
local maxZoomKey = "ta_maxzoom"
local algorithmSwitchKey = "ta_algsw"
local appModeSwitchKey = "ta_amode"
local searchModeForceKey = "ta_smforce"

local sensorLabelIndex, sensorInputIndex, minZoomIndex, maxZoomIndex, zoomInputboxIndex, estimateCheckboxIndex, algorithmSelectIndex, algorithmSwitchInputIndex, searchModeForceIndex
local abs = math.abs -- minimizes calls to math lib

local minSequenceLength     -- the minimal amount of gps points required for a speech output
local maxSequenceLength     -- the maximum amount of gps points. This limit prevents the readings array from becoming too long if there is no full 360° turn on the path
local bestSequenceLength    -- length of the subsequences that are examined to get the highest climb rate on the path
local enableSwitch          -- sensor reading and speech output are disabled if this switch is defined and in off position
local zoomSwitch            -- switch that can be used for manual zoom. When in -1 position, the autozoom is used.
local latSensorIndex        -- selected latitude sensor
local lonSensorIndex        -- selected longitude sensor
local sensorIndices         -- table with two entries representing - index 1: selected vario sensor index - index 2: selected altitude sensor index
local delay                 -- [int] the number of steps by which then vario values are shifted back in time
local sensorMode            -- mode 1: vario, mode 2: altitude difference
local algorithm             -- algorithm 1: best subsequence, algorithm 2: weighted vectors, algorithm 3: weighted vectors [bias]
local readingInterval   -- interval of sensor readings [ms]
local interval          -- interval of speech ouputs [s]
local estimateClimb     -- true if the estimated climb rate at 'bestPoint' should be computed
local circleRadius      -- radius of the circles in the telemetry frame in px per m/s
local minZoom, maxZoom  -- zoom range for the zoom switch
local algorithmSwitch   -- switch to select the algorithm in flight
local appModeSwitch     -- switch to toggle search mode
local searchModeForce   -- [boolean] true if the best-subsequence algorithm should always be used in search mode
local zoom = 1          -- current zoom
local switchOn          -- [boolean] saves the last state of the enable switch
local bestPoint         -- [GpsPoint] the best point on the path
local bestClimb         -- the (expected) climb at the best point, only valid if 'bestPoint ~= nil'

local gpsSensorIDs      -- array of the gps sensor ids, each index contains the sensor's id that corresponds to the entry in gpsSensorLabels at the same index
local gpsSensorParams   -- array of the gps sensor params, also corresponding to gpsSensorLabels
local otherSensorIDs    -- array of the single-value sensor ids
local otherSensorParams -- array of the single-value sensor params
local gpsSensorLabels   -- array of strings representing all params of gps sensors
local otherSensorLabels -- array of strings represensting all params of single-value sensors

local gpsReadings       -- array of GpsPoints representing the most recent sensor readings. New values are always inserted at index 1
local sensorReadings    -- array of vario or altitude values
local avgPoint          -- GpsPoint that has the average lat/lon values of all points in 'gpsReadings'
local lastTime          -- time of the last reading [ms]
local lastSpeech        -- time of the last speech output [ms]
local lastAltitude      -- last altitude, only used in sensor mode 2

-- translations
local locale = system.getLocale()
local appName = {en = "Thermal Assistant", de = "Thermikassistent", cz = "Tepelný asistent"}
local sensorsFormTitle = {en = "Sensors", de = "Sensoren", cz = "Senzory"}
local algorithmsFormTitle = {en = "Algorithm", de = "Algorithmus", cz = "algoritmus"}
local telemetryFormTitle = {en = "Telemetry frame", de = "Telemetriefenster", cz = "okno telemetrie"}
local minSequenceLengthText = {en = "Minimum sequence length", de = "Minimale Sequenzlänge", cz = "minimální délka sekvence"}
local maxSequenceLengthText = {en = "Maximum sequence length", de = "Maximale Sequenzlänge", cz = "maximální délka sekvence"}
local bestSequenceLengthText = {en = "Optimal subsequence length", de = "Länge optimale Teilsequenz", cz = "Optimální délka subsekvence"}
local enableSwitchText = {en = "Switch", de = "Switch", cz = "vypínač"}
local zoomSwitchText = {en = "Zoom", de = "Zoom", cz = "Zvětšení"}
local lonInputText = {en = "Longitude", de = "Längengrad", cz = "zeměpisná délka"}
local latInputText = {en = "Latitude", de = "Breitengrad", cz = "zeměpisná šířka"}
local sensorModeText = {en = "Mode", de = "Modus", cz = "Režim"}
local sensorInputText = {{en = "Vario EX", de = "Vario EX", cz = "vario EX"}, {en = "Altitude EX", de = "Höhe EX", cz = "výška EX"}}
local modeSelectionText = {en = {"Vario", "Altitude difference"}, de = {"Variometer", "Höhendifferenz"}, cz = {"variometr", "výškový rozdíl"}}
local delayText = {en = "Delay", de = "Verzögerung", cz = "zpoždění"}
local algorithmText = {en = "Algorithm", de = "Algorithmus", cz = "algoritmus"}
local algorithSelectionText = {en = {"Best subsequence", "Weighted vectors", "Weighted vectors [bias]"}, de = {"Beste Teilsequenz", "Gewichtete Vektoren", "Gewichtete Vektoren [Bias]"},
                                cz = {"nejlepší dílčí sekvence", "vážené vektory", "vážené vektory [zaujatost]"}}
local readingsText = {en = "Reading interval", de = "Messintervall", cz = "Interval měření"}
local intervalText = {en = "Announcement interval", de = "Ansageintervall", cz = "Interval oznámení"}
local estimateClimbText = {en = "Expected climb rate", de = "Erwartetes Steigen", cz = "Očekávaná rychlost stoupání"}
local circleRadiusText = {en = "Circle radius [px / m/s]", de = "Kreisradius [px / m/s]", cz = "Poloměr kruhu [px / ms]"}
local zoomRangeText = {en = "Zoom range", de = "Zoombereich", cz = "rozsah zvětšení"}
local searchModeText = {en = "Toggle search mode", de = "Suchmodus umschalten", cz = "Přepnout režim vyhledávání"}
local searchModeForceText = {en = "Always use alg. 1 in search mode", de = "Im Suchmodus immer Alg. 1 nutzen", cz = "použijte alg. 1 v režimu vyhledávání"}

local function getTranslation(table)
    return table[locale] or table["en"]
end

-----------------------------------------
-- clear all values, go to initial state
-----------------------------------------
local function reset()
    gpsReadings = {}    -- delete all points
    sensorReadings = {}
    avgPoint = nil
    bestPoint = nil
    bestClimb = nil
    lastTime = system.getTimeCounter()
    lastSpeech = lastTime
    lastAltitude = nil
end

-------------------
-- callback methods
-------------------

local function onSensorModeChanged(value)
    sensorMode = value
    reset()
    form.setProperties(sensorLabelIndex, { label = getTranslation(sensorInputText[sensorMode]) })
    form.setValue(sensorInputIndex, sensorIndices[sensorMode] + 1) -- add 1 to the value to compensate the ... option
    system.pSave(sensorModeKey, sensorMode)
end

local function onLatSensorChanged(value)
    latSensorIndex = value - 1  -- reduce by 1 to compensate the ... option
    system.pSave(latSensorIndexKey, latSensorIndex)
end

local function onLonSensorChanged(value)
    lonSensorIndex = value - 1  -- reduce by 1 to compensate the ... option
    system.pSave(lonSensorIndexKey, lonSensorIndex)
end

local function onOtherSensorChanged(value)
    sensorIndices[sensorMode] = value - 1   -- reduce by 1 to compensate the ... option
    system.pSave(sensorIndicesKey, sensorIndices)
end

local function onDelayChanged(value)
    delay = value
    reset()
    system.pSave(delayKey, delay)
end

local function onAlgorithmChanged(value)
    algorithm = value
    -- reset()
    system.pSave(algorithmKey, algorithm)
end

local function onEnableSwitchChanged(value)
    enableSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave(enableSwitchKey, enableSwitch)
end

local function onAppModeSwitchChanged(value)
    appModeSwitch = system.getInputsVal(value) ~= 0.0 and value or nil
    system.pSave(appModeSwitchKey, appModeSwitch)
end

local function onZoomSwitchChanged(value)
    zoomSwitch = value
    system.pSave(zoomSwitchKey, zoomSwitch)
end

local function onMinSequenceLengthChanged(value)
    minSequenceLength = value
    reset()
    system.pSave(minSequenceLengthKey, minSequenceLength)
end

local function onMaxSequenceLengthChanged(value)
    maxSequenceLength = value
    reset()
    system.pSave(maxSequenceLengthKey, maxSequenceLength)
end

local function onBestSequenceLengthChanged(value)
    bestSequenceLength = value
    reset()
    system.pSave(bestSequenceLengthKey, bestSequenceLength)
end

local function onReadingIntervalChanged(value)
    readingInterval = value
    reset()
    system.pSave(readingInteravlKey, readingInterval)
end

local function onIntervalChanged(value)
    interval = value
    reset()
    system.pSave(intervalKey, interval)
end

local function onEstimateClimbChanged(value)
    estimateClimb = not value
    form.setValue(estimateCheckboxIndex, estimateClimb)
    system.pSave(estimateClimbKey, estimateClimb and 1 or 0)
end

local function onCircleRadiusChanged(value)
    circleRadius = value
    system.pSave(circleRadiusKey, circleRadius)
end

local function onMinZoomChanged(value)
    if value <= maxZoom then
        minZoom = value
        system.pSave(minZoomKey, minZoom)
    else
        form.setValue(minZoomIndex, minZoom)
    end
end

local function onMaxZoomChanged(value)
    if value >= minZoom then
        maxZoom = value
        system.pSave(maxZoomKey, maxZoom)
    else
        form.setValue(maxZoomIndex, maxZoom)
    end
end

local function onAlgorithmSwitchChanged(value)
    algorithmSwitch = value
    system.pSave(algorithmSwitchKey, algorithmSwitch)
end

local function onSearchModeForceChanged(value)
    searchModeForce = not value
    form.setValue(searchModeForceIndex, searchModeForce)
    system.pSave(searchModeForceKey, searchModeForce and 1 or 0)
end

-------------------------------------------------------------------------
-- shortens the sequence of gps points and the associated sensor readings
-- returns true if and only if a turn of at least 360° was detected
-------------------------------------------------------------------------
local function filterReadings()
    while #sensorReadings > maxSequenceLength do -- remove excessive values
        table.remove(gpsReadings)
        table.remove(sensorReadings)
    end
    if system.getInputsVal(appModeSwitch) == 1 then -- when search mode is enabled
        return false -- skip further filtering by returning false
    end
                    -- track the flight path until the sum of bends is greater than 360°. Therefore the angles at all inner points are added
    local i = 2     -- the current angle is made of the points (i-1),(i),(i+1), thus the angle at point i is calculated in each iteration
    local sum = 0   -- sum of angles
    while i < #gpsReadings and abs(sum) < 360 do    -- loop until i is the second last point or the path contains a 360° turn
        local angle = gps.getBearing(gpsReadings[i], gpsReadings[i - 1]) - gps.getBearing(gpsReadings[i + 1], gpsReadings[i])   -- calculate the difference between bearings i relative to (i-1) and (i+1) relative to i
        if angle < -180 then angle = angle + 360        -- correct angle to be within -180° and +180°
        elseif angle > 180 then angle = angle - 360 end
        sum = sum + angle   -- add to sum
        i = i + 1
    end
    for _ = 1, #gpsReadings - math.max(i, minSequenceLength) do -- delete all points older than the i-th point, while not passing a minimum length
        table.remove(gpsReadings)
        table.remove(sensorReadings)
    end
    collectgarbage()
    return sum >= 360
end

-------------------------------------------------------------------------------------------------------
-- Announcement of the bearing and distance to the optimal point.
-- The expected climb rate at that point is also annouced if the best-subsequence algorith is selected.
-------------------------------------------------------------------------------------------------------
local function speechOutput()
    if avgPoint and bestPoint and #sensorReadings >= minSequenceLength and (algorithm ~= 1 or #sensorReadings >= bestSequenceLength) then
        local relPoint = (appModeSwitch and system.getInputsVal(appModeSwitch) == 1) and gpsReadings[1] or avgPoint -- use current position in search mode and the average otherwise
        local relocationBearing = gps.getBearing(relPoint, bestPoint)   -- bearing from the current center point towards the optimal point
        local relocationDistance = gps.getDistance(relPoint, bestPoint) -- distance from the current center point to the optimal point
        system.playNumber(relocationBearing, 0, string.char(176))       -- ° char as unicode
        system.playNumber(relocationDistance, 0, "m")
        if bestClimb then
            system.playNumber(bestClimb, 2, "m/s") -- play optimal climb
        end
        collectgarbage()
    end
end

---------------------------------------------------------------------------------
-- Estimates the climb rate at the given point based on the existing data points.
-- Uses the inverse square of distances to the point as a weight.
---------------------------------------------------------------------------------
local function estimateClimbRate(point)
    local sum = 0       -- sum of weighted climb rates
    local weightSum = 0 -- sum of weights
    for i = 1, #gpsReadings - delay do
        local dist = gps.getDistance(point, gpsReadings[i + delay])
        if dist < 0.1 then -- avoid division by 0 at the inverse square
            return sensorReadings[i]
        end
        local weight = 1 / (dist * dist)
        weightSum = weightSum + weight
        sum = sum + weight * sensorReadings[i]
    end
    return sum / weightSum
end

--------------------------------------------------------
-- sets 'bestPoint' according to the selected algorithm
-- and calls 'estimateClimbRate' if enabled
--------------------------------------------------------
local function calcBestPoint(fullTurn)
    collectgarbage()
    local alg1 = searchModeForce and system.getInputsVal(appModeSwitch) == 1 -- true if searchMode is enabled and algorithm 1 should be used
    if (algorithm == 1 or alg1) and #sensorReadings >= math.max(minSequenceLength, bestSequenceLength) + delay then -- best subsequence

        local sums = {} -- finding the best subsequence, sums[i] is the sum of the following 'bestSequenceLength' vario values
        sums[1] = 0
        for i = 1, bestSequenceLength do sums[1] = sums[1] + sensorReadings[i] end  -- calculate the first sum
        for i = 2, #sensorReadings - bestSequenceLength + 1 do
            table.insert(sums, i, sums[i - 1] + sensorReadings[i + bestSequenceLength - 1] - sensorReadings[i - 1]) -- calculate all other sums
        end
        if fullTurn then                                                            -- if a full turn was detected:
            for i = #sensorReadings - bestSequenceLength + 2, #sensorReadings do    -- calculate the last sums that exceed the array's last element and continue at the front
                table.insert(sums, i, sums[i - 1] + sensorReadings[i + bestSequenceLength - 1 - #sensorReadings] - sensorReadings[i - 1])
            end
        end
        -- find the highest sum
        local best = 1
        for i = 2, #sums do
            if sums[i] > sums[best] then best = i end
        end
        -- get center point of the best subsequence
        if fullTurn and best + delay + (bestSequenceLength - 1 // 2) > #sensorReadings then -- special case where the middle of the chosen subsequence exceeds the array's end
            bestPoint = gpsReadings[best + delay + (bestSequenceLength - 1) // 2 - #sensorReadings]
        else
            bestPoint = gpsReadings[best + delay + (bestSequenceLength - 1) // 2]   -- take the middle point of the best subsequence
        end
        bestClimb = sums[best] / bestSequenceLength

    elseif algorithm == 2 and (not alg1) and #sensorReadings >= minSequenceLength + delay then -- weighted vectors

        local varioSum = 0 -- sum of the absolute values of all climb rates
        for i = 1, #sensorReadings - delay do varioSum = varioSum + abs(sensorReadings[i]) end
        if varioSum == 0.0 then bestPoint = avgPoint -- all numbers in 'sensorReadings' are zeros, thus no better point can be determined - this avoids division by 0
        else
            local latSum, lonSum = 0,0  -- sums of latitudes and longitudes
            local centerLat, centerLon = gps.getValue(avgPoint)
            for i = 1, #gpsReadings - delay do
                local lat,lon = gps.getValue(gpsReadings[i + delay])
                latSum = latSum + sensorReadings[i] * (lat - centerLat) -- the sum of weights (sensorReadings[1..n] / varioSum) can be less than 1
                lonSum = lonSum + sensorReadings[i] * (lon - centerLon) -- hence the avg vector (centerLat,centerLon) cannot be reduced and has to be subtracted here, then added later
            end
            bestPoint = gps.newPoint(centerLat + latSum / varioSum, centerLon + lonSum / varioSum) -- best point is the weighted average
        end
        bestClimb = estimateClimb and estimateClimbRate(bestPoint) or nil

    elseif algorithm == 3 and (not alg1) and #sensorReadings >= minSequenceLength then -- weighted vectors [bias]

        local bias = 0 -- the lowest vario value in 'sensorReadings' and at most 0
        local varioSum = 0  -- sum of all vario values
        for i = 1, #sensorReadings - delay do
            if sensorReadings[i] < bias then bias = sensorReadings[i] end   -- set bias to lowest value so far (always negative at this point)
            varioSum = varioSum + sensorReadings[i]
        end
        if varioSum == 0.0 then bestPoint = avgPoint -- avoid division by 0
        else
            bias = -bias -- invert bias to a positive number
            varioSum = varioSum + (#sensorReadings - delay) * bias -- modify the sum of all values to get an overall weight of 1
            local latSum, lonSum = 0,0
            for i = 1, #gpsReadings - delay do
                local lat,lon = gps.getValue(gpsReadings[i + delay])
                local weight = sensorReadings[i] + bias
                latSum = latSum + lat * weight  -- in contrast to algorithm 2 the center point is irrelevant here since the sum of all weights is 1
                lonSum = lonSum + lon * weight
            end
            bestPoint = gps.newPoint(latSum / varioSum, lonSum / varioSum) -- best point is the weighted average
        end
        bestClimb = estimateClimb and estimateClimbRate(bestPoint) or nil
    end
    collectgarbage()
end

-----------------------------------------------------------------------------------------------
-- set the zoom value to the biggest value so that all points in 'gpsReadings' are in the frame
-----------------------------------------------------------------------------------------------
local function calcAutozoom(width, height)
    local centerLat, centerLon = gps.getValue(avgPoint)
    local maxLatPoint = gpsReadings[1] -- finding points with the highest latitude/longitude deviation relative to the average point
    local maxLonPoint = gpsReadings[1]
    local maxLatVal, maxLonVal = gps.getValue(gpsReadings[1])
    maxLatVal = abs(maxLatVal - centerLat) -- highest latitude deviation relative to the center point
    maxLonVal = abs(maxLonVal - centerLon) -- highest longitude deviation
    for i = 2, #gpsReadings do
        local lat,lon = gps.getValue(gpsReadings[i])
        if abs(lat - centerLat) > maxLatVal then -- new point with highest latitude deviation
            maxLatPoint = gpsReadings[i]
            maxLatVal = abs(lat - centerLat)
        end
        if abs(lon - centerLon) > maxLonVal then -- new point with highest longitude deviation
            maxLonPoint = gpsReadings[i]
            maxLonVal = abs(lon - centerLon)
        end
    end
    local autozoom = math.min(zoom, 20) + 2 -- add 1 to last zoom to allow it getting bigger while avoiding a high iteration quantity | another +1 since it is immediately subtracted again
    -- decrease zoom until the most extreme points are on screen, maximum 2 iterations
    -- => autozoom can become 'zoom + 1', 'zoom' or 'zoom - 1'
    repeat
        autozoom = autozoom - 1
        local _,y1 = gps.getLcdXY(maxLatPoint, avgPoint, autozoom)
        local x2,_ = gps.getLcdXY(maxLonPoint, avgPoint, autozoom)
    until autozoom < 2 or autozoom < zoom or (abs(y1) + 4 < height / 2 and abs(x2) + 4 < width / 2) -- 4 pixel margin
    zoom = autozoom
    collectgarbage()
end

------------------------------------------------------------------------------------------------------------
-- Prints the telemetry.
-- Each gps point is displayed as a circle with the radius proportional to the climb rate or as a small dot.
-- Depending on the selected algorithm, the best point is displayed as a square.
------------------------------------------------------------------------------------------------------------
local function printTelemetry(width, height)
    if gpsReadings and avgPoint and #gpsReadings > 0 then
        local zoomSwitchVal = system.getInputsVal(zoomSwitch)
        if (not zoomSwitch) or zoomSwitchVal == -1.0 then
            calcAutozoom(width, height)
        else
            zoom = math.floor(zoomSwitchVal * abs(maxZoom - minZoom) / 2 + (minZoom + maxZoom) / 2 + 0.5) -- get zoom level from switch and round to integer
        end

        local hWidth = width // 2
        local hHeight = height // 2

        for i = 1, #gpsReadings do -- draw points
            if i > delay and (sensorReadings[i - delay] > 0 or gpsReadings[i] == bestPoint) then -- positive climb at the i-th point
                local x,y = gps.getLcdXY(gpsReadings[i], avgPoint, zoom) -- pixel position relative to the average point
                if gpsReadings[i] == bestPoint then
                    local size = math.max(math.ceil(circleRadius * bestClimb), 2)
                    lcd.drawRectangle(hWidth + x - size, hHeight + y - size, size + size, size + size)   -- draw square at optimal position
                else
                    local radius = math.floor(circleRadius * sensorReadings[i - delay]) + 1
                    lcd.drawCircle(hWidth + x, hHeight + y, radius) -- draw circle with the specified radius
                end
            elseif i ~= 1 then -- no climb, not current position
                local x,y = gps.getLcdXY(gpsReadings[i], avgPoint, zoom)
                lcd.drawFilledRectangle(x + hWidth - 1, y + hHeight - 1, 2, 2)
            end
        end
        if bestPoint and algorithm ~= 1 and not (searchModeForce and system.getInputsVal(appModeSwitch) == 1) then -- draw square at the optimal point
            local x,y = gps.getLcdXY(bestPoint, avgPoint, zoom)
            local size = (estimateClimb and bestClimb) and math.max(math.ceil(bestClimb * circleRadius), 3) or 3 -- half size of the square
            lcd.drawFilledRectangle(hWidth + x - size, hHeight + y - size, size + size, size + size) -- draw best point
        end
        local x,y = gps.getLcdXY(gpsReadings[1], avgPoint, zoom)
        lcd.drawLine(hWidth + x - 6, hHeight + y - 6, hWidth + x + 6, hHeight + y + 6) -- draw X at current position
        lcd.drawLine(hWidth + x - 6, hHeight + y + 6, hWidth + x + 6, hHeight + y - 6)
        lcd.drawLine(hWidth, hHeight - 3, hWidth, hHeight + 3) -- draw + at average point (center of the frame)
        lcd.drawLine(hWidth - 3, hHeight, hWidth + 3, hHeight)
        if enableSwitch and system.getInputsVal(enableSwitch) ~= 1 and system.getTime() % 2 == 0 then -- blinking "disabled" to indicate that the displayed path is invalid
            lcd.drawText((width - lcd.getTextWidth(FONT_BOLD, "disabled")) / 2, 3, "disabled", FONT_BOLD)
        end
        collectgarbage()
    end
end

--------------------------------------------------------------------------------------
-- key event callback function
--------------------------------------------------------------------------------------
local function onKeyPressed(keyCode)
    if currForm ~= MAIN_FORM and (keyCode == KEY_ESC or keyCode == KEY_5) then
        form.preventDefault()
        form.reinit(MAIN_FORM)
    elseif currForm == TELEMETRY_FORM and keyCode == KEY_1 then
        onZoomSwitchChanged(nil)
        form.setValue(zoomInputboxIndex, nil)
    elseif currForm == ALGORITHM_FORM and keyCode == KEY_1 then
        onAlgorithmSwitchChanged(nil)
        form.setValue(algorithmSwitchInputIndex, nil)
    end
end

--------------------------------------------------------------------------------------

local function loop()
    if enableSwitch and system.getInputsVal(enableSwitch) ~= 1 then
        switchOn = false
    elseif not switchOn then -- switch was just moved to enabled position or deleted
        switchOn = true
        reset()
    end
    if algorithmSwitch then
        local switchAlg = math.floor(system.getInputsVal(algorithmSwitch)) + 2
        if switchAlg ~= algorithm then
            onAlgorithmChanged(switchAlg)
            if currForm == ALGORITHM_FORM then
                form.setValue(algorithmSelectIndex, algorithm)
            end
        end
    end
    if switchOn and latSensorIndex ~= 0 and lonSensorIndex ~= 0 and sensorIndices[sensorMode] ~= 0 then
        local time = system.getTimeCounter()
        if time >= lastTime + readingInterval then
            -- new reading
            local gpsPoint = gps.getPosition(gpsSensorIDs[latSensorIndex], gpsSensorParams[latSensorIndex], gpsSensorParams[lonSensorIndex])
            local sensorReading = system.getSensorValueByID(otherSensorIDs[sensorIndices[sensorMode]],
                                                            otherSensorParams[sensorIndices[sensorMode]])
            if gpsPoint and sensorReading and sensorReading.valid then
                if sensorMode == 1 then
                    table.insert(gpsReadings, 1, gpsPoint)
                    table.insert(sensorReadings, 1, sensorReading.value) -- add new point and vario/altitude value
                elseif lastAltitude then -- add new point in sensor mode 2 when there is a previous altitude value
                    table.insert(gpsReadings, 1, gpsPoint)
                    table.insert(sensorReadings, 1, (sensorReading.value - lastAltitude) * 1000 / readingInterval) -- add virtual vario value to the path
                    lastAltitude = sensorReading.value
                else -- sensor mode 2, this is the first reading
                    lastAltitude = sensorReading.value -- save altitude and ignore gps point
                end
                if #gpsReadings > 0 then    -- #gps points can be 0 if the first altitude after a reset was measured
                    local fullTurn = filterReadings()   -- delete excessive data points
                    local latSum, lonSum = gps.getValue(gpsReadings[1]) -- calculating the latitude/longitude sums
                    for i = 2, #gpsReadings do
                        local lat, lon = gps.getValue(gpsReadings[i])
                        latSum = latSum + lat
                        lonSum = lonSum + lon
                    end
                    avgPoint = gps.newPoint(latSum / #gpsReadings, lonSum / #gpsReadings) -- new average point
                    calcBestPoint(fullTurn)
                end
            elseif #gpsReadings > 0 then -- delete readings if not valid
                reset()
            else
                lastTime = time
                lastSpeech = time
                lastAltitude = nil
            end
            lastTime = lastTime + readingInterval
        end
        if gpsReadings and time >= lastSpeech + 1000 * interval then
            speechOutput()
            lastSpeech = lastSpeech + 1000 * interval
        end
    end
    collectgarbage()
end

local function initForm(formID)
    collectgarbage()
    if not formID or formID == MAIN_FORM then

        form.setTitle(getTranslation(appName))
        form.addRow(2)
        form.addLabel({ label = getTranslation(enableSwitchText) })
        form.addInputbox(enableSwitch, false, onEnableSwitchChanged)
        form.addRow(1)
        form.addLink(function () form.reinit(SENSORS_FORM) end, { label = getTranslation(sensorsFormTitle) .. " >>" })
        form.addRow(1)
        form.addLink(function () form.reinit(ALGORITHM_FORM) end, { label = getTranslation(algorithmsFormTitle) .. " >>" })
        form.addRow(1)
        form.addLink(function () form.reinit(TELEMETRY_FORM) end, { label = getTranslation(telemetryFormTitle) .. " >>" })
        form.addRow(2)
        form.addLabel({ label = getTranslation(readingsText) })
        form.addIntbox(readingInterval, 500, 5000, 1000, 0, 100, onReadingIntervalChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(intervalText), width = 250 })
        form.addIntbox(interval, 3, 30, 10, 0, 1, onIntervalChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(searchModeText), width = 250 })
        form.addInputbox(appModeSwitch, false, onAppModeSwitchChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(searchModeForceText), width = 280 })
        searchModeForceIndex = form.addCheckbox(searchModeForce, onSearchModeForceChanged)
        form.setFocusedRow(currForm or 1)

    elseif formID == SENSORS_FORM then

        form.setTitle(getTranslation(sensorsFormTitle))
        form.addRow(2)
        form.addLabel({ label = getTranslation(latInputText) })
        form.addSelectbox(gpsSensorLabels, latSensorIndex + 1, true, onLatSensorChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(lonInputText) })
        form.addSelectbox(gpsSensorLabels, lonSensorIndex + 1, true, onLonSensorChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(sensorModeText) })
        form.addSelectbox(getTranslation(modeSelectionText), sensorMode, false, onSensorModeChanged)
        form.addRow(2)
        sensorLabelIndex = form.addLabel({ label = getTranslation(sensorInputText[sensorMode]), width = 100 })
        sensorInputIndex = form.addSelectbox(otherSensorLabels, sensorIndices[sensorMode] + 1, true, onOtherSensorChanged, { width = 220 })
        form.addRow(2)
        form.addLabel({ label = getTranslation(delayText) })
        form.addIntbox(delay, 0, 5, 0, 0, 1, onDelayChanged)
        form.setFocusedRow(1)

    elseif formID == ALGORITHM_FORM then

        form.setTitle(getTranslation(algorithmsFormTitle))
        form.addRow(2)
        form.addLabel({ label = getTranslation(algorithmText), width = 100 })
        algorithmSelectIndex = form.addSelectbox(getTranslation(algorithSelectionText), algorithm, true, onAlgorithmChanged, { width = 220 })
        form.addRow(2)
        form.addLabel({ label = getTranslation(enableSwitchText) })
        algorithmSwitchInputIndex = form.addInputbox(algorithmSwitch, true, onAlgorithmSwitchChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(minSequenceLengthText), width = 250 })
        form.addIntbox(minSequenceLength, 5, 60, 5, 0, 1, onMinSequenceLengthChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(maxSequenceLengthText), width = 250 })
        form.addIntbox(maxSequenceLength, 5, 60, 20, 0, 1, onMaxSequenceLengthChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(bestSequenceLengthText), width = 250 })
        form.addIntbox(bestSequenceLength, 1, 20, 3, 0, 1, onBestSequenceLengthChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(estimateClimbText), width = 280 })
        estimateCheckboxIndex = form.addCheckbox(estimateClimb, onEstimateClimbChanged)
        form.setFocusedRow(1)
        form.setButton(1, "Clr", ENABLED)

    else

        form.setTitle(getTranslation(telemetryFormTitle))
        form.addRow(2)
        form.addLabel({ label = getTranslation(zoomSwitchText) })
        zoomInputboxIndex = form.addInputbox(zoomSwitch, true, onZoomSwitchChanged)
        form.addRow(2)
        form.addLabel({ label = getTranslation(circleRadiusText), width = 250 })
        form.addIntbox(circleRadius, 1, 50, 15, 0, 1, onCircleRadiusChanged)
        form.addRow(3)
        form.addLabel({ label = getTranslation(zoomRangeText), width = 210 })
        minZoomIndex = form.addIntbox(minZoom, 1, 21, 15, 0, 1, onMinZoomChanged, { width = 50 })
        maxZoomIndex = form.addIntbox(maxZoom, 1, 21, 21, 0, 1, onMaxZoomChanged, { width = 50 })
        form.setFocusedRow(1)
        form.setButton(1, "Clr", ENABLED)
    end
    currForm = formID
    collectgarbage()
end

local function init()
    collectgarbage()
    gpsSensorLabels = {"..."}
    otherSensorLabels = {"..."}
    gpsSensorIDs = {}
    gpsSensorParams = {}
    otherSensorIDs = {}
    otherSensorParams = {}
    for _,sensor in ipairs(system.getSensors()) do
        if sensor.param ~= 0 and sensor.type == 9 then
            gpsSensorLabels[#gpsSensorLabels+1] = string.format("%s: %s", sensor.sensorName, sensor.label)
            gpsSensorIDs[#gpsSensorIDs+1] = sensor.id
            gpsSensorParams[#gpsSensorParams+1] = sensor.param
        elseif sensor.param ~= 0 and sensor.type ~= 5 then
            otherSensorLabels[#otherSensorLabels+1] = string.format("%s: %s [%s]", sensor.sensorName, sensor.label, sensor.unit)
            otherSensorIDs[#otherSensorIDs+1] = sensor.id
            otherSensorParams[#otherSensorParams+1] = sensor.param
        end
    end
    minSequenceLength = system.pLoad(minSequenceLengthKey, 5)
    maxSequenceLength = system.pLoad(maxSequenceLengthKey, 20)
    bestSequenceLength = system.pLoad(bestSequenceLengthKey, 3)
    enableSwitch = system.pLoad(enableSwitchKey)
    zoomSwitch = system.pLoad(zoomSwitchKey)
    latSensorIndex = system.pLoad(latSensorIndexKey, 0)
    lonSensorIndex = system.pLoad(lonSensorIndexKey, 0)
    sensorIndices = system.pLoad(sensorIndicesKey) or {0, 0}
    delay = system.pLoad(delayKey, 0)
    if latSensorIndex > #gpsSensorIDs then latSensorIndex = 0 end
    if lonSensorIndex > #gpsSensorIDs then lonSensorIndex = 0 end
    if sensorIndices[1] > #otherSensorIDs then sensorIndices[1] = 0 end
    if sensorIndices[2] > #otherSensorIDs then sensorIndices[2] = 0 end
    sensorMode = system.pLoad(sensorModeKey, 1)
    algorithm = system.pLoad(algorithmKey, 2)
    readingInterval = system.pLoad(readingInteravlKey, 1000)
    interval = system.pLoad(intervalKey, 10)
    estimateClimb = (system.pLoad(estimateClimbKey, 1) == 1) -- create boolean from integer
    circleRadius = system.pLoad(circleRadiusKey, 15)
    minZoom = system.pLoad(minZoomKey, 15)
    maxZoom = system.pLoad(maxZoomKey, 21)
    algorithmSwitch = system.pLoad(algorithmSwitchKey)
    appModeSwitch = system.pLoad(appModeSwitchKey)
    searchModeForce = (system.pLoad(searchModeForceKey, 1) == 1) -- create boolean from integer
    system.registerForm(1, MENU_APPS, getTranslation(appName), initForm, onKeyPressed)
    system.registerTelemetry(2, getTranslation(appName), 4, printTelemetry)
    reset()
    collectgarbage()
end

local function destroy()
    system.unregisterTelemetry(2)
    collectgarbage()
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.31", name = getTranslation(appName) }