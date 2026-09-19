-- Multiplayer button state machine, loaded only with radio mode.
return function(S)
  function S.net_button(button,kind,now)
    local B,K=badge.input.BUTTON,badge.input.KIND
    if kind~=K.PRESSED then return end
    if button==B.B then
      S.capture=nil
      if S.phase=="duel" then
        if now<S.leave_until then if S.submit then S.submit(4) end;S.leave_until=0
        else S.leave_until=now+1800;S.message("Press B again to surrender",nil,1800) end
      elseif S.phase=="offer" then
        S.declined,S.declined_until=S.invite.peer..S.invite.sid,now+14000
        badge.radio.send("SB1|Q|"..S.invite.sid);S.invite=nil;S.phase="lobby"
      elseif S.phase=="result" then S.reset_home();S.mode_button=nil
      else
        if S.sid and S.phase~="result" and S.transmit then S.transmit("Q") end
        S.reset_home();S.mode_button=nil
      end
      return
    end
    if S.phase=="lobby" then
      if button==B.UP then S.selected=math.max(1,S.selected-1)
      elseif button==B.DOWN then S.selected=math.min(math.max(1,#S.peers),S.selected+1)
      elseif button==B.A and S.peers[S.selected] then
        S.peer=S.peers[S.selected].id;S.sid=string.format("%08X",badge.sys.random())
        S.role,S.phase,S.deadline,S.last_rx,S.next_tx="host","waiting",now+12000,now,0
        S.seq,S.revision,S.last_revision=0,0,-1
      end
    elseif S.phase=="offer" and button==B.A then
      S.peer,S.sid=S.invite.peer,S.invite.sid;S.invite=nil
      S.role,S.phase,S.deadline,S.last_rx,S.next_tx="guest","joining",now+12000,now,0
      S.seq,S.revision,S.last_revision=0,0,-1
    elseif S.phase=="duel" and button==B.A and not S.capture then
      if S.capture_start then S.capture_start(now) else S.message("Teach spells before duel","X") end
    elseif S.phase=="result" and button==B.A then S.reset_home();S.mode_button=nil end
  end
  S.mode_button=S.net_button
end
