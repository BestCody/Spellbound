if SPELLBOUND_STATE[4]~=4 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
local floor,min,max,sqrt=math.floor,math.min,math.max,math.sqrt
local N,B,RQ,FQ=16,5,64,32
local MAX_HOLD,MIN_ACTIVE,MAX_ACTIVE=4500,160,2800
local START_DV,START_BASE,START_STRONG,END_DV=80,80,180,45
local function clamp(v,a,b) return min(b,max(a,v)) end
local function round(v) return floor(v+0.5) end
local function p8(v) return clamp(round(v/RQ),-127,127)+128 end
local function raw_sample(t,x,y,z)
t=clamp(floor(t),0,65535)
return string.char(floor(t/256),t%256,p8(x),p8(y),p8(z))
end
local function unpack(raw,p)
local a,b,c,d,e=raw:byte(p,p+4)
if not e then return nil end
return a*256+b,(c-128)*RQ,(d-128)*RQ,(e-128)*RQ
end
local function delta(raw,n,i,lag)
local x,y,z,a,b,c,p,q=0,0,0,0,0,0,0,0
for j=max(1,i-1),min(n,i+1) do
local _,u,v,w=unpack(raw,(j-1)*B+1);x,y,z,p=x+u,y+v,z+w,p+1
end
i=max(1,i-lag)
for j=max(1,i-1),min(n,i+1) do
local _,u,v,w=unpack(raw,(j-1)*B+1);a,b,c,q=a+u,b+v,c+w,q+1
end
return x/p-a/q,y/p-b/q,z/p-c/q
end
local function signature(raw)
local n=#raw/B
if n<8 or n~=floor(n) then return nil,"Too few motion samples" end
local hold=select(1,unpack(raw,(n-1)*B+1))
if hold<160 or hold>MAX_HOLD then return nil,"Use a shorter A hold" end
local bn=min(6,n);local bx,by,bz=0,0,0
for i=1,bn do local _,x,y,z=unpack(raw,(i-1)*B+1);bx,by,bz=bx+x,by+y,bz+z end
bx,by,bz=bx/bn,by/bn,bz/bn
local start,mark
for i=5,n do
local _,x,y,z=unpack(raw,(i-1)*B+1);local a,b,c=delta(raw,n,i,3)
local dv=sqrt(a*a+b*b+c*c);local base=sqrt((x-bx)^2+(y-by)^2+(z-bz)^2)
if (dv>=START_DV and base>=START_BASE) or base>=START_STRONG then
if mark and i-mark<=2 then start=max(2,mark-2);break end
mark=i
end
end
if not start then return nil,"No sustained movement" end
local last=start
for i=start+1,n do
local x,y,z=delta(raw,n,i,3)
if sqrt(x*x+y*y+z*z)>=END_DV then last=i end
end
local finish=min(n,last+2)
local sm=select(1,unpack(raw,(start-1)*B+1));local em=select(1,unpack(raw,(finish-1)*B+1))
local active=em-sm
if active<MIN_ACTIVE then return nil,"Move a little longer" end
if active>MAX_ACTIVE then return nil,"Gesture itself is too long" end
local count=finish-start;local sum=0
for i=start+1,finish do
local x,y,z=delta(raw,n,i,1);local e=x*x+y*y+z*z
sum=sum+e
end
local rms=sqrt(sum/max(1,count))
if rms<18 then return nil,"No clear movement" end
local out=""
for k=0,N-1 do
local p=1+(count-1)*k/(N-1);local a=floor(p);local f=p-a
local ia=min(finish,start+a);local ib=min(finish,ia+1)
local x,y,z=delta(raw,n,ia,1);local u,v,w=delta(raw,n,ib,1)
local function q(t) return clamp(round(128+FQ*clamp(t/rms,-3.8,3.8)),1,255) end
out=out..string.char(q(x+(u-x)*f),q(y+(v-y)*f),q(z+(w-z)*f))
end
return out
end
S[51],S[62]=raw_sample,signature
