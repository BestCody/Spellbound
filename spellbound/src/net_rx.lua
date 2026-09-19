-- Side-effect fixed-layout radio receive state machine.
local S=SPELLBOUND_STATE
local function rem(t,now) return math.min(93,math.ceil(math.max(0,t-now)/40)) end
function S.codec(op,a,b,c)
  if op==0 then
    return string.char(33+a[1],33+a[2]/25,33+a[3]/25,33+a[4]/5,33+a[5]/5,
      33+rem(a[6],b),33+rem(a[7],b),33+rem(a[8],b),33+rem(a[9],b))..
      string.format("%04X",S.seq)..string.char(33+a[16])
  end
  if #a~=14 then return nil end
  c=c or {}
  c[1],c[2],c[3],c[4],c[5],c[6],c[7],c[8],c[9]=a:byte(1,9)
  for i=1,9 do c[i]=c[i]-33;if c[i]<0 then return nil end end
  c[10],c[11]=tonumber(a:sub(10,13),16),(a:byte(14) or 0)-33
  if not c[10] or c[1]>4 or c[11]<0 or c[11]>1 or
    math.max(c[2],c[3])>4 or math.max(c[4],c[5])>20 then return nil end
  c[2],c[3],c[4],c[5]=c[2]*25,c[3]*25,c[4]*5,c[5]*5
  c[6],c[7]=b+c[6]*40,b+c[7]*40
  c[8],c[9]=c[8]>0 and b+c[8]*40 or 0,c[9]>0 and b+c[9]*40 or 0
  return c
end
function S.receive(mac,rssi,p)
  local from=S.mac_key(mac);if not from or from==S.me then return end
  local now=S.clock();local phase=S.phase
  if p=="SB2H" then
    if phase=="lobby" then
      local signal=rssi
      for i=1,#S.peers,3 do
        if S.peers[i]==from then S.peers[i+1],S.peers[i+2]=now,signal;return end
      end
      if #S.peers<15 then
        S.peers[#S.peers+1]=from;S.peers[#S.peers+1]=now;S.peers[#S.peers+1]=signal
      else
        local weak=1
        for i=4,#S.peers,3 do if S.peers[i+2]<S.peers[weak+2] then weak=i end end
        if signal>S.peers[weak+2]+3 then S.peers[weak],S.peers[weak+1],S.peers[weak+2]=from,now,signal end
      end
    end
    return
  end
  if #p<12 or p:sub(1,3)~="SB2" then return end
  local k,s=p:sub(4,4),p:sub(5,12)
  if not tonumber(s,16) then return end
  if k=="I" and #p==24 then
    if p:sub(13)~=S.me or (S.declined==from..s and now<(S.deadline or 0)) then return end
    if phase=="lobby" then S.invite={from,s};S.phase="offer";S.deadline=now+12000
    elseif phase=="waiting" and from==S.peer and from<S.me then
      S.sid,S.role,S.phase,S.deadline,S.last_rx,S.next_tx=s,"guest","joining",now+12000,now,0
      S.seq,S.revision,S.last_state_tx=0,-1,0;S.locally_ended=false;S.peers=nil;S.transmit("J")
    elseif phase=="joining" and from==S.peer and s==S.sid then S.transmit("J") end
    return
  end
  if k=="Q" and #p==12 and phase=="offer" and S.invite and S.invite[1]==from and S.invite[2]==s then
    S.invite=nil;S.phase="lobby";S.message("Invite cancelled");return
  end
  if from~=S.peer or s~=S.sid or S.locally_ended then return end
  if k=="Q" and #p==12 then
    if phase~="home" and phase~="result" then S.last_rx=now;S.end_link() end
  elseif S.role=="host" then
    local active=phase=="duel" or phase=="result"
    if k=="J" and #p==12 then
      S.last_rx=now
      if phase=="waiting" then
        S.phase="duel";phase="duel";S.match={0,100,100,75,75,0,0,0,0,0,0,0,0,0,0,0};S.deadline=0
      end
      if phase=="duel" then S.send_state(now) end
    elseif k=="P" and #p==12 and active then S.last_rx=now
    elseif k=="C" and #p==17 and S.match and active then
      local number=tonumber(p:sub(13,16),16);local c=p:sub(17)
      if not number or number==0 or number>S.seq+1 or not c:find("^[FSRX]$") then return end
      S.last_rx=now
      if number==S.seq+1 then
        local spell=c=="F" and 1 or (c=="S" and 2 or (c=="R" and 3 or 4))
        S.apply(S.match,2,spell,number,now)
      end
      S.send_state(now)
    end
  elseif S.role=="guest" and k=="T" and #p==30 and (phase=="joining" or phase=="duel" or phase=="result") then
    local rev=tonumber(p:sub(13,16),16);if not rev then return end
    local data=p:sub(17);local seq=tonumber(data:sub(10,13),16)
    if rev<=(S.revision or -1) or not seq or seq>(S.seq or 0) then return end
    local old_hp=S.view and S.view[3];local old_in=S.view and S.view[9]
    local g=S.codec(1,data,now,S.view);if not g then return end
    S.last_rx,S.revision=now,rev
    if old_hp then
      if g[3]<old_hp then S.effect,S.effect_until=5,now+700
      elseif old_in>0 and g[9]==0 and g[1]==0 then S.effect,S.effect_until=6,now+700 end
    end
    S.view=g
    if S.pending and g[10]==S.pending[1] then S.feedback(g[11],S.pending[2]);S.pending=nil end
    if phase=="joining" then S.phase="duel";S.deadline=0 end
    if g[1]~=0 then
      S.phase,S.capture="result",nil
      if g[1]==2 then S.effect,S.effect_until=7,now+60000 end
    end
  end
end
