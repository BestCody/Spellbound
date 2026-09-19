if SPELLBOUND_STATE[4]~=4 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
local raw_sample,signature=S[51],S[62]
local function read_accel()
local x,y,z=badge.sensor.accel()
if type(x)=="number" and type(y)=="number" and type(z)=="number" and x==x and y==y and z==z
and math.max(math.abs(x),math.abs(y),math.abs(z))<=32000 then return x,y,z end
end
local function sample(now)
local c=S[5]
if not c or now-c[2]<20 then return end
local x,y,z=read_accel();if not x then c[4]=true;return end
local e=now-c[1]
if e<=S[1] then c[3]=c[3]..raw_sample(e,x,y,z) end
c[2]=now
end
S[7]=function(now)
local x,y,z=read_accel()
if not x then S[31]("Motion sensor unavailable / invalid",4);return end
S[5]={now,now,raw_sample(0,x,y,z),false};S[16]=0
end
S[6]=function(now,too_long)
local c=S[5];if not c then return end
sample(now);c=S[5]
local raw,bad=c[3],c[4];S[5]=nil
if bad or too_long then
S[31](too_long and "A hold too long - try again" or "Sensor sample invalid",4);return
end
local sig,err=signature(raw);raw=nil
if not sig then S[31](err or "No clear movement",4);return end
S[21](sig)
end
S[8]=function(now)
local c=S[5];if not c then return end
if now-c[1]>S[1] then S[6](now,true)
else sample(now);if not badge.input.is_down(badge.input.BUTTON.A) then S[6](now,false) end end
end
