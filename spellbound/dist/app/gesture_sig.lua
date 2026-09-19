-- Capture packing, activity segmentation, normalized derivative signature.
local floor,min,max,sqrt=math.floor,math.min,math.max,math.sqrt
local N,B=16,8
local RQ,FQ=32,32
local MAX_HOLD,MIN_ACTIVE,MAX_ACTIVE=4500,160,2800
local START_DV,START_BASE,START_STRONG,END_DV=80,80,180,45
local function clamp(v,a,b) return min(b,max(a,v)) end
local function round(v) return floor(v+0.5) end
local function p16(v)
  local q=clamp(round(v/RQ),-32768,32767)+32768
  return floor(q/256),q%256
end
local function raw_sample(t,x,y,z)
  t=clamp(floor(t),0,65535)
  local a,b=p16(x);local c,d=p16(y);local e,f=p16(z)
  return string.char(floor(t/256),t%256,a,b,c,d,e,f)
end
local function unpack(raw,p)
  local a,b,c,d,e,f,g,h=raw:byte(p,p+7)
  if not h then return nil end
  return a*256+b,(c*256+d-32768)*RQ,(e*256+f-32768)*RQ,(g*256+h-32768)*RQ
end
local function pos(i) return (i-1)*B+1 end
local function smooth(raw,n,i)
  local lo,hi=max(1,i-1),min(n,i+1)
  local x,y,z,c=0,0,0,0
  for j=lo,hi do
    local _,a,b,d=unpack(raw,pos(j));x,y,z,c=x+a,y+b,z+d,c+1
  end
  return x/c,y/c,z/c
end
local function mag(x,y,z) return sqrt(x*x+y*y+z*z) end
local function activity(raw,n,i)
  local x,y,z=smooth(raw,n,i);local a,b,c=smooth(raw,n,max(1,i-3))
  return mag(x-a,y-b,z-c)
end
local function deriv(raw,n,i)
  local x,y,z=smooth(raw,n,i);local a,b,c=smooth(raw,n,max(1,i-1))
  return x-a,y-b,z-c
end
local function signature(raw)
  local n=#raw/B
  if n<8 or n~=floor(n) then return nil,"Too few motion samples" end
  local hold=select(1,unpack(raw,pos(n)))
  if hold<160 or hold>MAX_HOLD then return nil,"Use a shorter A hold" end
  local bn=min(6,n);local bx,by,bz=0,0,0
  for i=1,bn do local _,x,y,z=unpack(raw,pos(i));bx,by,bz=bx+x,by+y,bz+z end
  bx,by,bz=bx/bn,by/bn,bz/bn
  local start,mark
  for i=5,n do
    local x,y,z=smooth(raw,n,i);local dv=activity(raw,n,i)
    local base=mag(x-bx,y-by,z-bz)
    if (dv>=START_DV and base>=START_BASE) or base>=START_STRONG then
      if mark and i-mark<=2 then start=max(2,mark-2);break end
      mark=i
    end
  end
  if not start then return nil,"No sustained movement" end
  local last=start
  for i=start+1,n do if activity(raw,n,i)>=END_DV then last=i end end
  local finish=min(n,last+2)
  local sm=select(1,unpack(raw,pos(start)));local em=select(1,unpack(raw,pos(finish)))
  local active=em-sm
  if active<MIN_ACTIVE then return nil,"Move a little longer" end
  if active>MAX_ACTIVE then return nil,"Gesture itself is too long" end
  local count=finish-start;local sum,peak=0,0
  for i=start+1,finish do
    local x,y,z=deriv(raw,n,i);local e=x*x+y*y+z*z
    sum=sum+e;peak=max(peak,sqrt(e))
  end
  local rms=sqrt(sum/max(1,count))
  if rms<18 then return nil,"No clear movement" end
  local out={}
  for k=0,N-1 do
    local p=1+(count-1)*k/(N-1);local a=floor(p);local f=p-a
    local ia=min(finish,start+a);local ib=min(finish,ia+1)
    local x,y,z=deriv(raw,n,ia);local u,v,w=deriv(raw,n,ib)
    local function q(t) return clamp(round(128+FQ*clamp(t/rms,-3.8,3.8)),1,255) end
    out[#out+1]=string.char(q(x+(u-x)*f),q(y+(v-y)*f),q(z+(w-z)*f))
  end
  return table.concat(out),nil,{hold_ms=hold,active_ms=active,samples=n,start_ms=sm,end_ms=em,peak_delta=round(peak),rms_delta=round(rms)}
end
return {raw_sample=raw_sample,signature=signature}
