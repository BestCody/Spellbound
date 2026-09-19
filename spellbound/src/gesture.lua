-- Spellbound original source, MIT license.
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local SB={nodes=16,max_capture=2400}
local function clamp(v,a,b) return min(b,max(a,v)) end
local function round(v) return floor(v+0.5) end
-- Captures are packed timestamp/x/y/z bytes, not per-sample Lua tables.
-- Sensor values are quantized to 32 mg; resampled signatures use 50 mg.
local function raw_sample(t,x,y,z)
  return string.char(floor(t/256), t%256,
    clamp(round(x/32)+128,1,255), clamp(round(y/32)+128,1,255),
    clamp(round(z/32)+128,1,255))
end
local function unpack_sample(s,i)
  local a,b,x,y,z = s:byte(i,i+4)
  return a*256+b,(x-128)*32,(y-128)*32,(z-128)*32
end
local function signature(raw)
  local n = #raw/5
  if n < 8 or n ~= floor(n) then return nil,"Too few motion samples" end
  local duration = select(1,unpack_sample(raw,#raw-4))
  if duration < 300 or duration > SB.max_capture then return nil,"Use a 0.3-2.4s movement" end
  local _,bx,by,bz = unpack_sample(raw,1)
  local out, j, movement = {}, 1, 0
  for k=0,SB.nodes-1 do
    local target = duration*k/(SB.nodes-1)
    while j < n-1 and select(1,unpack_sample(raw,j*5+1)) < target do j=j+1 end
    local t,x,y,z = unpack_sample(raw,(j-1)*5+1)
    local u,a,b,c = unpack_sample(raw,j*5+1)
    if u <= t then return nil,"Invalid sample timing" end
    local f=clamp((target-t)/(u-t),0,1)
    local dx,dy,dz = x+(a-x)*f-bx, y+(b-y)*f-by, z+(c-z)*f-bz
    movement=max(movement,math.sqrt(dx*dx+dy*dy+dz*dz))
    out[#out+1]=string.char(clamp(round(dx/50)+128,1,255),
      clamp(round(dy/50)+128,1,255),clamp(round(dz/50)+128,1,255))
  end
  if movement < 260 then return nil,"No clear movement" end
  return table.concat(out),nil,duration
end
local function distance(a,b)
  if #a ~= 48 or #b ~= 48 then return 99 end
  local sum=0
  for i=1,48 do local d=(a:byte(i)-b:byte(i))*0.05; sum=sum+d*d end
  return math.sqrt(sum/48)
end
local function nearest(sig, model)
  local first,second,id=99,99,nil
  for s=1,3 do
    local d=99
    for _,t in ipairs(model[s]) do d=min(d,distance(sig,t)) end
    if d<first then second,first,id=first,d,s elseif d<second then second=d end
  end
  return id,first,second
end
-- Experimental defaults, deliberately conservative. Personal training avoids
-- assumptions about the badge's physical axis orientation.
local function preset(sig)
  local peak,tail,axis,range=0,0,1,0
  for a=1,3 do
    local lo,hi=0,0
    for i=a,48,3 do local v=(sig:byte(i)-128)*0.05;lo=min(lo,v);hi=max(hi,v) end
    if hi-lo>range then range,axis=hi-lo,a end
  end
  local flips,last=0,0
  for k=0,15 do
    local i=k*3+1
    local x,y,z=(sig:byte(i)-128)*0.05,(sig:byte(i+1)-128)*0.05,(sig:byte(i+2)-128)*0.05
    peak=max(peak,math.sqrt(x*x+y*y+z*z))
    local v=(sig:byte(k*3+axis)-128)*0.05
    local sign=v>0.28 and 1 or (v< -0.28 and -1 or 0)
    if sign~=0 then if last~=0 and sign~=last then flips=flips+1 end;last=sign end
  end
  local e1,e2,e3=(sig:byte(46)-128)*0.05,(sig:byte(47)-128)*0.05,(sig:byte(48)-128)*0.05
  local endpoint=math.sqrt(e1*e1+e2*e2+e3*e3)
  for i=40,45 do tail=max(tail,abs(sig:byte(i)-sig:byte(46+(i-40)%3))*0.05) end
  if peak>3.4 then return nil end
  if flips>=3 and flips<=6 and range>0.85 and endpoint<0.65 then return 3 end
  if endpoint>0.8 and endpoint<2.15 and tail<0.25 and flips<=1 then return 2 end
  if flips==1 and range>1.2 and endpoint<0.50 then return 1 end
end
local function recognize(sig, model)
  model=model or {{},{},{}}
  local id,d,runner=nearest(sig,model)
  if id and d<=0.42 then
    if runner-d<0.09 or d>runner*0.78 then return nil,"Ambiguous - try again",d end
    return id,"Learned gesture",d
  end
  local p=preset(sig)
  if p and #model[p]==0 then return p,"Preset (calibrate for accuracy)",d end
  return nil,"Fizzle - no clear match",d
end


return {raw_sample=raw_sample,signature=signature,distance=distance,recognize=recognize,preset=preset}
