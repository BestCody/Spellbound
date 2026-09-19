-- Shared Spellbound state and low-cost helpers.
local min,max,floor=math.min,math.max,math.floor
local S={
  MAX_CAPTURE=4500, LED=160,
  spells={"Fireball","Shield","Recharge"}, codes={"F","S","R"},
  reject_messages={"Not enough mana","Spell cooling down","Attack already in flight","Match finished","Out-of-order action"},
  phase="home", selected=1, role=nil, me="", peer=nil, sid=nil, radio_ok=false,
  peers={}, invite=nil, match=nil, pending=nil, view=nil,
  declined=nil, declined_until=0, seq=0, revision=0, last_revision=-1,
  last_rx=0, next_tx=0, next_ui=0, next_led=0, last_state_tx=0, last_ping=0, deadline=0,
  capture=nil, training=nil, models={{},{},{}}, thresholds={nil,nil,nil}, note="", note_until=0, effect="", effect_until=0,
  leave_until=0, radio_started=false, widgets={}, text_cache={}, visible_phase=nil,
  next_gc=0, locally_ended=false,
}

function S.clamp(v,a,b) return min(b,max(a,v)) end
function S.round(v) return floor(v+0.5) end
function S.clock() return badge.sys.ms() end
function S.mac_key(v)
  if type(v)~="string" then return nil end
  local s=string.upper((v:gsub(":","")))
  if #s~=12 or s:find("[^0-9A-F]") then return nil end
  return s
end
function S.message(s,fx,duration)
  S.note,S.note_until=s,S.clock()+(duration or 2000)
  if fx then S.effect,S.effect_until=fx,S.clock()+700 end
end
function S.reset_home()
  S.phase,S.selected,S.role="home",1,nil
  S.peer,S.sid,S.match,S.pending,S.view,S.invite,S.capture,S.training=nil,nil,nil,nil,nil,nil,nil,nil
  S.seq,S.revision,S.last_revision=0,0,-1
  S.next_tx,S.leave_until,S.locally_ended=0,0,false
  S.note,S.note_until,S.effect,S.effect_until="",0,"",0
end
function S.end_link(reason)
  S.locally_ended=true
  if S.match then S.match.result=4 end
  if S.view then S.view.result=4 end
  S.phase,S.pending,S.capture="result",nil,nil
  S.effect,S.effect_until="",0
  S.message(reason,nil,60000)
end
return S
