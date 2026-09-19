-- Motion capture coordinator. Signature/classifier modules are preloaded by app.lua.
return function(S,G)
  local raw_sample,signature=G.raw_sample,G.signature
  local function read_accel()
    local x,y,z=badge.sensor.accel()
    if type(x)=="number" and type(y)=="number" and type(z)=="number" and x==x and y==y and z==z
      and math.max(math.abs(x),math.abs(y),math.abs(z))<=32000 then return x,y,z end
  end
  local function sample(now)
    if not S.capture or now-S.capture.last<20 then return end
    local x,y,z=read_accel();if not x then S.capture.bad=true;return end
    local e=now-S.capture.start
    if e<=S.MAX_CAPTURE then S.capture.raw=S.capture.raw..raw_sample(e,x,y,z) end
    S.capture.last=now
  end
  function S.capture_start(now)
    local x,y,z=read_accel()
    if not x then S.message("Motion sensor unavailable / invalid","X");return end
    S.capture={start=now,last=now,raw=raw_sample(0,x,y,z),bad=false};S.effect=""
  end
  function S.capture_finish(now,too_long)
    if not S.capture then return end
    sample(now);local raw,bad=S.capture.raw,S.capture.bad;S.capture=nil
    if bad or too_long then
      S.message(too_long and "A hold too long - try again" or "Sensor sample invalid","X");return
    end
    local sig,err,meta=signature(raw);raw=nil
    if not sig then S.message(err or "No clear movement","X");return end
    S.handle_signature(sig,meta)
  end
  function S.capture_tick(now)
    if not S.capture then return end
    if now-S.capture.start>S.MAX_CAPTURE then S.capture_finish(now,true)
    else sample(now);if not badge.input.is_down(badge.input.BUTTON.A) then S.capture_finish(now,false) end end
  end
end
