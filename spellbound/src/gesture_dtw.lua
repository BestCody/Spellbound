-- Side-effect DTW classifier. Work rows allocate lazily and retain only 14 numeric cells.
local S=SPELLBOUND_STATE
local min,max,sqrt=math.min,math.max,math.sqrt
local N,BAND,FQ,INF=16,3,32,1e30
local TDEF,RATIO=0.48,0.88
local prev,cur
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
      local x=(i-1)*3+1
      local y=(j-1)*3+1
      local p=(a:byte(x)-b:byte(y))/FQ
      local q=(a:byte(x+1)-b:byte(y+1))/FQ
      local r=(a:byte(x+2)-b:byte(y+2))/FQ
      cur[k]=(p*p+q*q+r*r)/3+min(prev[k+1] or INF,prev[k],cur[k-1] or INF)
    end
    prev,cur=cur,prev
  end
  return sqrt(prev[BAND+1]/N)
end
local function recognize(sig,model)
  model=model or {}
  local best,bd,rd=nil,99,99
  for s=1,3 do
    local d=model[s] and distance(sig,model[s]) or 99
    if d<bd then rd=bd;best,bd=s,d elseif d<rd then rd=d end
  end
  if not best or bd>=99 then return nil,"Teach this spell first",bd end
  local ratio=rd<99 and (rd>0 and bd/rd or 1) or 0
  if bd>TDEF then return nil,"Fizzle - outside learned range",bd end
  if rd<99 and bd>=rd*RATIO then return nil,"Ambiguous - try again",bd end
  return best,"Learned gesture",bd
end
S.distance,S.recognize=distance,recognize
