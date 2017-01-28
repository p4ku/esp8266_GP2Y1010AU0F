---  Example how to use
---  esp8266 and
---  Sharp Optical Dust Sensor GP2Y1010AU0F
---
---  Author: Blaszczyk Piotr

led_pin = 5      -- Sensor LED PIN (3)
vRef = 3.3     -- V ref 3.3V
led_2_pin = 2  -- Test LED pin


gpio.mode(led_2_pin, gpio.OUTPUT)
gpio.mode(led_pin, gpio.OUTPUT)
gpio.write(led_pin, gpio.HIGH)

function round2(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function ReadSharpSensor()    
    gpio.write(led_pin, gpio.LOW) -- Sensor LED ON
    tmr.delay(280)  -- wait 280us
    voltage=adc.read(0)  -- Read ADC value
    tmr.delay(10)
    gpio.write(led_pin, gpio.HIGH) -- Sensor LED OFF
    
    print("ADC value: "..voltage)

    -- 0-1023 int value to 0-3.3V
    calcVoltage = vRef * voltage / 1024

    print("Voltage: "..round2(calcVoltage * 1000, 2).."mV")

    -- linear eqaution taken from http://www.howmuchsnow.com/arduino/airquality/
    -- Chris Nafis (c) 2012
    dustDensity = 0.172 * calcVoltage - 0.0999;
    dustDensity = dustDensity * 1000;
    
    print("Dust density:"..round2(dustDensity,1).."ug/m^3") 
    return calcVoltage, dustDensity   
end

-- Send data to Thingspeak
function postThingSpeak()
    connout = nil
    connout = net.createConnection(net.TCP, 0)
 
    connout:on("receive", function(connout, payloadout)
        if (string.find(payloadout, "Status: 200 OK") ~= nil) then
            print("Posted OK");
            gpio.write(led_2_pin, gpio.LOW) -- Test LED OFF
        end
    end)
 
    connout:on("connection", function(connout, payloadout)
 
        print("Posting...");
        gpio.write(led_2_pin, gpio.HIGH)  -- Test LED ON
 
        local voltage, dustDensity = ReadSharpSensor();
 
        connout:send("GET /update?api_key=UMA5PXH21E3R02EC&field1="..voltage.."&field2="..dustDensity
        .. " HTTP/1.1\r\n"
        .. "Host: api.thingspeak.com\r\n"
        .. "Connection: close\r\n"
        .. "Accept: */*\r\n"
        .. "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n"
        .. "\r\n")
    end)
 
    connout:on("disconnection", function(connout, payloadout)
        connout:close();
        collectgarbage();
    end)
 
    connout:connect(80,'api.thingspeak.com')
end

function startMeasurements()
    -- Send data every 5s to ThingSpeak
    tmr.alarm(2, 5000, 1, function() 
      postThingSpeak() 
    end)
end
