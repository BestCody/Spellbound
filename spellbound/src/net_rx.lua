-- Side-effect radio receive state machine.
local S=SPELLBOUND_STATE
function S.receive(mac,rssi,payload)
  local from=S.mac_key(mac);if not from or from==S.me then return end
  local now=S.clock();local phase=S.phase
  if payload=="SB1|H" then
    if phase=="lobby" then
      local signal=type(rssi)=="number" and rssi or -127
      local found=false
      for i=1,#S.peers,3 do
        if S.peers[i]==from then S.peers[i+1],S.peers[i+2]=now,signal;found=true;break end
      end
      if not found and #S.peers<15 then
        S.peers[#S.peers+1]=from;S.peers[#S.peers+1]=now;S.peers[#S.peers+1]=signal
      elseif not found then
        local weak=1
        for i=4,#S.peers,3 do if S.peers[i+2]<S.peers[weak+2] then weak=i end end
        if signal>S.peers[weak+2]+3 then S.peers[weak],S.peers[weak+1],S.peers[weak+2]=from,now,signal end
      end
    end
    return
  end
  local k,s,d=S.split_packet(payload);if not k then return end
  if k=="I" then
    if d~=S.me or (S.declined==from..s and now<(S.deadline or 0)) then return end
    if phase=="lobby" then S.invite={from,s};S.phase="offer";S.deadline=now+12000
    elseif phase=="waiting" and from==S.peer and from<S.me then
      S.sid,S.role,S.phase,S.deadline,S.last_rx,S.next_tx=s,"guest","joining",now+12000,now,0
      S.seq,S.revision=0,-1;S.locally_ended=false;S.peers=nil;S.transmit("J")
    elseif phase=="joining" and from==S.peer and s==S.sid then S.transmit("J") end
    return
  end
  if k=="Q" and d=="" and phase=="offer" and S.invite and S.invite[1]==from and S.invite[2]==s then
    S.invite=nil;S.phase="lobby";S.message("Invitation cancelled");return
  end
  if from~=S.peer or s~=S.sid or S.locally_ended then return end
  if k=="Q" and d=="" then
    if phase~="home" and phase~="result" then S.last_rx=now;S.end_link("Other badge left the match") end
  elseif S.role=="host" then
    local active=phase=="duel" or phase=="result"
    if k=="J" and d=="" then
      if phase=="waiting" then S.phase="starting";phase="starting";S.match=S.new_match(now);S.deadline=now+12000 end
      if phase=="starting" then S.last_rx=now;S.transmit("S")
      elseif active then S.last_rx=now;S.send_state(now) end
    elseif k=="K" and d=="" and phase=="starting" then
      S.last_rx=now;S.phase="duel";S.deadline=0;S.send_state(now)
    elseif k=="P" and d=="" and active then S.last_rx=now
    elseif k=="C" and S.match and active then
      local n,c=d:match("^([0-9A-F]+)|([FSRX])$")
      if not n or #n~=4 then return end
      local number=tonumber(n,16);if number==0 or number>S.match[16]+1 then return end
      S.last_rx=now
      if number==S.match[16]+1 then
        local spell=c=="F" and 1 or (c=="S" and 2 or (c=="R" and 3 or 4))
        S.apply(S.match,2,spell,number,now)
      end
      S.send_state(now)
    end
  elseif S.role=="guest" then
    if k=="S" and d=="" then
      if phase=="joining" or phase=="duel" then S.last_rx=now;S.transmit("K") end
    elseif k=="T" and (phase=="joining" or phase=="duel" or phase=="result") then
      local r,data=d:match("^([0-9A-F]+)|([0-9A-F]+)$")
      if not r or #r~=4 then return end
      local old_hp=S.view and S.view[3]
      local old_in=S.view and S.view[9]
      local rev=tonumber(r,16);local seq=tonumber(data:sub(18,21),16)
      if rev<=(S.revision or -1) or not seq or seq>(S.seq or 0) then return end
      local g=S.unpack_state(data,now,S.view);if not g then return end
      S.last_rx,S.revision=now,rev
      if old_hp then
        if g[3]<old_hp then S.effect,S.effect_until=5,now+700
        elseif old_in>0 and g[9]==0 and g[1]==0 then S.effect,S.effect_until=6,now+700 end
      end
      S.view=g
      if S.pending and g[16]==S.pending[1] then S.feedback(g[17],S.pending[2]);S.pending=nil end
      if phase=="joining" then S.phase="duel";S.deadline=0 end
      if g[1]~=0 then S.phase,S.capture="result",nil end
    end
  end
end
