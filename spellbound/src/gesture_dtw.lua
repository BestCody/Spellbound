-- Side-effect DTW classifier. Work rows allocate lazily and retain only 14 numeric cells.
local S=SPELLBOUND_STATE
local min,max,sqrt=math.min,math.max,math.sqrt
local N,BAND,FQ,INF=16,3,32,1e30
local TRAIN_MAX,TMIN,TMAX,TDEF,RATIO=0.85,0.34,0.68,0.48,0.88
local prev,cur
local function cost(a,i,b,j)
  local x=(i-1)*3+1;local y=(j-1)*3+1
  local p=(a:byte(x)-b:byte(y))/FQ
  local q=(a:byte(x+1)-b:byte(y+1))/FQ
  local r=(a:byte(x+2)-b:byte(y+2))/FQ
  return (p*p+q*q+r*r)/3
end
local function distance(a,b)
  if type(a)~="string" or type(b)~="string" or #a~=48 or #b~=48 then return 99 end
  if not prev then prev,cur={},{} end
  for k=1,7 do prev[k]=INF;cur[k]=INF end
  prev[BAND+1]=0
  for i=1,N do
    for k=1,7 do cur[k]=INF end
    local lo,hi=max(1,i-BAND),min(N,i+BAND)
    for j=lo,hi do
      local k=j-i+BAND+1
      cur[k]=cost(a,i,b,j)+min(prev[k+1] or INF,prev[k],cur[k-1] or INF)
    end
    prev,cur=cur,prev
  end
  return sqrt(prev[BAND+1]/N)
end
local function class_score(sig,t)
  if not t or #t==0 then return 99 end
  local a,b=99,99
  for i=1,#t do
    local d=distance(sig,t[i])
    if d<a then b,a=a,d elseif d<b then b=d end
  end
  return #t==1 and a or (a+b)/2
end
local function calibrate(t)
  if not t or #t<2 then return TDEF,0,0 end
  local largest,total,n=0,0,0
  for i=1,#t-1 do for j=i+1,#t do
    local d=distance(t[i],t[j]);largest=max(largest,d);total=total+d;n=n+1
  end end
  return min(TMAX,max(TMIN,largest*1.35+0.08)),largest,total/max(1,n)
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
S.distance,S.class_score,S.calibrate,S.recognize,S.train_max=
  distance,class_score,calibrate,recognize,TRAIN_MAX
