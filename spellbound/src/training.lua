-- Side-effect teaching/classification. Gesture models allocate only when Teach is first opened.
local S=SPELLBOUND_STATE
S.models=S.models or {{},{},{}}
S.thresholds=S.thresholds or {}
function S.handle_signature(sig)
  if S.phase=="teach" and S.training then
    local spell=S.training[1];local samples=S.training[2]
    if #samples<3 then
      local nearest=99
      for i=1,#samples do nearest=math.min(nearest,S.distance(sig,samples[i])) end
      if #samples==1 and nearest>S.train_max then
        samples[1]=sig
        S.message("New baseline saved - repeat it","R");return
      elseif #samples>1 and nearest>S.train_max then
        S.message("Movement changed too much - repeat","X");return
      end
      samples[#samples+1]=sig
      if #samples==3 then
        S.training[3]=S.calibrate(samples)
        S.message("Now test with a NEW repetition","R")
      else S.message("Example saved in RAM","R") end
      return
    end
    local oldm,oldt=S.models[spell],S.thresholds[spell]
    local th=S.training[3] or S.calibrate(samples)
    S.models[spell],S.thresholds[spell]=samples,th
    local id,why=S.recognize(sig,S.models,S.thresholds)
    if id~=spell then
      S.models[spell],S.thresholds[spell]=oldm,oldt
      if id then S.message("Looks like "..S.spells[id].." - make it distinct","X")
      else S.message(why or "Test failed - repeat","X") end
      return
    end
    S.message(S.spells[id].." learned for this session","R",4000)
    S.training=nil;S.phase="train_select";return
  end
  local id,why=S.recognize(sig,S.models,S.thresholds)
  if id and S.submit then S.submit(id) else S.message(why or "Duel unavailable","X") end
end
function S.teach_render(now,shown)
  local out=""
  if S.phase=="train_select" then
    for n=1,3 do
      out=out..(n==S.selected and "> " or "  ")..S.spells[n]..
        (#S.models[n]>0 and " [learned]" or " [untrained]").."\n"
    end
    return out.."\n"..(shown~="" and shown or "3 examples + fresh test").."\nA open / B back"
  end
  local tr=S.training;local samples=tr and tr[2] or {}
  return S.spells[tr[1]].."\n"..
    (#samples<3 and ("Example "..(#samples+1).." of 3") or "Fresh test repetition")..
    "\n\nHold A, move, release.\n"..(shown~="" and shown or "Idle before/after is trimmed").."\nB cancels"
end
function S.teach_button(button,kind,now)
  local B,K=badge.input.BUTTON,badge.input.KIND
  if kind~=K.PRESSED then return end
  if button==B.B then
    S.capture=nil
    if S.phase=="teach" then S.training=nil;S.phase="train_select"
    else S.reset_home() end
  elseif S.phase=="train_select" then
    if button==B.UP then S.selected=(S.selected+1)%3+1
    elseif button==B.DOWN then S.selected=S.selected%3+1
    elseif button==B.A then S.training={S.selected,{}};S.phase="teach" end
  elseif S.phase=="teach" and button==B.A and not S.capture then S.capture_start(now) end
end
