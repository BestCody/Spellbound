-- Radio discovery/retry/match tick.
return function(S)
  function S.network_tick(now)
    if not S.radio_ok then return end
    if S.phase=="lobby" then
      for i=#S.peers,1,-1 do if now-S.peers[i].seen>4000 then table.remove(S.peers,i) end end
      S.selected=S.clamp(S.selected,1,math.max(1,#S.peers))
      if now>=S.next_tx then badge.radio.send("SB1|H");S.next_tx=now+850 end
    elseif S.phase=="offer" then
      if now>S.deadline then S.invite=nil;S.phase="lobby" end
    elseif S.phase=="waiting" or S.phase=="starting" or S.phase=="joining" then
      if now>S.deadline then S.end_link("Pairing timed out - try again");return end
      if now>=S.next_tx then
        S.transmit(S.phase=="waiting" and "I" or (S.phase=="starting" and "S" or "J"),S.phase=="waiting" and S.peer or nil)
        S.next_tx=now+600
      end
    elseif S.phase=="duel" or S.phase=="result" then
      if S.phase=="duel" and now-S.last_rx>6000 then S.end_link("Link lost - match cancelled");return end
      if S.role=="host" and S.match then
        S.ensure_engine();local hp,attack=S.match.hp[1],S.match.incoming[1];S.advance(S.match,now)
        if S.match.hp[1]<hp then S.effect,S.effect_until="D",now+700
        elseif attack>0 and S.match.incoming[1]==0 and S.match.result==0 then S.effect,S.effect_until="B",now+700 end
        if S.match.result~=0 then S.phase,S.capture="result",nil end
        if now-S.last_state_tx>=200 then S.send_state(now) end
      elseif S.role=="guest" then
        if now-S.last_ping>=750 then S.transmit("P");S.last_ping=now end
        if S.pending and now>=S.pending.next then
          S.transmit("C",string.format("%04X|%s",S.pending.seq,S.pending.spell==4 and "X" or S.codes[S.pending.spell]))
          S.pending.next=now+350
          if now-S.pending.started>5000 then S.end_link("Cast not acknowledged - cancelled") end
        end
      end
    end
  end
end
