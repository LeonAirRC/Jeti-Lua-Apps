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

local filepath = "Apps/EmulatedTelemetry/sensors.json"
local monthDays = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334}
local units = {"m", "km", "s", "min", "h", "m/s", "km/h", "V", "A", "mAh", "Ah", "W", "Wmi", "°C", "°", "%", "l", "ml", "hl", "l/m", "ml/m", "hPa", "kPa", "b",
                "ft", "mi.", "yd.", "ft/s", "mph", "kt.", "F", "psi", "atm", "floz", "gal", "oz/m", "gpm"}
local labels = {"Voltage", "Current", "Run time", "U Rx", "A1", "A2", "T", "Q", "Input A", "Input B", "Input C", "Output", "Power", "Velocity", "Speed", "Temp. A", "Temp. B",
                "Cell 1", "Cell 2", "Cell 3", "Cell 4", "Cell 5", "Cell 6", "LowestVolt", "LowestCell", "Accu. volt", "Vario", "Abs. altit", "Rel. altit", "Air press.",
                "U Battery", "I Battery", "U BEC", "I BEC", "Capacity", "Revolution", "Temp.", "Run Time", "PWM", "Quality", "SatCount", "Altitude", "AltRelat.", "Distance",
                "Course", "Azimuth", "Impulse", "Trip", "R.volume", "R.volumeP", "Flow", "Pressure"}
local systemSounds = {SOUND_START,   SOUND_BOUND,   SOUND_LOWTXVOLT,   SOUND_LOWSIGNAL, SOUND_SIGNALLOSS, SOUND_RANGETEST, SOUND_AUTOTRIM, SOUND_INACT, SOUND_LOWQ}

local sensors

local function contains(table, value)
    for _,v in pairs(table) do
        if value == v then
            return true
        end
    end
    return false
end

local text = io.readall(filepath)
if not text then
    print("The file EmulatedTelemetry/sensors.json is missing")
    return {}
end

local function getSensorValue(sensor)
    return (sensor.upperBound - sensor.lowerBound) * (system.getInputs(sensor.input) or 0) / 2 + (sensor.upperBound + sensor.lowerBound) / 2
end

system.getSensors = function()
    return sensors
end

system.getSensorByID = function(id, param)
    for _,sensor in pairs(sensors) do
        if sensor.id == id and sensor.param == param then
            return sensor
        end
    end
    return nil
end

system.getSensorValueByID = function(id, param)
    for _,sensor in pairs(sensors) do
        if sensor.id == id and sensor.param == param then
            local s = {type = sensor.type, valid = sensor.valid}
            if sensor.type == 5 then
                if sensor.decimals == 0 then
                    s.valSec = sensor.valSec
                    s.valMin = sensor.valMin
                    s.valHour = sensor.valHour
                else
                    s.valYear = sensor.valYear
                    s.valMonth = sensor.valMonth
                    s.valDay = sensor.valDay
                end
            elseif sensor.type == 9 then
                s.valGPS = sensor.valGPS
            else
                s.value = sensor.value
                s.min = sensor.min
                s.max = sensor.max
            end
            return s
        end
    end
    return nil
end

gps.getPosition = function (id, pLat, pLon)
    local sLat, sLon = system.getSensorByID(id, pLat), system.getSensorByID(id, pLon)
    if sLat and sLon and sLat.valid and sLon.valid and sLat.valGPS and sLon.valGPS then
        local lat, lon = sLat.valGPS / 0x1000, sLon.valGPS / 0x1000
        if sLat.decimals > 2 then lat = -lat end
        if sLon.decimals > 2 then lon = -lon end
        return gps.newPoint(lat, lon)
    else
        return nil
    end
end

system.vibration = function(leftRight, vibrationProfile)
    assert(type(leftRight) == "boolean", "Error in system.vibration: expected boolean: leftRight")
    assert(type(vibrationProfile) == "number" and vibrationProfile == math.ceil(vibrationProfile), "Error in system.vibration: expected integer: vibrationProfile")
    print(string.format("vibration(leftRight : %s, vibrationProfile : %s)", tostring(leftRight), tostring(vibrationProfile)))
end

