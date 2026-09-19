-- Radio coordinator; heavy state handlers compile only on Find a duel.
return function(S)
  local new_match,apply,advance,pack_state,unpack_state
  function S.ensure_engine()
    if new_match then return end
    local e=require("engine")
    new_match,apply,advance,pack_state,unpack_state=e.new_match,e.apply,e.advance,e.pack,e.unpack
    S.new_match,S.apply,S.advance,S.pack_state,S.unpack_state=new_match,apply,advance,pack_state,unpack_state
    e=nil;badge.sys.gc_step()
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
    S.ensure_engine();S.revision=S.revision+1
    if S.revision>65535 then S.match.result=4;S.revision=65535 end
    S.transmit("T",string.format("%04X|",S.revision)..pack_state(S.match,now));S.last_state_tx=now
  end
  function S.feedback(code,spell)
    if code==0 then S.message(spell==4 and "You surrendered" or (S.spells[spell].." cast"),spell==4 and nil or S.codes[spell])
    else S.message(S.reject_messages[code] or "Action rejected","X") end
  end
  function S.submit(spell)
    if S.phase~="duel" then return end
    local now=S.clock()
    if S.role=="host" then
      S.ensure_engine();S.feedback(apply(S.match,1,spell,0,now),spell);S.send_state(now)
    elseif S.view then
      if S.pending then S.message("Waiting for cast acknowledgement");return end
      if S.seq>=65534 then S.message("Match limit - start a new duel");return end
      S.seq=S.seq+1;S.pending={seq=S.seq,spell=spell,next=now,started=now}
    end
  end
  local r=require("net_rx");r(S);r=nil;badge.sys.gc_step()
  local t=require("net_tick");t(S);t=nil;badge.sys.gc_step()
  local b=require("net_buttons");b(S);b=nil;badge.sys.gc_step()
  local e=require("effects");e(S);e=nil;badge.sys.gc_step()
end
