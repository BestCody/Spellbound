-- Side-effect discovery/retry tick plus lazy duel renderer.
local S=SPELLBOUND_STATE
function S.advance(g,now)
  if g[1]~=0 then return end
  for p=1,2 do
    local ii=7+p;local si=5+p;local hi=1+p
    if g[ii]>0 and now>=g[ii] then
      if g[si]>=g[ii] then g[si]=0 else g[hi]=math.max(0,g[hi]-25) end
      g[ii]=0
    end
  end
  if g[2]==0 and g[3]==0 then g[1]=3 elseif g[2]==0 then g[1]=2 elseif g[3]==0 then g[1]=1 end
end
function S.network_tick(now)
  local phase=S.phase
  if phase=="lobby" then
    for i=#S.peers-2,1,-3 do if now-S.peers[i+1]>4000 then table.remove(S.peers,i+2);table.remove(S.peers,i+1);table.remove(S.peers,i) end end
    S.selected=math.min(math.max(S.selected,1),math.max(1,#S.peers/3))
    if now>=S.next_tx then badge.radio.send("SB2H");S.next_tx=now+850 end
  elseif phase=="offer" then
    if now>S.deadline then S.invite=nil;S.phase="lobby" end
  elseif phase=="waiting" or phase=="joining" then
    if now>S.deadline then S.end_link();return end
    if now>=S.next_tx then
      S.transmit(phase=="waiting" and "I" or "J",
        phase=="waiting" and S.peer or nil)
      S.next_tx=now+600
    end
  elseif phase=="duel" or phase=="result" then
    if phase=="duel" and now-S.last_rx>6000 then S.end_link();return end
    if S.role=="host" and S.match then
      local hp,attack=S.match[2],S.match[8];S.advance(S.match,now)
      if S.match[2]<hp then S.effect,S.effect_until=5,now+700
      elseif attack>0 and S.match[8]==0 and S.match[1]==0 then S.effect,S.effect_until=6,now+700 end
      if S.match[1]~=0 then
        S.phase,S.capture="result",nil
        if S.match[1]==1 then S.effect,S.effect_until=7,now+60000 end
      end
      if now-S.last_state_tx>=200 then S.send_state(now) end
    elseif S.role=="guest" then
      if now-S.last_state_tx>=750 then S.transmit("P");S.last_state_tx=now end
      if S.pending and now>=S.pending[3] then
        S.transmit("C",string.format("%04X%s",S.pending[1],
          S.pending[2]==4 and "X" or S.codes:sub(S.pending[2],S.pending[2])))
        S.pending[3]=now+350
        if now-S.pending[4]>5000 then S.end_link() end
      end
    end
  end
end
