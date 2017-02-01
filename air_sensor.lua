---  Example of usage esp8266 and
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
    shift = 0.66  -- sensor calibration
    calcVoltage = (vRef * voltage / 1024) + shift

    print("Voltage: "..round2(calcVoltage * 1000, 2).."mV")

    -- linear eqaution taken from http://www.howmuchsnow.com/arduino/airquality/
    -- Chris Nafis (c) 2012
    dustDensity = 0.172 * calcVoltage - 0.0999;
    dustDensity = dustDensity * 1000;
    
    print("Dust density:"..round2(dustDensity,1).."ug/m^3") 
    return calcVoltage, dustDensity   
end

function postdata(host, msg) 
   print(msg)
   gpio.write(led_2_pin, gpio.HIGH)  -- Test LED ON
   
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
 
        connout:send("POST /api/v1/sensor HTTP/1.1\r\n"
        .. "Host: "..host.."\r\n"
        .. "Content-Type: application/json\r\n"
        .. "Accept: application/json\r\n"
        .. "Connection: close\r\n"        
        .. "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n"
        .. "Content-length: "..string.len(msg).."\r\n"
        .. "\r\n"
        .. msg)
   end)
   connout:on("disconnection", function(connout, payloadout)
        print("Disconnected");
        connout:close();
        collectgarbage();
   end) 
   connout:connect(80, host)
end

-- Send data to api.less-smog.org
function sendToLessSmog()
  local voltage, dustDensity = ReadSharpSensor();
  local msg = '{"api_key": "FGTEDVNHYEWERTJ", '
        msg = msg..'"api_secret": "CVFGDYNTEDWED", '
        msg = msg..'"latitude": 51.752469, '
        msg = msg..'"longitude": -1.263779, '
        msg = msg..'"name": "Indor Sharp", '
        msg = msg..'"type": "indoor", '
        msg = msg..'"quantity": "PM2.5", '
        msg = msg..'"unit": "ug/m3", '
        msg = msg..'"value": "'..dustDensity..'", '
        msg = msg..'"chipid": "'..node.chipid()..'" }'        
  postdata('api.less-smog.org', msg) 
end

-- Send data every 10s
function startMeasurements()
    tmr.alarm(2, 10000, 1, function() 
      sendToLessSmog()      
    end)
end
