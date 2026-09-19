-- Spellbound gesture recognizer: segmented normalized derivative DTW.
local floor,min,max,sqrt=math.floor,math.min,math.max,math.sqrt
local NODES,BAND,SAMPLE_BYTES=16,3,8
local RAW_Q,FEATURE_Q=32,32
local MAX_HOLD,MIN_ACTIVE,MAX_ACTIVE=4500,160,2800
local START_DV,START_BASE,START_STRONG,END_DV=80,80,180,45
local MIN_RMS=18
local TRAIN_MAX=0.85
local THRESH_MIN,THRESH_MAX,THRESH_DEFAULT=0.34,0.68,0.48
local AMBIG_RATIO=0.88
local INF=1e30

local function clamp(v,a,b) return min(b,max(a,v)) end
local function round(v) return floor(v+0.5) end
local function pack16(v)
  local q=clamp(round(v/RAW_Q),-32768,32767)+32768
  return floor(q/256),q%256
end

-- 8-byte transient sample: uint16 ms + int16 x/y/z at 32 mg resolution.
-- This removes the previous ~4 g byte-packing ceiling without changing the
-- compact learned template size (still 16 nodes x 3 bytes = 48 bytes).
local function raw_sample(t,x,y,z)
  t=clamp(floor(t),0,65535)
  local xh,xl=pack16(x);local yh,yl=pack16(y);local zh,zl=pack16(z)
  return string.char(floor(t/256),t%256,xh,xl,yh,yl,zh,zl)
end
local function unpack_sample(raw,pos)
  local th,tl,xh,xl,yh,yl,zh,zl=raw:byte(pos,pos+7)
  if not zl then return nil end
  return th*256+tl,(xh*256+xl-32768)*RAW_Q,
    (yh*256+yl-32768)*RAW_Q,(zh*256+zl-32768)*RAW_Q
end
local function sample_pos(i) return (i-1)*SAMPLE_BYTES+1 end

-- Three-sample moving average reduces cached-sensor jitter before derivatives.
local function smooth(raw,n,i)
  local lo,hi=max(1,i-1),min(n,i+1)
  local sx,sy,sz,c=0,0,0,0
  for j=lo,hi do
    local _,x,y,z=unpack_sample(raw,sample_pos(j))
    sx,sy,sz,c=sx+x,sy+y,sz+z,c+1
  end
  return sx/c,sy/c,sz/c
end
local function mag(x,y,z) return sqrt(x*x+y*y+z*z) end
local function lag_activity(raw,n,i)
  local x,y,z=smooth(raw,n,i)
  local a,b,c=smooth(raw,n,max(1,i-3))
  return mag(x-a,y-b,z-c)
end
local function derivative(raw,n,i)
  local x,y,z=smooth(raw,n,i)
  local a,b,c=smooth(raw,n,max(1,i-1))
  return x-a,y-b,z-c
end

