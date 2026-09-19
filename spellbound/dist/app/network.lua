-- Nearby-radio duel protocol. Game engine is loaded only when a match actually needs it.
return function(S)
  local new_match,apply,advance,pack_state,unpack_state
  local function ensure_engine()
    if new_match then return end
    local e=require("engine")
    new_match,apply,advance,pack_state,unpack_state=e.new_match,e.apply,e.advance,e.pack,e.unpack
    S.new_match,S.apply,S.advance,S.pack_state,S.unpack_state=new_match,apply,advance,pack_state,unpack_state
    if package and package.loaded then package.loaded["engine"]=nil end
    e=nil;badge.sys.gc_step()
  end
  local function transmit(kind,data)
    if not S.radio_ok or not S.sid then return false end
    local p="SB1|"..kind.."|"..S.sid..(data and ("|"..data) or "")
    if #p>44 then return false end
    return badge.radio.send(p)
  end
  local function split_packet(p)
    if type(p)~="string" or #p>44 then return nil end
    local k,s,d=p:match("^SB1|([IJSKCTPQ])|([0-9A-F]+)|?(.*)$")
    if not k or #s~=8 then return nil end
    if p~="SB1|"..k.."|"..s..(d~="" and ("|"..d) or "") then return nil end
    return k,s,d
  end
  local function send_state(now)
    if not S.match then return end
    ensure_engine();S.revision=S.revision+1
    if S.revision>65535 then S.match.result=4;S.revision=65535 end
    transmit("T",string.format("%04X|",S.revision)..pack_state(S.match,now));S.last_state_tx=now
  end
  local function feedback(code,spell)
    if code==0 then S.message(spell==4 and "You surrendered" or (S.spells[spell].." cast"),spell==4 and nil or S.codes[spell])
    else S.message(S.reject_messages[code] or "Action rejected","X") end
  end
  local function submit(spell)
    if S.phase~="duel" then return end
    local now=S.clock()
    if S.role=="host" then ensure_engine();feedback(apply(S.match,1,spell,0,now),spell);send_state(now)
    elseif S.view then
      if S.pending then S.message("Waiting for cast acknowledgement");return end
      if S.seq>=65534 then S.message("Match limit - start a new duel");return end
      S.seq=S.seq+1;S.pending={seq=S.seq,spell=spell,next=now,started=now}
    end
  end
  local function receive(mac,rssi,payload)
    local from=S.mac_key(mac);if not from or from==S.me then return end
    local now=S.clock()
    if payload=="SB1|H" then
      if S.phase=="lobby" then
        local found=false
        for _,p in ipairs(S.peers) do if p.id==from then p.seen=now;found=true;break end end
        if not found and #S.peers<5 then S.peers[#S.peers+1]={id=from,seen=now} end
      end
      return
    end
    local k,s,d=split_packet(payload);if not k then return end
    if k=="I" then
      if d~=S.me or (S.declined==from..s and now<S.declined_until) then return end
      if S.phase=="lobby" then S.invite={peer=from,sid=s};S.phase="offer";S.deadline=now+12000
      elseif S.phase=="joining" and from==S.peer and s==S.sid then transmit("J") end
      return
    end
    if k=="Q" and d=="" and S.phase=="offer" and S.invite.peer==from and S.invite.sid==s then S.invite=nil;S.phase="lobby";S.message("Invitation cancelled");return end
    if from~=S.peer or s~=S.sid or S.locally_ended then return end
    if k=="Q" and d=="" then
      if S.phase~="home" and S.phase~="result" then S.last_rx=now;S.end_link("Other badge left the match") end
    elseif k=="J" and d=="" and S.role=="host" then
      ensure_engine()
      if S.phase=="waiting" then S.phase="starting";S.match=new_match(now);S.deadline=now+12000 end
      if S.phase=="starting" then S.last_rx=now;transmit("S") elseif S.phase=="duel" or S.phase=="result" then S.last_rx=now;send_state(now) end
    elseif k=="S" and d=="" and S.role=="guest" then
      if S.phase=="joining" or S.phase=="duel" then S.last_rx=now;transmit("K") end
    elseif k=="K" and d=="" and S.role=="host" and S.phase=="starting" then S.last_rx=now;S.phase="duel";S.match.started=now;send_state(now)
    elseif k=="P" and d=="" and S.role=="host" and (S.phase=="duel" or S.phase=="result") then S.last_rx=now
    elseif k=="C" and S.role=="host" and S.match and (S.phase=="duel" or S.phase=="result") then
      ensure_engine();local n,c=d:match("^([0-9A-F]+)|([FSRX])$");if not n or #n~=4 then return end
      local number=tonumber(n,16);if number==0 or number>S.match.ack+1 then return end
      S.last_rx=now
      if number==S.match.ack+1 then local spell=c=="F" and 1 or (c=="S" and 2 or (c=="R" and 3 or 4));apply(S.match,2,spell,number,now) end
      send_state(now)
    elseif k=="T" and S.role=="guest" and (S.phase=="joining" or S.phase=="duel" or S.phase=="result") then
      ensure_engine();local r,data=d:match("^([0-9A-F]+)|([0-9A-F]+)$");if not r or #r~=4 then return end
      local rev=tonumber(r,16);local g=unpack_state(data,now);if not g or rev<=S.last_revision or g.ack>S.seq then return end
      S.last_rx,S.last_revision=now,rev
      if S.view then if g.hp[2]<S.view.hp[2] then S.effect,S.effect_until="D",now+700 elseif S.view.incoming[2]>0 and g.incoming[2]==0 and g.result==0 then S.effect,S.effect_until="B",now+700 end end
      S.view=g;if S.pending and g.ack==S.pending.seq then feedback(g.reply,S.pending.spell);S.pending=nil end
      if S.phase=="joining" then S.phase="duel" end;if g.result~=0 then S.phase,S.capture="result",nil end
    end
  end
  local function network_tick(now)
    if not S.radio_ok then return end
    if S.phase=="lobby" then
      for i=#S.peers,1,-1 do if now-S.peers[i].seen>4000 then table.remove(S.peers,i) end end
      S.selected=S.clamp(S.selected,1,math.max(1,#S.peers));if now>=S.next_tx then badge.radio.send("SB1|H");S.next_tx=now+850 end
    elseif S.phase=="offer" then if now>S.deadline then S.invite=nil;S.phase="lobby" end
    elseif S.phase=="waiting" or S.phase=="starting" or S.phase=="joining" then
      if now>S.deadline then S.end_link("Pairing timed out - try again");return end
      if now>=S.next_tx then transmit(S.phase=="waiting" and "I" or (S.phase=="starting" and "S" or "J"),S.phase=="waiting" and S.peer or nil);S.next_tx=now+600 end
    elseif S.phase=="duel" or S.phase=="result" then
      if S.phase=="duel" and now-S.last_rx>6000 then S.end_link("Link lost - match cancelled");return end
      if S.role=="host" and S.match then
        ensure_engine();local hp,attack=S.match.hp[1],S.match.incoming[1];advance(S.match,now)
        if S.match.hp[1]<hp then S.effect,S.effect_until="D",now+700 elseif attack>0 and S.match.incoming[1]==0 and S.match.result==0 then S.effect,S.effect_until="B",now+700 end
        if S.match.result~=0 then S.phase,S.capture="result",nil end;if now-S.last_state_tx>=200 then send_state(now) end
      elseif S.role=="guest" then
        if now-S.last_ping>=750 then transmit("P");S.last_ping=now end
        if S.pending and now>=S.pending.next then
          transmit("C",string.format("%04X|%s",S.pending.seq,S.pending.spell==4 and "X" or S.codes[S.pending.spell]));S.pending.next=now+350
          if now-S.pending.started>5000 then S.end_link("Cast not acknowledged - cancelled") end
        end
      end
    end
  end
  S.transmit,S.split_packet,S.send_state,S.submit,S.receive,S.network_tick,S.ensure_engine=transmit,split_packet,send_state,submit,receive,network_tick,ensure_engine
end
