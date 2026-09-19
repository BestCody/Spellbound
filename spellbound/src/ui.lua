-- Three-widget rebuildable UI: background, text, capture progress.
return function(S,root)
  local W={}
  local function build(parent)
    W={};S.widgets=W;S.last_screen=nil
    local bg=badge.ui.box(parent,320,240);bg:set_pos(0,0)
    bg:style({bg_color=0x100C20,border_width=0,pad_all=0,radius=0});W.bg=bg
    local l=badge.ui.label(bg,"");l:set_pos(12,8);l:set_size(296,207)
    l:style({text_font=14,text_color=0xE8E4F5,pad_all=0});W.text=l
    local p=badge.ui.bar(bg,0,S.MAX_CAPTURE,0);p:set_pos(12,222);p:set_size(296,4)
    p:style({bg_color=0x30263F});p:style({bg_color=0xE8C573},"indicator");W.progress=p
    S.ui_live=true
  end
  function S.destroy_ui()
    if not S.ui_live then return end
    local bg=W.bg;S.ui_live=false
    if bg then bg:delete() end
    W={};S.widgets=W;S.last_screen=nil
  end
  function S.create_ui(parent) if not S.ui_live then build(parent) end end
  function S.render(now)
    if not S.ui_live then return end
    local shown=now<S.note_until and S.note or ""
    local out="SPELLBOUND / "..string.upper(S.phase:gsub("_"," ")).." / "..S.me:sub(-4).."\n\n"
    if S.phase=="home" then
      out=out..(S.selected==1 and "> " or "  ").."Find a duel\n"..
        (S.selected==2 and "> " or "  ").."Teach a spell\n\n"..
        (shown~="" and shown or ("Radio "..(S.radio_ok and "ON" or "OFF")))..
        "\nA open / B back"
    elseif S.phase=="train_select" then
      for n=1,3 do out=out..(n==S.selected and "> " or "  ")..S.spells[n]..
        (#S.models[n]>0 and " [learned]" or " [untrained]").."\n" end
      out=out.."\n"..(shown~="" and shown or "3 examples + fresh test").."\nA open / B back"
    elseif S.phase=="teach" then
      out=out..S.spells[S.training.spell].."\n"..
        (#S.training.samples<3 and ("Example "..(#S.training.samples+1).." of 3") or "Fresh test repetition")..
        "\n\nHold A, move, release.\n"..(shown~="" and shown or "Idle before/after is trimmed").."\nB cancels"
    elseif S.phase=="lobby" then
      if #S.peers==0 then out=out.."Searching...\nKeep both badges nearby."
      else for n,x in ipairs(S.peers) do out=out..(n==S.selected and "> " or "  ").."Badge "..x.id:sub(-4).."\n" end end
      out=out.."\nRadio code "..S.me:sub(-4).."\nA invite / B back"
    elseif S.phase=="offer" then
      out=out.."Challenge from "..S.invite.peer:sub(-4).."\n\nA accepts / B declines"
    elseif S.phase=="waiting" then out=out.."Invitation queued.\nWaiting for opponent.\n\nB cancels"
    elseif S.phase=="starting" or S.phase=="joining" then out=out.."Synchronizing...\n\nB cancels"
    elseif S.phase=="duel" or S.phase=="result" then
      local own=S.role=="host" and 1 or 2;local g=S.role=="host" and S.match or S.view
      if g then local foe=3-own
        out=out.."YOU HP "..g.hp[own].."  MANA "..g.mana[own]..
          "\nFOE HP "..g.hp[foe].."  MANA "..g.mana[foe].."\n\n"
      end
      local title="READY TO CAST"
      if S.phase=="result" then
        title=(not g or g.result==4) and "MATCH CANCELLED" or
          (g.result==3 and "DRAW" or (g.result==own and "YOU WIN" or "DEFEAT"))
        out=out..title.."\n"..(shown~="" and shown or "A or B returns to menu")
      else
        if g and g.incoming[own]>now then title=g.shield[own]>=g.incoming[own] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
        elseif now<S.effect_until and S.effect=="B" then title="BLOCKED"
        elseif S.capture then title="CHANNELING..."
        elseif S.pending then title="CAST QUEUED - WAIT"
        elseif g and g.shield[own]>now then title="SHIELD ACTIVE" end
        out=out..title.."\n"..(shown~="" and shown or "Hold A > move > release").."\nB twice surrenders"
      end
    end
    if S.last_screen~=out then W.text:set_text(out);S.last_screen=out end
    W.progress:hidden(not S.capture)
    if S.capture then W.progress:set_value(S.clamp(now-S.capture.start,0,S.MAX_CAPTURE)) end
  end
  build(root)
end
