-- Side-effect teaching/classification. Gesture models allocate only when Teach is first opened.
local S=SPELLBOUND_STATE
S.models=S.models or {}
function S.handle_signature(sig)
  if S.phase=="teach" and S.training then
    local spell=S.training[1]
    if not S.training[2] then
      S.training[2]=sig;S.message("Now test with a NEW repetition",3);return
    end
    local old=S.models[spell];S.models[spell]=S.training[2]
    local id,why=S.recognize(sig,S.models)
    if id~=spell then
      S.models[spell]=old
      if id then S.message("Looks like "..S.spells[id].." - make it distinct",4)
      else S.message(why or "Test failed - repeat",4) end
      return
    end
    S.message(S.spells[id].." learned for this session",3,4000)
    S.training=nil;S.phase="train_select";return
  end
  local id,why=S.recognize(sig,S.models)
  if id and S.submit then S.submit(id) else S.message(why or "Duel unavailable",4) end
end
function S.teach_render(now,shown)
  local out=""
  if S.phase=="train_select" then
    for n=1,3 do
      out=out..(n==S.selected and "> " or "  ")..S.spells[n]..
        (S.models[n] and " [learned]" or " [untrained]").."\n"
    end
    return out.."\n"..(shown~="" and shown or "1 example + fresh test").."\nA open / B back"
  end
  local tr=S.training
  return S.spells[tr[1]].."\n"..
    (not tr[2] and "Training example" or "Fresh test repetition")..
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
    elseif button==B.A then S.training={S.selected};S.phase="teach" end
  elseif S.phase=="teach" and button==B.A and not S.capture then S.capture_start(now) end
end
