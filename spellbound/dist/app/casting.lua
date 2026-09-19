local S=SPELLBOUND_STATE
local raw_sample,signature=S.raw_sample,S.signature
local function read_accel()
local x,y,z=badge.sensor.accel()
if type(x)=="number" and type(y)=="number" and type(z)=="number" and x==x and y==y and z==z
and math.max(math.abs(x),math.abs(y),math.abs(z))<=32000 then return x,y,z end
end
local function sample(now)
local c=S.capture
if not c or now-c[2]<20 then return end
local x,y,z=read_accel();if not x then c[4]=true;return end
local e=now-c[1]
if e<=S.MAX_CAPTURE then c[3]=c[3]..raw_sample(e,x,y,z) end
c[2]=now
end
function S.capture_start(now)
local x,y,z=read_accel()
if not x then S.message("Motion sensor unavailable / invalid","X");return end
S.capture={now,now,raw_sample(0,x,y,z),false};S.effect=""
end
function S.capture_finish(now,too_long)
local c=S.capture;if not c then return end
sample(now);c=S.capture
local raw,bad=c[3],c[4];S.capture=nil
if bad or too_long then
S.message(too_long and "A hold too long - try again" or "Sensor sample invalid","X");return
end
local sig,err,meta=signature(raw);raw=nil
if not sig then S.message(err or "No clear movement","X");return end
S.handle_signature(sig,meta)
end
function S.capture_tick(now)
local c=S.capture;if not c then return end
if now-c[1]>S.MAX_CAPTURE then S.capture_finish(now,true)
else sample(now);if not badge.input.is_down(badge.input.BUTTON.A) then S.capture_finish(now,false) end end
end
