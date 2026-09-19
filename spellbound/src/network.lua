-- Side-effect radio coordinator and multiplayer buttons. Network state allocates only on first duel.
local S=SPELLBOUND_STATE
S.peers=S.peers or {}
S.radio_started=S.radio_started or false
function S.end_link(reason)
  S.locally_ended=true
  if S.match then S.match[1]=4 end
  if S.view then S.view[1]=4 end
  S.phase,S.pending,S.capture="result",nil,nil
  S.effect,S.effect_until="",0
  S.message(reason,nil,60000)
end
function S.transmit(kind,data)
  if not S.radio_ok or not S.sid then return false end
  local p="SB1|"..kind.."|"..S.sid..(data and ("|"..data) or "")
  if #p>44 then return false end
  return badge.radio.send(p)
end
function S.split_packet(p)
  if type(p)~="string" or #p>44 then return nil end
  local k,s,d=p:match("^SB1|([IJSKCTPQ])|([0-9A-F]+)|?(.*)$")
  if not k or #s~=8 then return nil end
  if p~="SB1|"..k.."|"..s..(d~="" and ("|"..d) or "") then return nil end
  return k,s,d
end
function S.send_state(now)
  if not S.match then return end
  S.revision=(S.revision or 0)+1
  if S.revision>65535 then S.match[1]=4;S.revision=65535 end
  S.transmit("T",string.format("%04X|",S.revision)..S.pack_state(S.match,now))
  S.last_state_tx=now
end
function S.feedback(code,spell)
  if code==0 then
    S.message(spell==4 and "You surrendered" or (S.spells[spell].." cast"),spell==4 and nil or S.codes[spell])
  else
    local m=code==1 and "Not enough mana" or
      (code==2 and "Spell cooling down" or
      (code==3 and "Attack already in flight" or
      (code==4 and "Match finished" or "Out-of-order action")))
    S.message(m,"X")
  end
end
function S.submit(spell)
  if S.phase~="duel" then return end
  local now=S.clock()
  if S.role=="host" then
    S.feedback(S.apply(S.match,1,spell,0,now),spell);S.send_state(now)
  elseif S.view then
    if S.pending then S.message("Waiting for cast acknowledgement");return end
    if S.seq>=65534 then S.message("Match limit - start a new duel");return end
    S.seq=S.seq+1;S.pending={S.seq,spell,now,now}
  end
end
function S.net_button(button,kind,now)
  local B,K=badge.input.BUTTON,badge.input.KIND
  if kind~=K.PRESSED then return end
  if button==B.B then
    S.capture=nil
    if S.phase=="duel" then
      if now<(S.leave_until or 0) then S.submit(4);S.leave_until=0
      else S.leave_until=now+1800;S.message("Press B again to surrender",nil,1800) end
    elseif S.phase=="offer" then
      S.declined,S.declined_until=S.invite[1]..S.invite[2],now+14000
      badge.radio.send("SB1|Q|"..S.invite[2]);S.invite=nil;S.phase="lobby"
    elseif S.phase=="result" then S.reset_home()
    else
      if S.sid and S.phase~="result" then S.transmit("Q") end
      S.reset_home()
    end
    return
  end
  if S.phase=="lobby" then
    if button==B.UP then S.selected=math.max(1,S.selected-1)
    elseif button==B.DOWN then S.selected=math.min(math.max(1,#S.peers),S.selected+1)
    elseif button==B.A and S.peers[S.selected] then
      S.peer=S.peers[S.selected][1];S.sid=string.format("%08X",badge.sys.random())
      S.role,S.phase,S.deadline,S.last_rx,S.next_tx="host","waiting",now+12000,now,0
      S.seq,S.revision,S.last_revision=0,0,-1;S.locally_ended=false
    end
  elseif S.phase=="offer" and button==B.A then
    S.peer,S.sid=S.invite[1],S.invite[2];S.invite=nil
    S.role,S.phase,S.deadline,S.last_rx,S.next_tx="guest","joining",now+12000,now,0
    S.seq,S.revision,S.last_revision=0,0,-1;S.locally_ended=false
  elseif S.phase=="duel" and button==B.A and not S.capture then
    if S.capture_start then S.capture_start(now) else S.message("Teach spells before duel","X") end
  elseif S.phase=="result" and button==B.A then S.reset_home() end
end