system.playFile = function(fileName, playbackType)
    assert(type(fileName) == "string", "Error in system.playFile: expected string: fileName")
    assert(type(playbackType) == "number" and playbackType == math.ceil(playbackType), "Error in system.playFile: expected integer: playbackType")
    assert(playbackType == AUDIO_BACKGROUND or playbackType == AUDIO_IMMEDIATE or playbackType == AUDIO_QUEUE, "Error in system.playFile: playbackType " .. tostring(playbackType) .. " not allowed")
    print(string.format("playFile(fileName : %s, playbackType : %s)", tostring(fileName), tostring(playbackType or "nil")))
end

system.playNumber = function(value, decimals, unit, label)
    assert(type(value) == "number", "Error in system.playNumber: expected number: value")
    assert(type(decimals) == "number" and decimals == math.ceil(decimals), "Error in system.playNumber: expected integer: decimals")
    assert(not unit or type(unit) == "string", "Error in system.playNumber: expected string: unit")
    assert(not label or type(label) == "string", "Error in system.playNumber: expected string: label")
    assert(decimals >= 0 and decimals <= 2, "Error in system.playNumber: 'decimals' has to be between 0 and 2")
    print(string.format("playNumber(value : %s, decimals : %s, unit : %s, label : %s)", tostring(value), tostring(decimals), contains(units, unit) and unit or "nil", contains(labels, label) and label or "nil"))
    return true
end

system.playBeep = function(repeatCount, frequency, length)
    assert(type(repeatCount) == "number" and repeatCount == math.ceil(repeatCount), "Error in system.playBeep: expected integer: repeatCount")
    assert(type(frequency) == "number" and frequency == math.ceil(frequency), "Error in system.playBeep: expected integer: frequency")
    assert(type(length) == "number" and length == math.ceil(length), "Error in system.playBeep: expected integer: length")
    assert(repeatCount >= 0 and repeatCount <= 10, "Error in system.playBeep: 'repeatCount' has to be between 0 and 10")
    assert(frequency >= 200 and frequency <= 10000, "Error in system.playBeep: 'frequency' has to be between 200 and 10000")
    assert(length >= 20 and length <= 10000, "Error in system.playBeep: 'length' has to be between 20 and 10000")
    print(string.format("playBeep(repeatCount : %s, frequency : %s, length : %s", tostring(repeatCount), tostring(frequency), tostring(length)))
end

system.playSystemSound = function(soundIndex)
    assert(type(soundIndex) == "number" and soundIndex == math.ceil(soundIndex), "Error in system.playSystemSound: expected integer: soundIndex")
    assert(contains(systemSounds, soundIndex), "Error in system.playSystemSound: soundIndex " .. tostring(soundIndex) .. " not allowed")
    print(string.format("playSystemSound(soundIndex : %s)", tostring(soundIndex)))
end

local function loop()
    for _,sensor in pairs(sensors) do
        if sensor.param ~= 0 then
            sensor.valid = system.getInputs(sensor.input) ~= -1.0 -- invalidate data when the input is in off-position
            if sensor.type == 5 then
                if sensor.decimals == 0 then
                    local sec = math.floor(getSensorValue(sensor))
                    sensor.valSec = sec % 60
                    sensor.valMin = (sec % 3600) // 60
                    sensor.valHour = sec // 3600
                else
                    local day = math.floor(getSensorValue(sensor))
                    sensor.valYear = 2000 + day // 365
                    day = day % 365
                    for i = #monthDays, 1, -1 do
                        if day >= monthDays[i] then
                            sensor.valMonth = i
                            sensor.valDay = day - monthDays[i] + 1
                            break
                        end
                    end
                end
            elseif sensor.type == 9 then
                local deg = math.floor(getSensorValue(sensor) * 0x10000)
                if deg >= 0 then
                    sensor.decimals = sensor.decimals % 2
                    sensor.valGPS = deg
                else
                    sensor.decimals = 2 + sensor.decimals % 2
                    sensor.valGPS = -deg
                end
            else
                sensor.value = getSensorValue(sensor)
                sensor.minVal = sensor.minVal and (sensor.value and math.min(sensor.minVal, sensor.value) or sensor.minVal) or sensor.value
                sensor.maxVal = sensor.maxVal and (sensor.value and math.max(sensor.maxVal, sensor.value) or sensor.maxVal) or sensor.value
            end
        end
    end
    collectgarbage()
end

local function init()
    sensors = json.decode(text)
end

local function destroy()
    system.getSensors = nil
    system.getSensorByID = nil
    system.getSensorValueByID = nil
    gps.getPosition = nil
    sensors = nil
    collectgarbage()
end

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.1.2", name = "Emulated Telemetry" }