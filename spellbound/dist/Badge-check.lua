--[==[badge-app
slug=spellbound_check
name=Spellbound Check
icon=SC
api=2
heap_kb=48
wake_lock=1
version=0.1.0
]==]
-- Standalone API/connection check; no game modules required.
local status,body,rx,ready,next_draw=nil,nil,"No ping received",false,0
function on_enter(root)
  status=badge.ui.label(root,"SPELLBOUND HARDWARE CHECK")
  status:set_pos(10,10);status:set_size(300,30)
  body=badge.ui.label(root,"");body:set_pos(10,50);body:set_size(300,180)
  ready=badge.radio.enable()==true
  if ready then badge.radio.on_recv(function(mac,rssi,p)
    if p=="SBC1 ping" then rx="RX ping from "..mac:sub(-5);badge.led.set_all(0,48,16);badge.led.show() end
  end) end
end
function on_tick()
  local now=badge.sys.ms();if now<next_draw then return end;next_draw=now+200
  local x,y,z=badge.sensor.accel()
  local sensor=type(x)=="number" and type(y)=="number" and type(z)=="number" and string.format("Accel mg: %.0f %.0f %.0f",x,y,z) or "Sensor unavailable"
  body:set_text(sensor.."\nRadio "..(ready and "enabled" or "unavailable").."\nLua bytes: "..badge.sys.heap().."\n"..rx.."\nA: send ping. HOME: exit.")
end
function on_button(b,k)
  if b==badge.input.BUTTON.A and k==badge.input.KIND.PRESSED then
    if ready then
      local ok=badge.radio.send("SBC1 ping")
      rx=ok and "TX queued; check other badge" or "TX queue failed"
    end
  end
end
function on_exit()
  badge.radio.on_recv(nil);badge.radio.disable();badge.led.clear();badge.led.show()
end