local function signature(raw)
  local n=#raw/SAMPLE_BYTES
  if n<8 or n~=floor(n) then return nil,"Too few motion samples" end
  local hold_ms=select(1,unpack_sample(raw,sample_pos(n)))
  if hold_ms<160 or hold_ms>MAX_HOLD then return nil,"Use a shorter A hold" end

  -- Stable initial reference: average six readings instead of trusting one
  -- button-press sample. Derivatives below remove constant gravity/baseline.
  local base_n=min(6,n)
  local bx,by,bz=0,0,0
  for i=1,base_n do
    local _,x,y,z=unpack_sample(raw,sample_pos(i))
    bx,by,bz=bx+x,by+y,bz+z
  end
  bx,by,bz=bx/base_n,by/base_n,bz/base_n

  -- Activity segmentation. Start uses both short-lag motion and distance from
  -- the initial reference; end uses only short-lag motion so ending at a new
  -- orientation does not make trailing idle look active. We scan the complete
  -- A-hold, so brief pauses inside the gesture are retained rather than ending
  -- the segment early.
  local start,prev_mark=nil,nil
  for i=5,n do
    local x,y,z=smooth(raw,n,i)
    local dv=lag_activity(raw,n,i)
    local base=mag(x-bx,y-by,z-bz)
    local active=(dv>=START_DV and base>=START_BASE) or base>=START_STRONG
    if active then
      if prev_mark and i-prev_mark<=2 then start=max(2,prev_mark-2);break end
      prev_mark=i
    end
  end
  if not start then return nil,"No sustained movement" end

  local last=start
  for i=start+1,n do if lag_activity(raw,n,i)>=END_DV then last=i end end
  local finish=min(n,last+2)
  local start_ms=select(1,unpack_sample(raw,sample_pos(start)))
  local end_ms=select(1,unpack_sample(raw,sample_pos(finish)))
  local active_ms=end_ms-start_ms
  if active_ms<MIN_ACTIVE then return nil,"Move a little longer" end
  if active_ms>MAX_ACTIVE then return nil,"Gesture itself is too long" end

  -- High-pass-ish representation: derivatives of smoothed acceleration.
  -- Normalize by RMS motion energy so gentle/strong repetitions have similar
  -- amplitude. Resample to 16 nodes; DTW later absorbs local timing changes.
  local count=finish-start
  local sumsq,peak=0,0
  for i=start+1,finish do
    local dx,dy,dz=derivative(raw,n,i)
    local e=dx*dx+dy*dy+dz*dz
    sumsq=sumsq+e;peak=max(peak,sqrt(e))
  end
  local rms=sqrt(sumsq/max(1,count))
  if rms<MIN_RMS then return nil,"No clear movement" end

  local out={}
  for k=0,NODES-1 do
    local p=1+(count-1)*k/(NODES-1)
    local a=floor(p);local f=p-a
    local ia=min(finish,start+a)
    local ib=min(finish,ia+1)
    local ax,ay,az=derivative(raw,n,ia)
    local bx2,by2,bz2=derivative(raw,n,ib)
    local dx=ax+(bx2-ax)*f
    local dy=ay+(by2-ay)*f
    local dz=az+(bz2-az)*f
    local function q(v)
      return clamp(round(128+FEATURE_Q*clamp(v/rms,-3.8,3.8)),1,255)
    end
    out[#out+1]=string.char(q(dx),q(dy),q(dz))
  end

  return table.concat(out),nil,{
    hold_ms=hold_ms,active_ms=active_ms,samples=n,start_ms=start_ms,end_ms=end_ms,
    peak_delta=round(peak),rms_delta=round(rms)
  }
end

-- Reused DTW rows keep working memory bounded. The Sakoe-Chiba-style band of
-- +/-3 nodes permits local speed variation without allowing arbitrary warping.
local prev,cur={},{}
local function node_cost(a,i,b,j)
  local ap=(i-1)*3+1;local bp=(j-1)*3+1
  local dx=(a:byte(ap)-b:byte(bp))/FEATURE_Q
  local dy=(a:byte(ap+1)-b:byte(bp+1))/FEATURE_Q
  local dz=(a:byte(ap+2)-b:byte(bp+2))/FEATURE_Q
  return (dx*dx+dy*dy+dz*dz)/3
end
local function distance(a,b)
  if type(a)~="string" or type(b)~="string" or #a~=48 or #b~=48 then return 99 end
  for j=0,NODES do prev[j]=INF;cur[j]=INF end
  prev[0]=0
  for i=1,NODES do
    for j=0,NODES do cur[j]=INF end
    local lo,hi=max(1,i-BAND),min(NODES,i+BAND)
    for j=lo,hi do
      cur[j]=node_cost(a,i,b,j)+min(prev[j],prev[j-1],cur[j-1])
    end
    prev,cur=cur,prev
  end
  return sqrt(prev[NODES]/NODES)
end

local function class_score(sig,templates)
  if not templates or #templates==0 then return 99 end
  local first,second=99,99
  for _,t in ipairs(templates) do
    local d=distance(sig,t)
    if d<first then second,first=first,d elseif d<second then second=d end
  end
  if #templates==1 then return first end
  return (first+second)/2
end

-- Learn tolerance from the user's own three examples. A floor preserves useful
-- tolerance when examples are nearly identical; a cap prevents an inconsistent
-- class from becoming a catch-all.
local function calibrate(templates)
  if not templates or #templates<2 then return THRESH_DEFAULT,0,0 end
  local largest,total,pairs=0,0,0
  for i=1,#templates-1 do
    for j=i+1,#templates do
      local d=distance(templates[i],templates[j])
      largest=max(largest,d);total=total+d;pairs=pairs+1
    end
  end
  local mean=total/max(1,pairs)
  local threshold=clamp(largest*1.35+0.08,THRESH_MIN,THRESH_MAX)
  return threshold,largest,mean
end

-- One ambiguity criterion only: the best class must beat the runner-up by a
-- relative margin. Per-class acceptance uses its learned threshold.
local function recognize(sig,model,thresholds)
  model=model or {{},{},{}}
  thresholds=thresholds or {}
  local scores={99,99,99}
  local best,runner,best_score,runner_score=nil,nil,99,99
  for s=1,3 do
    local score=class_score(sig,model[s]);scores[s]=score
    if score<best_score then
      runner,runner_score=best,best_score
      best,best_score=s,score
    elseif score<runner_score then runner,runner_score=s,score end
  end
  if not best or best_score>=99 then
    return nil,"Teach this spell first",best_score,{scores=scores}
  end

  local threshold=thresholds[best] or THRESH_DEFAULT
  local ratio=runner_score<99 and (runner_score>0 and best_score/runner_score or 1) or 0
  local diag={scores=scores,best=best,runner=runner,threshold=threshold,ratio=ratio}
  if best_score>threshold then
    return nil,"Fizzle - outside learned range",best_score,diag
  end
  if runner_score<99 and best_score>runner_score*AMBIG_RATIO then
    return nil,"Ambiguous - try again",best_score,diag
  end
  return best,"Learned gesture",best_score,diag
end

return {
  raw_sample=raw_sample,signature=signature,distance=distance,
  class_score=class_score,calibrate=calibrate,recognize=recognize,
  train_max=TRAIN_MAX
}
