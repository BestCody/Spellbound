if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
local raw_sample,signature=S[47],S[58]
local function accel()
local x,y,z=badge.sensor.accel()
if type(x)=="number" and type(y)=="number" and type(z)=="number" and x==x and y==y and z==z
and math.max(math.abs(x),math.abs(y),math.abs(z))<=32000 then return x,y,z end
end
local function sample(now)
local c=S[5];if not c or now-c[2]<20 then return end
local x,y,z=accel();if not x then c[4]=true;return end
if now-c[1]<=S[1] then c[3]=c[3]..raw_sample(x,y,z) end
c[2]=now
end
S[6]=function(now,event)
if event==0 then
local x,y,z=accel()
if not x then S[30]("Sensor unavailable",4);return end
S[5]={now,now,raw_sample(x,y,z),false};S[15]=0;return
end
local c=S[5];if not c then return end
local long=now-c[1]>S[1]
if event==2 and not long then
sample(now);if badge.input.is_down(badge.input.BUTTON.A) then return end
else sample(now) end
c=S[5];local raw,bad=c[3],c[4];S[5]=nil
if bad or long then S[30](long and "Hold too long" or "Try again",4);return end
local sig,err=signature(raw);raw=nil
if not sig then S[30](err or "No clear movement",4);return end
S[20](sig)
end
