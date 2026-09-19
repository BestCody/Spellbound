if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
local floor,min,max,sqrt=math.floor,math.min,math.max,math.sqrt
local RQ=64
local function clamp(v,a,b) return min(b,max(a,v)) end
local function p8(v) return clamp(floor(v/RQ+128.5),1,255) end
local function raw_sample(x,y,z) return string.char(p8(x),p8(y),p8(z)) end
local function delta(raw,i,lag)
local p=(i-1)*3;local q=(i-2)*3
local r=max(0,(i-lag-1)*3);local s=max(0,(i-lag-2)*3)
local x,y,z=raw:byte(p+1,p+3);local a,b,c=raw:byte(q+1,q+3)
local u,v,w=raw:byte(r+1,r+3);local d,e,f=raw:byte(s+1,s+3)
return (x+a-u-d)*32,(y+b-v-e)*32,(z+c-w-f)*32
end
local function quant(v,rms) return clamp(floor(128.5+32*clamp(v/rms,-3.8,3.8)),1,255) end
local function signature(raw)
local n=#raw/3
if n<9 or n>226 or n~=floor(n) then return nil,"Try again" end
local bx,by,bz=0,0,0
for i=1,6 do
local p=(i-1)*3;local x,y,z=raw:byte(p+1,p+3);bx,by,bz=bx+x,by+y,bz+z
end
bx,by,bz=bx/6,by/6,bz/6
local start,mark
for i=5,n do
local p=(i-1)*3;local x,y,z=raw:byte(p+1,p+3);local a,b,c=delta(raw,i,3)
local dv=sqrt(a*a+b*b+c*c);local u,v,w=(x-bx)*RQ,(y-by)*RQ,(z-bz)*RQ
local base=sqrt(u*u+v*v+w*w)
if (dv>=80 and base>=80) or base>=180 then
if mark and i-mark<=2 then start=max(2,mark-2);break end
mark=i
end
end
if not start then return nil,"Try again" end
local last=start
for i=start+1,n do
local x,y,z=delta(raw,i,3);if sqrt(x*x+y*y+z*z)>=45 then last=i end
end
local finish=min(n,last+2)
if finish-start<8 or finish-start>140 then return nil,"Try again" end
local count=finish-start;local sum=0
for i=start+1,finish do local x,y,z=delta(raw,i,1);sum=sum+x*x+y*y+z*z end
local rms=sqrt(sum/count);if rms<18 then return nil,"Try again" end
local out=""
for k=0,15 do
local p=1+(count-1)*k/15;local a=floor(p);local f=p-a
local ia=min(finish,start+a);local ib=min(finish,ia+1)
local x,y,z=delta(raw,ia,1);local u,v,w=delta(raw,ib,1)
out=out..string.char(quant(x+(u-x)*f,rms),quant(y+(v-y)*f,rms),quant(z+(w-z)*f,rms))
end
return out
end
S[47],S[58]=raw_sample,signature
