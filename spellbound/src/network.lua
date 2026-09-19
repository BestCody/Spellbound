-- Side-effect radio coordinator and multiplayer buttons. Network state allocates only on first duel.
local S=SPELLBOUND_STATE
S.peers=S.peers or {}
function S.end_link()
  S.locally_ended=true
  if S.match then S.match[1]=4 end
  if S.view then S.view[1]=4 end
  S.phase,S.pending,S.capture="result",nil,nil
  S.effect,S.effect_until=0,0
  S.message("Link ended",nil,60000)
end
function S.transmit(kind,data)
  if S.sid then return badge.radio.send("SB2"..kind..S.sid..(data or "")) end
end
function S.send_state(now)
  S.revision=(S.revision or 0)+1
  if S.revision>65535 then S.match[1]=4;S.revision=65535 end
  S.transmit("T",string.format("%04X",S.revision)..S.codec(0,S.match,now))
  S.last_state_tx=now
end
function S.feedback(code,spell)
  if code~=0 then S.message("Cast rejected",4);return end
  S.message(spell==4 and "You surrendered" or (S.spells[spell].." cast"),spell==4 and nil or spell)
end
function S.submit(spell)
  if S.phase~="duel" then return end
  local now=S.clock()
  if S.role=="host" then
    S.feedback(S.apply(S.match,1,spell,0,now),spell);S.send_state(now)
  else
    if S.pending then S.message("Wait for cast");return end
    if S.seq>=65534 then S.message("Match ended");return end
    S.seq=S.seq+1;S.pending={S.seq,spell,now,now}
  end
end
