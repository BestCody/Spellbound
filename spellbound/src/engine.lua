-- Spellbound original source, MIT license.
local min,max=math.min,math.max
local costs,cooldowns={30,25,0},{2400,2400,3000}
local function clamp(v,a,b) return min(b,max(a,v)) end
-- Host game state. Index 1 is host; index 2 is guest. All rules use host time.
local function new_match(now)
  return {hp={100,100},mana={75,75},shield={0,0},incoming={0,0},
    cd={{0,0,0},{0,0,0}},result=0,ack=0,reply=0,started=now}
end
local function advance(g,now)
  if g.result~=0 then return end
  -- Resolve both due attacks before deciding the winner (draws are possible).
  for p=1,2 do
    if g.incoming[p]>0 and now>=g.incoming[p] then
      if g.shield[p]>=g.incoming[p] then g.shield[p]=0
      else g.hp[p]=max(0,g.hp[p]-25) end
      g.incoming[p]=0
    end
  end
  if g.hp[1]==0 and g.hp[2]==0 then g.result=3
  elseif g.hp[1]==0 then g.result=2 elseif g.hp[2]==0 then g.result=1 end
end
local function apply(g,p,spell,number,now)
  -- Reply: 0 accepted, 1 mana, 2 cooldown, 3 busy, 4 finished, 5 bad sequence.
  if p==2 and number~=g.ack+1 then return 5 end
  advance(g,now)
  local result=0
  if g.result~=0 then result=4
  elseif spell==4 then g.result=3-p
  elseif g.mana[p]<costs[spell] then result=1
  elseif now<g.cd[p][spell] then result=2
  elseif spell==1 and g.incoming[3-p]>0 then result=3
  else
    g.mana[p]=clamp(g.mana[p]-costs[spell]+(spell==3 and 35 or 0),0,100)
    g.cd[p][spell]=now+cooldowns[spell]
    if spell==1 then g.incoming[3-p]=now+1800
    elseif spell==2 then g.shield[p]=now+2200 end
  end
  if p==2 then g.ack,g.reply=number,result end
  return result
end
local function pack_state(g,now)
  local function rem(t) return clamp(math.ceil(max(0,t-now)/20),0,255) end
  return string.format("%X%02X%02X%02X%02X%02X%02X%02X%02X%04X%X",
    g.result,g.hp[1],g.hp[2],g.mana[1],g.mana[2],rem(g.shield[1]),rem(g.shield[2]),
    rem(g.incoming[1]),rem(g.incoming[2]),g.ack,g.reply)
end
local function unpack_state(s,now)
  if #s~=22 or s:find("[^0-9A-F]") then return nil end
  local function h(a,b) return tonumber(s:sub(a,b),16) end
  local g={result=h(1,1),hp={h(2,3),h(4,5)},mana={h(6,7),h(8,9)},
    shield={now+h(10,11)*20,now+h(12,13)*20},
    incoming={h(14,15),h(16,17)},ack=h(18,21),reply=h(22,22)}
  if g.result>4 or g.reply>5 or g.hp[1]>100 or g.hp[2]>100 or g.mana[1]>100 or g.mana[2]>100 then return nil end
  for p=1,2 do g.incoming[p]=g.incoming[p]>0 and (now+g.incoming[p]*20) or 0 end
  return g
end

return {new_match=new_match,apply=apply,advance=advance,pack=pack_state,unpack=unpack_state}
