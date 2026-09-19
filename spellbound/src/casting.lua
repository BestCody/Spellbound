-- Motion capture/training. Gesture recognizer is loaded only when capture begins.
return function(S)
  local raw_sample,signature,distance,recognize
  local function ensure_gesture()
    if raw_sample then return end
    local g=require("gesture")
    raw_sample,signature,distance,recognize=g.raw_sample,g.signature,g.distance,g.recognize
    S.raw_sample,S.signature,S.distance,S.recognize=raw_sample,signature,distance,recognize
    if package and package.loaded then package.loaded["gesture"]=nil end
    g=nil;badge.sys.gc_step()
  end
  local function read_accel()
    local x,y,z=badge.sensor.accel()
    if type(x)=="number" and type(y)=="number" and type(z)=="number" and x==x and y==y and z==z and math.max(math.abs(x),math.abs(y),math.abs(z))<=4000 then return x,y,z end
  end
  local function capture_start(now)
    ensure_gesture()
    local x,y,z=read_accel()
    if not x then S.message("Motion sensor unavailable / invalid","X");return end
    S.capture={start=now,last=now,raw=raw_sample(0,x,y,z),bad=false};S.effect=""
  end
  local function capture_sample(now)
    if not S.capture or now-S.capture.last<20 then return end
    local x,y,z=read_accel();if not x then S.capture.bad=true;return end
    local elapsed=now-S.capture.start
    if elapsed<=S.MAX_CAPTURE then S.capture.raw=S.capture.raw..raw_sample(elapsed,x,y,z) end
    S.capture.last=now
  end
  local function capture_finish(now,too_long)
    if not S.capture then return end
    capture_sample(now)
    local raw,bad=S.capture.raw,S.capture.bad;S.capture=nil
    if bad or too_long then S.message(too_long and "Gesture too long - try again" or "Sensor error / movement too strong","X");return end
    local sig,err=signature(raw);if not sig then S.message(err,"X");return end
    if S.phase=="teach" and S.training then
      local samples=S.training.samples
      if #samples<3 then
        for _,other in ipairs(samples) do if distance(sig,other)>0.48 then S.message("Repeat the SAME movement");return end end
        for spell=1,3 do if spell~=S.training.spell then for _,other in ipairs(S.models[spell]) do if distance(sig,other)<0.28 then S.message("Too similar to "..S.spells[spell]);return end end end end
        samples[#samples+1]=sig;S.message(#samples==3 and "Now test with a NEW repetition" or "Example saved in RAM","R")
      else
        local proposed={S.models[1],S.models[2],S.models[3]};proposed[S.training.spell]=samples
        local id=recognize(sig,proposed);if id~=S.training.spell then S.message("Test failed - repeat or B to retry");return end
        S.models=proposed;S.message(S.spells[id].." learned for this session","R",4000);S.training=nil;S.phase="train_select"
      end
    else
      local id,why=recognize(sig,S.models)
      if id and S.submit then S.submit(id) else S.message(why or "Duel unavailable","X") end
    end
  end
  function S.capture_tick(now)
    if not S.capture then return end
    if now-S.capture.start>S.MAX_CAPTURE then capture_finish(now,true)
    else capture_sample(now);if not badge.input.is_down(badge.input.BUTTON.A) then capture_finish(now,false) end end
  end
  S.capture_start,S.capture_finish,S.ensure_gesture=capture_start,capture_finish,ensure_gesture
end
