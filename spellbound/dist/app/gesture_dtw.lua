if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
local min,max,sqrt=math.min,math.max,math.sqrt
local N,BAND,FQ,INF=16,3,32,1e30
local TDEF,RATIO=0.48,0.88
local row
local function distance(a,b)
if type(a)~="string" or type(b)~="string" or #a~=48 or #b~=48 then return 99 end
if not row then row={} end
for k=0,8 do row[k]=INF end
row[BAND+1]=0
for i=1,N do
local lo,hi=max(1,i-BAND),min(N,i+BAND)
local first,last=lo-i+BAND+1,hi-i+BAND+1;row[first-1]=INF
local x=(i-1)*3+1
for j=lo,hi do
local k=j-i+BAND+1
local y=(j-1)*3+1
local p=(a:byte(x)-b:byte(y))/FQ
local q=(a:byte(x+1)-b:byte(y+1))/FQ
local r=(a:byte(x+2)-b:byte(y+2))/FQ
row[k]=(p*p+q*q+r*r)/3+min(row[k+1],row[k],row[k-1])
end
row[last+1]=INF
end
return sqrt(row[BAND+1]/N)
end
local function recognize(sig,model)
model=model or {}
local best,bd,rd=nil,99,99
for s=1,3 do
local d=model[s] and distance(sig,model[s]) or 99
if d<bd then rd=bd;best,bd=s,d elseif d<rd then rd=d end
end
if not best or bd>=99 then return nil,"Teach spell first" end
if bd>TDEF or (rd<99 and bd>=rd*RATIO) then return nil,"Try again" end
return best
end
S[14],S[49]=distance,recognize
