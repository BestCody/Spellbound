-- Side-effect teaching/classification. Gesture models allocate only when Teach is first opened.
local S=SPELLBOUND_STATE
S.models=S.models or {}
function S.handle_signature(sig)
  if S.phase=="teach" and S.training then
    local spell=S.training[1]
    if not S.training[2] then
      S.training[2]=sig;S.message("Now: fresh test",3);return
    end
    if S.distance(sig,S.training[2])>0.48 then S.message("Test again",4);return end
    S.models[spell]=S.training[2]
    S.message(S.spells[spell].." learned",3,4000)
    S.training=nil;S.phase="train_select";return
  end
  local id,why=S.recognize(sig,S.models)
  if id and S.submit then S.submit(id) else S.message(why or "Duel unavailable",4) end
end
function S.teach_action(button,kind,now)
  if not now then
    local shown=kind;local out=""
    if S.phase=="train_select" then
      for n=1,3 do out=out..string.format("%s%s %s\n",n==S.selected and "> " or "  ",S.spells[n],S.models[n] and "[ok]" or "[ ]") end
      return out.."\n"..(shown~="" and shown or "1 example + test").."\nA open / B back"
    end
    local tr=S.training
    return S.spells[tr[1]].."\n"..(not tr[2] and "Example" or "Fresh test")..
      "\n\nHold A, move, release\n"..(shown~="" and shown or "Ready").."\nB cancels"
  end
  local B=badge.input.BUTTON
  if button==B.B then
    S.capture=nil
    if S.phase=="teach" then S.training=nil;S.phase="train_select"
    else S.reset_home() end
  elseif S.phase=="train_select" then
    if button==B.UP then S.selected=(S.selected+1)%3+1
    elseif button==B.DOWN then S.selected=S.selected%3+1
    elseif button==B.A then S.training={S.selected};S.phase="teach" end
  elseif S.phase=="teach" and button==B.A and not S.capture then S.capture_event(now,0) end
end
