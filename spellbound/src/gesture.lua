-- Spellbound original source, MIT license.
local floor,min,max,sqrt=math.floor,math.min,math.max,math.sqrt
local SB={nodes=16,max_capture=3000,deadband=96}
local function clamp(v,a,b) return min(b,max(a,v)) end
local function round(v) return floor(v+0.5) end
-- Captures are packed timestamp/x/y/z bytes, not per-sample Lua tables.
-- Sensor values are quantized to 32 mg; signatures remain 16 XYZ nodes / 48 bytes.
-- Resampling is by cumulative motion distance, so pauses and speed changes do not
-- move signature nodes through time. The deadband ignores small stationary jitter.
local function raw_sample(t,x,y,z)
  return string.char(floor(t/256), t%256,
    clamp(round(x/32)+128,1,255), clamp(round(y/32)+128,1,255),
    clamp(round(z/32)+128,1,255))
end
local function unpack_sample(s,i)
  local a,b,x,y,z=s:byte(i,i+4)
  return a*256+b,(x-128)*32,(y-128)*32,(z-128)*32
end
local function signature(raw)
  local n=#raw/5
  if n<8 or n~=floor(n) then return nil,"Too few motion samples" end
  local duration=select(1,unpack_sample(raw,#raw-4))
  if duration<250 or duration>SB.max_capture then return nil,"Use a 0.25-3.0s movement" end

  local _,bx,by,bz=unpack_sample(raw,1)
  local ax,ay,az=bx,by,bz
  local total,movement=0,0
  for i=6,#raw,5 do
    local _,x,y,z=unpack_sample(raw,i)
    local dx,dy,dz=x-ax,y-ay,z-az
    local step=sqrt(dx*dx+dy*dy+dz*dz)
    if step>=SB.deadband then
      total=total+step
      ax,ay,az=x,y,z
    end
    local rx,ry,rz=x-bx,y-by,z-bz
    movement=max(movement,sqrt(rx*rx+ry*ry+rz*rz))
  end
  if movement<260 or total<260 then return nil,"No clear movement" end

  local out={string.char(128,128,128)}
  local idx,cum=6,0
  ax,ay,az=bx,by,bz
  local sx,sy,sz,ex,ey,ez,seg_start,seg_end
  local function next_segment()
    while idx<=#raw do
      local _,x,y,z=unpack_sample(raw,idx);idx=idx+5
      local dx,dy,dz=x-ax,y-ay,z-az
      local step=sqrt(dx*dx+dy*dy+dz*dz)
      if step>=SB.deadband then
        sx,sy,sz=ax,ay,az;ex,ey,ez=x,y,z
        seg_start=cum;cum=cum+step;seg_end=cum
        ax,ay,az=x,y,z
        return true
      end
    end
    return false
  end

  local have=next_segment()
  for k=1,SB.nodes-1 do
    local target=total*k/(SB.nodes-1)
    while have and target>seg_end do have=next_segment() end
    if not have then ex,ey,ez=ax,ay,az;seg_start,seg_end=target,target+1 end
    local f=clamp((target-seg_start)/(seg_end-seg_start),0,1)
    local x=sx+(ex-sx)*f-bx
    local y=sy+(ey-sy)*f-by
    local z=sz+(ez-sz)*f-bz
    out[#out+1]=string.char(clamp(round(x/50)+128,1,255),
      clamp(round(y/50)+128,1,255),clamp(round(z/50)+128,1,255))
  end
  return table.concat(out),nil,duration
end
local function distance(a,b)
  if #a~=48 or #b~=48 then return 99 end
  local sum=0
  for i=1,48 do local d=(a:byte(i)-b:byte(i))*0.05;sum=sum+d*d end
  return sqrt(sum/48)
end
local function nearest(sig,model)
  local first,second,id=99,99,nil
  for s=1,3 do
    local d=99
    for _,t in ipairs(model[s]) do d=min(d,distance(sig,t)) end
    if d<first then second,first,id=first,d,s elseif d<second then second=d end
  end
  return id,first,second
end
local function recognize(sig,model)
  model=model or {{},{},{}}
  local id,d,runner=nearest(sig,model)
  if not id then return nil,"Teach this spell first",d end
  if d<=0.42 then
    if runner-d<0.09 or d>runner*0.78 then return nil,"Ambiguous - try again",d end
    return id,"Learned gesture",d
  end
  return nil,"Fizzle - no clear match",d
end

return {raw_sample=raw_sample,signature=signature,distance=distance,recognize=recognize}
