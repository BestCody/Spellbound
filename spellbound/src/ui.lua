-- Minimal rebuildable Spellbound UI: 5 native widgets.
return function(S,root)
  local floor=math.floor
  local W={}
  local function text(key,v)
    if S.text_cache[key]~=v then W[key]:set_text(v);S.text_cache[key]=v end
  end
  local function build(parent)
    W={};S.widgets=W;S.text_cache={};S.visible_phase=nil
    local bg=badge.ui.box(parent,320,240);bg:set_pos(0,0)
    bg:style({bg_color=0x100C20,border_width=0,pad_all=0,radius=0});W.bg=bg
    local h=badge.ui.label(bg,"");h:set_pos(12,7);h:set_size(296,42)
    h:style({text_font=16,text_color=0xC3A0FF,pad_all=0});W.header=h
    local b=badge.ui.label(bg,"");b:set_pos(12,55);b:set_size(296,105)
    b:style({text_font=16,text_color=0xE8E4F5,pad_all=0});W.body=b
    local i=badge.ui.label(bg,"");i:set_pos(12,165);i:set_size(296,50)
    i:style({text_font=14,text_color=0xE8E4F5,pad_all=0});W.info=i
    local p=badge.ui.bar(bg,0,S.MAX_CAPTURE,0);p:set_pos(12,222);p:set_size(296,4)
    p:style({bg_color=0x30263F});p:style({bg_color=0xE8C573},"indicator");W.progress=p
    S.ui_live=true
  end
  function S.destroy_ui()
    if not S.ui_live then return end
    local bg=W.bg;S.ui_live=false
    if bg then bg:delete() end
    W={};S.widgets=W;S.text_cache={};S.visible_phase=nil
  end
  function S.create_ui(parent) if not S.ui_live then build(parent) end end
  function S.render(now)
    if not S.ui_live then return end
    local shown=now<S.note_until and S.note or ""
    text("header","SPELLBOUND\n"..string.upper(S.phase:gsub("_"," ")).." / "..S.me:sub(-4))
    local body,info="",""
    if S.phase=="duel" or S.phase=="result" then
      local own=S.role=="host" and 1 or 2
      local g=S.role=="host" and S.match or S.view
      if g then
        local foe=3-own
        body="YOU  HP "..g.hp[own].."  MANA "..g.mana[own]..
          "\nFOE  HP "..g.hp[foe].."  MANA "..g.mana[foe]
      end
      local title="READY TO CAST"
      if S.phase=="result" then
        title=(not g or g.result==4) and "MATCH CANCELLED" or
          (g.result==3 and "DRAW" or (g.result==own and "YOU WIN" or "DEFEAT"))
        info=title.."\n"..(shown~="" and shown or "A or B returns to menu")
      else
        if g and g.incoming[own]>now then
          title=g.shield[own]>=g.incoming[own] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
        elseif now<S.effect_until and S.effect=="B" then title="BLOCKED"
        elseif S.capture then title="CHANNELING..."
        elseif S.pending then title="CAST QUEUED - WAIT"
        elseif g and g.shield[own]>now then title="SHIELD ACTIVE" end
        info=title.."\n"..(shown~="" and shown or "Hold A > move > release / B twice surrenders")
      end
    elseif S.phase=="home" or S.phase=="lobby" or S.phase=="train_select" then
      local items=S.phase=="home" and {"Find a duel","Teach a spell"} or {}
      if S.phase=="lobby" then for n,x in ipairs(S.peers) do items[n]="Badge "..x.id:sub(-4) end end
      if S.phase=="train_select" then
        for n=1,3 do items[n]=S.spells[n]..(#S.models[n]>0 and " [learned]" or " [untrained]") end
      end
      for n,v in ipairs(items) do body=body..(n==S.selected and "> " or "  ")..v.."\n" end
      if S.phase=="lobby" then
        if #S.peers==0 then body="Searching...\nKeep both badges nearby." end
        info=shown~="" and shown or ("Radio code "..S.me:sub(-4).." / both badges Find a duel")
      elseif S.phase=="home" then info=shown~="" and shown or ("Radio "..(S.radio_ok and "ON" or "OFF").." / Teach before casting")
      else info=shown~="" and shown or "3 examples + fresh validation / session only" end
    elseif S.phase=="offer" then body="Challenge from "..S.invite.peer:sub(-4).."\n\nAccept this player?";info="A accepts / B declines"
    elseif S.phase=="waiting" then body="Invitation queued.\nWaiting for opponent.";info="B cancels"
    elseif S.phase=="starting" or S.phase=="joining" then body="Synchronizing...";info="B cancels"
    elseif S.phase=="teach" then
      body=S.spells[S.training.spell].."\n"..(#S.training.samples<3 and
        ("Example "..(#S.training.samples+1).." of 3") or "Fresh test repetition")..
        "\n\nHold A, move, release."
      info=shown~="" and shown or "Idle before/after motion is trimmed / B cancels"
    end
    text("body",body);text("info",info)
    W.progress:hidden(not S.capture)
    if S.capture then W.progress:set_value(S.clamp(now-S.capture.start,0,S.MAX_CAPTURE)) end
  end
  function S.leds(now)
    local g=S.role=="host" and S.match or S.view
    local own=S.role=="host" and 1 or 2
    local mode=now<S.effect_until and S.effect or ""
    if S.phase=="result" and g and g.result==own then mode="W"
    elseif S.phase=="duel" and g and g.incoming[own]>now then mode=g.shield[own]>=g.incoming[own] and "S" or "I"
    elseif S.phase=="duel" and g and g.shield[own]>now and mode=="" then mode="S" end
    badge.led.clear();local step=floor(now/150)%6+1
    if mode=="F" or mode=="I" then for n=1,6 do if n==step then badge.led.set(n,S.LED,50,0) end end
    elseif mode=="S" or mode=="B" then badge.led.set_all(0,70,S.LED)
    elseif mode=="R" then badge.led.set_all(0,S.LED,100)
    elseif mode=="D" then badge.led.set_all(S.LED,0,0)
    elseif mode=="W" then for n=1,6 do if n==step then badge.led.set(n,S.LED,120,20) end end end
    badge.led.show()
  end
  build(root)
end
