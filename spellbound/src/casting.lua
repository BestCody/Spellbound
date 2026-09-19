-- Motion capture/training with adaptive segmented-DTW gesture recognition.
return function(S)
  local raw_sample,signature,distance,recognize,calibrate,class_score,train_max

  local function ensure_gesture()
    if raw_sample then return end
    local g=require("gesture")
    raw_sample,signature,distance,recognize=g.raw_sample,g.signature,g.distance,g.recognize
    calibrate,class_score,train_max=g.calibrate,g.class_score,g.train_max
    S.raw_sample,S.signature,S.distance,S.recognize=raw_sample,signature,distance,recognize
    S.calibrate,S.class_score=calibrate,class_score
    if package and package.loaded then package.loaded["gesture"]=nil end
    g=nil;badge.sys.gc_step()
  end

  local function read_accel()
    local x,y,z=badge.sensor.accel()
    if type(x)=="number" and type(y)=="number" and type(z)=="number"
      and x==x and y==y and z==z
      and math.max(math.abs(x),math.abs(y),math.abs(z))<=32000 then
      return x,y,z
    end
  end

  local function log_meta(meta)
    if not meta then return end
    badge.sys.log(string.format(
      "GESTURE hold=%d active=%d samples=%d start=%d end=%d peak=%d rms=%d",
      meta.hold_ms or -1,meta.active_ms or -1,meta.samples or -1,
      meta.start_ms or -1,meta.end_ms or -1,meta.peak_delta or -1,meta.rms_delta or -1))
  end
  local function log_diag(diag,result)
    if not diag then return end
    local scores=diag.scores or {99,99,99}
    local best=diag.best and S.codes[diag.best] or "-"
    badge.sys.log(string.format(
      "GESTURE scores F=%.3f S=%.3f R=%.3f best=%s thr=%.3f ratio=%.3f %s",
      scores[1] or 99,scores[2] or 99,scores[3] or 99,best,
      diag.threshold or -1,diag.ratio or -1,result or ""))
  end

  local function capture_start(now)
    ensure_gesture()
    local x,y,z=read_accel()
    if not x then S.message("Motion sensor unavailable / invalid","X");return end
    S.capture={start=now,last=now,raw=raw_sample(0,x,y,z),bad=false};S.effect=""
  end
  local function capture_sample(now)
    if not S.capture or now-S.capture.last<20 then return end
    local x,y,z=read_accel()
    if not x then S.capture.bad=true;return end
    local elapsed=now-S.capture.start
    if elapsed<=S.MAX_CAPTURE then S.capture.raw=S.capture.raw..raw_sample(elapsed,x,y,z) end
    S.capture.last=now
  end

  local function capture_finish(now,too_long)
    if not S.capture then return end
    capture_sample(now)
    local raw,bad=S.capture.raw,S.capture.bad;S.capture=nil
    if bad or too_long then
      S.message(too_long and "A hold too long - try again" or "Sensor sample invalid","X")
      return
    end

    local sig,err,meta=signature(raw)
    log_meta(meta)
    if not sig then S.message(err or "No clear movement","X");return end

    if S.phase=="teach" and S.training then
      local spell=S.training.spell
      local samples=S.training.samples
      if #samples<3 then
        local nearest=99
        for _,other in ipairs(samples) do nearest=math.min(nearest,distance(sig,other)) end

        if #samples==1 and nearest>train_max then
          -- A bad first example should not poison the whole teaching session.
          samples[1]=sig
          badge.sys.log(string.format("GESTURE train %s reset-baseline d=%.3f",S.codes[spell],nearest))
          S.message("New baseline saved - repeat it","R")
          return
        elseif #samples>1 and nearest>train_max then
          badge.sys.log(string.format("GESTURE train %s reject sample=%d nearest=%.3f",
            S.codes[spell],#samples+1,nearest))
          S.message("Movement changed too much - repeat","X")
          return
        end

        samples[#samples+1]=sig
        if #samples>1 then
          badge.sys.log(string.format("GESTURE train %s sample=%d nearest=%.3f",
            S.codes[spell],#samples,nearest))
        end
        if #samples==3 then
          local threshold,spread,mean=calibrate(samples)
          S.training.threshold=threshold
          badge.sys.log(string.format(
            "GESTURE calibrate %s spread=%.3f mean=%.3f thr=%.3f",
            S.codes[spell],spread,mean,threshold))
          S.message("Now test with a NEW repetition","R")
        else
          S.message("Example saved in RAM","R")
        end
        return
      end

      local proposed={S.models[1],S.models[2],S.models[3]}
      proposed[spell]=samples
      local thresholds={S.thresholds[1],S.thresholds[2],S.thresholds[3]}
      thresholds[spell]=S.training.threshold or calibrate(samples)
      local id,why,score,diag=recognize(sig,proposed,thresholds)
      log_diag(diag,id==spell and "ACCEPT-VALIDATION" or "REJECT-VALIDATION")
      if id~=spell then
        if id then S.message("Looks like "..S.spells[id].." - make it distinct","X")
        else S.message(why or "Test failed - repeat","X") end
        return
      end

      S.models=proposed;S.thresholds=thresholds
      S.message(S.spells[id].." learned for this session","R",4000)
      S.training=nil;S.phase="train_select"
      return
    end

    local id,why,score,diag=recognize(sig,S.models,S.thresholds)
    log_diag(diag,id and "ACCEPT-CAST" or "REJECT-CAST")
    if id and S.submit then S.submit(id)
    else S.message(why or "Duel unavailable","X") end
  end

  function S.capture_tick(now)
    if not S.capture then return end
    if now-S.capture.start>S.MAX_CAPTURE then capture_finish(now,true)
    else
      capture_sample(now)
      if not badge.input.is_down(badge.input.BUTTON.A) then capture_finish(now,false) end
    end
  end

  S.capture_start,S.capture_finish,S.ensure_gesture=capture_start,capture_finish,ensure_gesture
end
