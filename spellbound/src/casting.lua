-- Side-effect motion capture coordinator.
local S=SPELLBOUND_STATE
local raw_sample,signature=S.raw_sample,S.signature
local function accel()
  local x,y,z=badge.sensor.accel()
  if type(x)=="number" and type(y)=="number" and type(z)=="number" and x==x and y==y and z==z
    and math.max(math.abs(x),math.abs(y),math.abs(z))<=32000 then return x,y,z end
end
local function sample(now)
  local c=S.capture;if not c or now-c[2]<20 then return end
  local x,y,z=accel();if not x then c[4]=true;return end
  if now-c[1]<=S.MAX_CAPTURE then c[3]=c[3]..raw_sample(x,y,z) end
  c[2]=now
end
function S.capture_event(now,event)
  if event==0 then
    local x,y,z=accel()
    if not x then S.message("Sensor unavailable",4);return end
    S.capture={now,now,raw_sample(x,y,z),false};S.effect=0;return
  end
  local c=S.capture;if not c then return end
  local long=now-c[1]>S.MAX_CAPTURE
  if event==2 and not long then
    sample(now);if badge.input.is_down(badge.input.BUTTON.A) then return end
  else sample(now) end
  c=S.capture;local raw,bad=c[3],c[4];S.capture=nil
  if bad or long then S.message(long and "Hold too long" or "Try again",4);return end
  local sig,err=signature(raw);raw=nil
  if not sig then S.message(err or "No clear movement",4);return end
  S.handle_signature(sig)
end
