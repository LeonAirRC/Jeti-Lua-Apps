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

local sensors

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

system.getSensorValueByID = function (id, param)
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

return { init = init, loop = loop, destroy = destroy, author = "LeonAir RC", version = "1.0", name = "Emulated Telemetry" }