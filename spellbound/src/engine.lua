-- Side-effect flat host game engine and duel LED effects.
local S=SPELLBOUND_STATE
local min,max,floor=math.min,math.max,math.floor
local function clamp(v,a,b) return min(b,max(a,v)) end
local function new_match(now)
  return {0,100,100,75,75,0,0,0,0,0,0,0,0,0,0,0,0,now}
end
local function advance(g,now)
  if g[1]~=0 then return end
  for p=1,2 do
    local ii=7+p;local si=5+p;local hi=1+p
    if g[ii]>0 and now>=g[ii] then
      if g[si]>=g[ii] then g[si]=0 else g[hi]=max(0,g[hi]-25) end
      g[ii]=0
    end
  end
  if g[2]==0 and g[3]==0 then g[1]=3
  elseif g[2]==0 then g[1]=2 elseif g[3]==0 then g[1]=1 end
end
local function apply(g,p,spell,number,now)
  if p==2 and number~=g[16]+1 then return 5 end
  advance(g,now)
  local result=0
  local mi=p==1 and 4 or 5;local ti=p==1 and 9 or 12
  local ii=p==1 and 9 or 8;local si=p==1 and 6 or 7
  local cost=spell==1 and 30 or (spell==2 and 25 or 0)
  if g[1]~=0 then result=4
  elseif spell==4 then g[1]=3-p
  elseif g[mi]<cost then result=1
  elseif now<g[ti+spell] then result=2
  elseif spell==1 and g[ii]>0 then result=3
  else
    g[mi]=clamp(g[mi]-cost+(spell==3 and 35 or 0),0,100)
    g[ti+spell]=now+(spell==3 and 3000 or 2400)
    if spell==1 then g[ii]=now+1800 elseif spell==2 then g[si]=now+2200 end
  end
  if p==2 then g[16],g[17]=number,result end
  return result
end
local function rem(t,now) return clamp(math.ceil(max(0,t-now)/20),0,255) end
local function pack_state(g,now)
  return string.format("%X%02X%02X%02X%02X%02X%02X%02X%02X%04X%X",
    g[1],g[2],g[3],g[4],g[5],rem(g[6],now),rem(g[7],now),
    rem(g[8],now),rem(g[9],now),g[16],g[17])
end
local function hex(s,a,b) return tonumber(s:sub(a,b),16) end
local function unpack_state(s,now)
  if #s~=22 or s:find("[^0-9A-F]") then return nil end
  local g={hex(s,1,1),hex(s,2,3),hex(s,4,5),hex(s,6,7),hex(s,8,9),
    now+hex(s,10,11)*20,now+hex(s,12,13)*20,hex(s,14,15),hex(s,16,17),
    0,0,0,0,0,0,hex(s,18,21),hex(s,22,22),now}
  if g[1]>4 or g[17]>5 or g[2]>100 or g[3]>100 or g[4]>100 or g[5]>100 then return nil end
  g[8]=g[8]>0 and now+g[8]*20 or 0;g[9]=g[9]>0 and now+g[9]*20 or 0
  return g
end
S.new_match,S.apply,S.advance,S.pack_state,S.unpack_state=
  new_match,apply,advance,pack_state,unpack_state
function S.leds(now)
  local g=S.role=="host" and S.match or S.view
  local own=S.role=="host" and 1 or 2
  local mode=now<S.effect_until and S.effect or ""
  if S.phase=="result" and g and g[1]==own then mode="W"
  elseif S.phase=="duel" and g then
    local si=own==1 and 6 or 7;local ii=own==1 and 8 or 9
    if g[ii]>now then mode=g[si]>=g[ii] and "S" or "I"
    elseif g[si]>now and mode=="" then mode="S" end
  end
  badge.led.clear();local step=floor(now/150)%6+1
  if mode=="F" or mode=="I" then for n=1,6 do if n==step then badge.led.set(n,160,50,0) end end
  elseif mode=="S" or mode=="B" then badge.led.set_all(0,70,160)
  elseif mode=="R" then badge.led.set_all(0,160,100)
  elseif mode=="D" then badge.led.set_all(160,0,0)
  elseif mode=="W" then for n=1,6 do if n==step then badge.led.set(n,160,120,20) end end end
  badge.led.show()
end
