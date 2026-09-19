-- Banded DTW, adaptive per-spell thresholds, ambiguity rejection.
local min,max,sqrt=math.min,math.max,math.sqrt
local N,BAND,FQ,INF=16,3,32,1e30
local TRAIN_MAX=0.85
local TMIN,TMAX,TDEF=0.34,0.68,0.48
local RATIO=0.88
local prev,cur={},{}
local function cost(a,i,b,j)
  local x=(i-1)*3+1;local y=(j-1)*3+1
  local p=(a:byte(x)-b:byte(y))/FQ
  local q=(a:byte(x+1)-b:byte(y+1))/FQ
  local r=(a:byte(x+2)-b:byte(y+2))/FQ
  return (p*p+q*q+r*r)/3
end
local function distance(a,b)
  if type(a)~="string" or type(b)~="string" or #a~=48 or #b~=48 then return 99 end
  for j=0,N do prev[j]=INF;cur[j]=INF end;prev[0]=0
  for i=1,N do
    for j=0,N do cur[j]=INF end
    local lo,hi=max(1,i-BAND),min(N,i+BAND)
    for j=lo,hi do cur[j]=cost(a,i,b,j)+min(prev[j],prev[j-1],cur[j-1]) end
    prev,cur=cur,prev
  end
  return sqrt(prev[N]/N)
end
local function class_score(sig,t)
  if not t or #t==0 then return 99 end
  local a,b=99,99
  for _,v in ipairs(t) do
    local d=distance(sig,v)
    if d<a then b,a=a,d elseif d<b then b=d end
  end
  return #t==1 and a or (a+b)/2
end
local function clamp(v,a,b) return min(b,max(a,v)) end
local function calibrate(t)
  if not t or #t<2 then return TDEF,0,0 end
  local largest,total,n=0,0,0
  for i=1,#t-1 do for j=i+1,#t do
    local d=distance(t[i],t[j]);largest=max(largest,d);total=total+d;n=n+1
  end end
  return clamp(largest*1.35+0.08,TMIN,TMAX),largest,total/max(1,n)
end
local function recognize(sig,model,thresholds)
  model=model or {{},{},{}};thresholds=thresholds or {}
  local scores={99,99,99};local best,runner,bd,rd=nil,nil,99,99
  for s=1,3 do
    local d=class_score(sig,model[s]);scores[s]=d
    if d<bd then runner,rd=best,bd;best,bd=s,d elseif d<rd then runner,rd=s,d end
  end
  if not best or bd>=99 then return nil,"Teach this spell first",bd,{scores=scores} end
  local th=thresholds[best] or TDEF
  local ratio=rd<99 and (rd>0 and bd/rd or 1) or 0
  local diag={scores=scores,best=best,runner=runner,threshold=th,ratio=ratio}
  if bd>th then return nil,"Fizzle - outside learned range",bd,diag end
  if rd<99 and bd>=rd*RATIO then return nil,"Ambiguous - try again",bd,diag end
  return best,"Learned gesture",bd,diag
end
return {distance=distance,class_score=class_score,calibrate=calibrate,recognize=recognize,train_max=TRAIN_MAX}
