
local pinDoor = 1 --GPIO5, io index is 1
local SSID = "abc"
local PASSWORD = "def"

function getDoorState()
	if (0 == gpio.read(pinDoor))
		return "Closed"
	else
		return "Opened"
	end
end

function receiver(sck, data)
	local response = {}

  -- if you're sending back HTML over HTTP you'll want something like this instead
  -- local response = {"HTTP/1.0 200 OK\r\nServer: NodeMCU on ESP8266\r\nContent-Type: text/html\r\n\r\n"}

  response[#response + 1] = "HTTP/1.0 200 OK\r\n"
  response[#response + 1] = "Server: NodeMCU on ESP8266\r\n"
  response[#response + 1] = "Content-Type: text/html\r\n\r\n"

  response[#response + 1] = "<HTML>\r\n"
  response[#response + 1] = "<TITLE>Door state<\/TITLE>\r\n"
  response[#response + 1] = "<BODY>\r\n"
  response[#response + 1] = "Current state: "..getDoorState().."\r\n"
  response[#response + 1] = "<\/BODY>\r\n"
  response[#response + 1] = "<\/HTML>\r\n"

  -- sends and removes the first element from the 'response' table
  local function send(localSocket)
    if #response > 0 then
      localSocket:send(table.remove(response, 1))
    else
      localSocket:close()
      response = nil
    end
  end

  -- triggers the send() function again once the first chunk of data was sent
  sck:on("sent", send)
  send(sck)
end

function startup()
	-- sync the time from 0.fr.pool.ntp.org
	sntp.sync("224.0.1.1",
		function(sec, usec, server, info)
			print('sync', sec, usec, server)
		end,
		function()
			print('failed!')
		end
	)
    -- start http server
	-- net.TCP, 30 sec timeout
	srv = net.createServer(30)
	if srv then
		srv:listen(80, function(conn)
			conn:on("receive", receiver)
			conn:send("Hello world")
		end)
	end
end

-- Define WiFi station event callbacks 
wifi_connect_event = function(T) 
  print("Connection to AP("..T.SSID..") established!")
  print("Waiting for IP address...")
  if disconnect_ct ~= nil then disconnect_ct = nil end  
end

wifi_got_ip_event = function(T) 
  -- Note: Having an IP address does not mean there is internet access!
  -- Internet connectivity can be determined with net.dns.resolve().    
  print("Wifi connection is ready! IP address is: "..T.IP)
  print("Startup will resume momentarily, you have 3 seconds to abort.")
  print("Waiting...") 
  tmr.create():alarm(3000, tmr.ALARM_SINGLE, startup)
end

wifi_disconnect_event = function(T)
  if T.reason == wifi.eventmon.reason.ASSOC_LEAVE then 
    --the station has disassociated from a previously connected AP
    return 
  end
  -- total_tries: how many times the station will attempt to connect to the AP. Should consider AP reboot duration.
  local total_tries = 75
  print("\nWiFi connection to AP("..T.SSID..") has failed!")

  --There are many possible disconnect reasons, the following iterates through 
  --the list and returns the string corresponding to the disconnect reason.
  for key,val in pairs(wifi.eventmon.reason) do
    if val == T.reason then
      print("Disconnect reason: "..val.."("..key..")")
      break
    end
  end

  if disconnect_ct == nil then 
    disconnect_ct = 1 
  else
    disconnect_ct = disconnect_ct + 1 
  end
  if disconnect_ct < total_tries then 
    print("Retrying connection...(attempt "..(disconnect_ct+1).." of "..total_tries..")")
  else
    wifi.sta.disconnect()
    print("Aborting connection to AP!")
    disconnect_ct = nil  
  end
end

gpio.mode(pinDoor, gpio.INPUT, gpio.PULLUP)
-- Register WiFi Station event callbacks
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, wifi_connect_event)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifi_got_ip_event)
wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, wifi_disconnect_event)

print("Connecting to WiFi access point...")
wifi.setmode(wifi.STATION)
if (wifi.sta.sethostname("NodeMCU") == true) then
    print("hostname was successfully changed")
else
    print("hostname was not changed")
end
print("Current hostname is :"..wifi.sta.gethostname())
wifi.sta.config({ssid=SSID, pwd=PASSWORD, auto=true})
-- wifi.sta.connect() not necessary because config() uses auto-connect=true by default

