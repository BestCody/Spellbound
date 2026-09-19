-- Side-effect multiplayer renderer and button dispatcher.
local S=SPELLBOUND_STATE
function S.net_action(button,kind,now)
  if not now then
    local shown=kind;now=button
    local out="";local phase=S.phase
    if phase=="lobby" then
      if #S.peers==0 then out="Searching..."
      else for i=1,#S.peers,3 do
        local n=(i+2)/3;out=out..string.format("%sBadge %s\n",n==S.selected and "> " or "  ",S.peers[i]:sub(-6))
      end end
      return out.."\nA invite / B back"
    elseif phase=="offer" then return "Challenge "..S.invite[1]:sub(-6).."\n\nA accept / B decline"
    elseif phase=="waiting" then return "Waiting...\n\nB cancels"
    elseif phase=="joining" then return "Syncing...\n\nB cancels" end
    local own=S.role=="host" and 1 or 2;local g=own==1 and S.match or S.view
    if g then
      local hi=1+own;local mi=3+own
      out=string.format("YOU HP %d  MANA %d\nFOE HP %d  MANA %d\n\n",g[hi],g[mi],g[5-hi],g[9-mi])
    end
    local title="READY TO CAST"
    if phase=="result" then
      title=(not g or g[1]==4) and "MATCH CANCELLED" or (g[1]==3 and "DRAW" or (g[1]==own and "YOU WIN" or "DEFEAT"))
      return out..title.."\n"..(shown~="" and shown or "A/B: menu")
    end
    if g then
      local si=5+own;local ii=7+own
      if g[ii]>now then title=g[si]>=g[ii] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
      elseif now<S.effect_until and S.effect==6 then title="BLOCKED"
      elseif S.capture then title="CHANNELING..."
      elseif S.pending then title="CAST QUEUED - WAIT"
      elseif g[si]>now then title="SHIELD ACTIVE" end
    end
    return out..title.."\n"..(shown~="" and shown or "Hold A, move, release").."\nB twice: surrender"
  end
  local B=badge.input.BUTTON
  local phase=S.phase
  if button==B.B then
    S.capture=nil
    if phase=="duel" then
      if now<(S.deadline or 0) then S.submit(4);S.deadline=0 else S.deadline=now+1800;S.message("B again: surrender",nil,1800) end
    elseif phase=="offer" then
      S.declined,S.deadline=S.invite[1]..S.invite[2],now+14000
      badge.radio.send("SB2Q"..S.invite[2]);S.invite=nil;S.phase="lobby"
    elseif phase=="result" then S.reset_home()
    else if S.sid then S.transmit("Q") end;S.reset_home() end
    return
  end
  local role,next_phase,revision
  if phase=="lobby" then
    if button==B.UP then S.selected=math.max(1,S.selected-1)
    elseif button==B.DOWN then S.selected=math.min(math.max(1,#S.peers/3),S.selected+1)
    elseif button==B.A and S.peers[(S.selected-1)*3+1] then
      S.peer=S.peers[(S.selected-1)*3+1];S.peers=nil;S.sid=string.format("%08X",badge.sys.random())
      role,next_phase,revision="host","waiting",0
    end
  elseif phase=="offer" and button==B.A then
    S.peer,S.sid=S.invite[1],S.invite[2];S.invite,S.peers=nil,nil
    role,next_phase,revision="guest","joining",-1
  elseif phase=="duel" and button==B.A and not S.capture then
    if S.capture_event then S.capture_event(now,0) else S.message("Teach before duel",4) end
  elseif phase=="result" and button==B.A then S.reset_home() end
  if role then
    S.role,S.phase,S.deadline,S.last_rx,S.next_tx=role,next_phase,now+12000,now,0
    S.seq,S.revision,S.last_state_tx=0,revision,0;S.locally_ended=false;if S.ensure_engine then S.ensure_engine() end
  end
end

function S.leds(now)
  local mode=now<S.effect_until and S.effect or 0
  badge.led.clear();local step=math.floor(now/150)%6+1
  if mode==1 then badge.led.set(step,160,50,0)
  elseif mode==2 or mode==6 then badge.led.set_all(0,70,160)
  elseif mode==3 then badge.led.set_all(0,160,100)
  elseif mode==5 then badge.led.set_all(160,0,0)
  elseif mode==7 then badge.led.set(step,160,120,20) end
  badge.led.show()
end
