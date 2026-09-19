-- Side-effect radio receive state machine.
local S=SPELLBOUND_STATE
function S.receive(mac,rssi,payload)
  local from=S.mac_key(mac);if not from or from==S.me then return end
  local now=S.clock()
  if payload=="SB1|H" then
    if S.phase=="lobby" then
      local found=false
      for i=1,#S.peers do
        local p=S.peers[i];if p[1]==from then p[2]=now;found=true;break end
      end
      if not found and #S.peers<5 then S.peers[#S.peers+1]={from,now} end
    end
    return
  end
  local k,s,d=S.split_packet(payload);if not k then return end
  if k=="I" then
    if d~=S.me or (S.declined==from..s and now<(S.declined_until or 0)) then return end
    if S.phase=="lobby" then S.invite={from,s};S.phase="offer";S.deadline=now+12000
    elseif S.phase=="joining" and from==S.peer and s==S.sid then S.transmit("J") end
    return
  end
  if k=="Q" and d=="" and S.phase=="offer" and S.invite and S.invite[1]==from and S.invite[2]==s then
    S.invite=nil;S.phase="lobby";S.message("Invitation cancelled");return
  end
  if from~=S.peer or s~=S.sid or S.locally_ended then return end
  if k=="Q" and d=="" then
    if S.phase~="home" and S.phase~="result" then S.last_rx=now;S.end_link("Other badge left the match") end
  elseif k=="J" and d=="" and S.role=="host" then
    if S.phase=="waiting" then S.phase="starting";S.match=S.new_match(now);S.deadline=now+12000 end
    if S.phase=="starting" then S.last_rx=now;S.transmit("S")
    elseif S.phase=="duel" or S.phase=="result" then S.last_rx=now;S.send_state(now) end
  elseif k=="S" and d=="" and S.role=="guest" then
    if S.phase=="joining" or S.phase=="duel" then S.last_rx=now;S.transmit("K") end
  elseif k=="K" and d=="" and S.role=="host" and S.phase=="starting" then
    S.last_rx=now;S.phase="duel";S.match[18]=now;S.send_state(now)
  elseif k=="P" and d=="" and S.role=="host" and (S.phase=="duel" or S.phase=="result") then
    S.last_rx=now
  elseif k=="C" and S.role=="host" and S.match and (S.phase=="duel" or S.phase=="result") then
    local n,c=d:match("^([0-9A-F]+)|([FSRX])$")
    if not n or #n~=4 then return end
    local number=tonumber(n,16);if number==0 or number>S.match[16]+1 then return end
    S.last_rx=now
    if number==S.match[16]+1 then
      local spell=c=="F" and 1 or (c=="S" and 2 or (c=="R" and 3 or 4))
      S.apply(S.match,2,spell,number,now)
    end
    S.send_state(now)
  elseif k=="T" and S.role=="guest" and (S.phase=="joining" or S.phase=="duel" or S.phase=="result") then
    local r,data=d:match("^([0-9A-F]+)|([0-9A-F]+)$")
    if not r or #r~=4 then return end
    local rev=tonumber(r,16);local g=S.unpack_state(data,now)
    if not g or rev<=(S.last_revision or -1) or g[16]>(S.seq or 0) then return end
    S.last_rx,S.last_revision=now,rev
    if S.view then
      if g[3]<S.view[3] then S.effect,S.effect_until="D",now+700
      elseif S.view[9]>0 and g[9]==0 and g[1]==0 then S.effect,S.effect_until="B",now+700 end
    end
    S.view=g
    if S.pending and g[16]==S.pending[1] then S.feedback(g[17],S.pending[2]);S.pending=nil end
    if S.phase=="joining" then S.phase="duel" end
    if g[1]~=0 then S.phase,S.capture="result",nil end
  end
end
