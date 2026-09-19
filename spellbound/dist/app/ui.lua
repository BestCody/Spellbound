-- Low-memory Spellbound UI: 9 native widgets, no projectile/mana widgets.
return function(S,root)
  local floor=math.floor
  local W=S.widgets
  local function label(parent,key,x,y,w,h,size,color)
    local o=badge.ui.label(parent,"")
    o:set_pos(x,y);o:set_size(w,h)
    o:style({text_font=size,text_color=color or 0xE8E4F5,pad_all=0})
    W[key]=o
  end
  local function text(key,v)
    if S.text_cache[key]~=v then W[key]:set_text(v);S.text_cache[key]=v;return true end
  end

  local bg=badge.ui.box(root,320,240);bg:set_pos(0,0)
  bg:style({bg_color=0x100C20,border_width=0,pad_all=0,radius=0});W.bg=bg
  label(bg,"header",12,7,296,42,16,0xC3A0FF)
  label(bg,"body",12,54,296,106,16)
  label(bg,"p1",12,62,296,20,14,0xC3A0FF)
  label(bg,"p2",12,105,296,20,14,0xF0CA73)
  local hp1=badge.ui.bar(bg,0,100,100);hp1:set_pos(12,86);hp1:set_size(296,7)
  hp1:style({bg_color=0x30263F,radius=3});hp1:style({bg_color=0xC3A0FF},"indicator");W.hp1=hp1
  local hp2=badge.ui.bar(bg,0,100,100);hp2:set_pos(12,129);hp2:set_size(296,7)
  hp2:style({bg_color=0x30263F,radius=3});hp2:style({bg_color=0xF0CA73},"indicator");W.hp2=hp2
  label(bg,"info",12,148,296,68,14)
  local p=badge.ui.bar(bg,0,S.MAX_CAPTURE,0);p:set_pos(12,222);p:set_size(296,4)
  p:style({bg_color=0x30263F});p:style({bg_color=0xE8C573},"indicator");W.progress=p

  function S.render(now)
    local duel=S.phase=="duel" or S.phase=="result"
    local own=S.role=="host" and 1 or 2
    local g=S.role=="host" and S.match or S.view
    if S.visible_phase~=S.phase then
      S.visible_phase=S.phase
      W.body:hidden(duel)
      for _,k in ipairs({"p1","p2","hp1","hp2"}) do W[k]:hidden(not duel) end
    end
    text("header","SPELLBOUND\n"..string.upper(S.phase:gsub("_"," ")).." / "..S.me:sub(-4))
    local shown=now<S.note_until and S.note or ""

    if duel then
      local title="READY TO CAST"
      local hint="Hold A > move > release"
      local footer="B twice surrenders"
      if g then
        local a,b=own,3-own
        if text("p1","YOU  HP "..g.hp[a].."  MANA "..g.mana[a]) then W.hp1:set_value(g.hp[a]) end
        if text("p2","FOE  HP "..g.hp[b].."  MANA "..g.mana[b]) then W.hp2:set_value(g.hp[b]) end
      end
      if S.phase=="result" then
        title=(not g or g.result==4) and "MATCH CANCELLED" or
          (g.result==3 and "DRAW" or (g.result==own and "YOU WIN" or "DEFEAT"))
        hint=shown~="" and shown or "";footer="A or B returns to menu"
      else
        if g and g.incoming[own]>now then
          title=g.shield[own]>=g.incoming[own] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
        elseif now<S.effect_until and S.effect=="B" then title="BLOCKED"
        elseif S.capture then title="CHANNELING..."
        elseif S.pending then title="CAST QUEUED - WAIT"
        elseif g and g.shield[own]>now then title="SHIELD ACTIVE" end
        if shown~="" then hint=shown
        else hint="FIRE 30 / SHIELD 25 / MANA +35" end
      end
      text("info",title.."\n"..hint.."\n"..footer)
    else
      local body,hint,footer="","","UP/DOWN select  A open  B back"
      if S.phase=="home" or S.phase=="lobby" or S.phase=="train_select" then
        local items=S.phase=="home" and {"Find a duel","Teach a spell"} or {}
        if S.phase=="lobby" then for i,x in ipairs(S.peers) do items[i]="Badge "..x.id:sub(-4) end end
        if S.phase=="train_select" then
          for i=1,3 do items[i]=S.spells[i]..(#S.models[i]>0 and " [learned]" or " [untrained]") end
        end
        for i,v in ipairs(items) do body=body..(i==S.selected and "> " or "  ")..v.."\n" end
        if S.phase=="lobby" then
          hint="Radio code "..S.me:sub(-4).." / both badges Find a duel"
          if #S.peers==0 then body="Searching...\nKeep both badges nearby." end
        elseif S.phase=="home" then hint="Radio "..(S.radio_ok and "ON" or "OFF").." / Teach before casting"
        else hint="3 examples + fresh validation / session only" end
      elseif S.phase=="offer" then body="Challenge from "..S.invite.peer:sub(-4).."\n\nAccept this player?";footer="A accepts   B declines"
      elseif S.phase=="waiting" then body="Invitation queued.\nWaiting for opponent.";footer="B cancels"
      elseif S.phase=="starting" or S.phase=="joining" then body="Synchronizing...";footer="B cancels"
      elseif S.phase=="teach" then
        body=S.spells[S.training.spell].."\n"..(#S.training.samples<3 and
          ("Example "..(#S.training.samples+1).." of 3") or "Fresh test repetition")..
          "\n\nHold A, move, release."
        hint="Idle before/after motion is trimmed";footer="B cancels"
      end
      text("body",body)
      text("info",(shown~="" and shown or hint).."\n"..footer)
    end
    W.progress:hidden(not S.capture)
    if S.capture then W.progress:set_value(S.clamp(now-S.capture.start,0,S.MAX_CAPTURE)) end
  end

  function S.leds(now)
    local g=S.role=="host" and S.match or S.view
    local own=S.role=="host" and 1 or 2
    local mode=now<S.effect_until and S.effect or ""
    if S.phase=="result" and g and g.result==own then mode="W"
    elseif S.phase=="duel" and g and g.incoming[own]>now then
      mode=g.shield[own]>=g.incoming[own] and "S" or "I"
    elseif S.phase=="duel" and g and g.shield[own]>now and mode=="" then mode="S" end
    badge.led.clear();local step=floor(now/150)%6+1
    if mode=="F" or mode=="I" then for i=1,6 do if i==step then badge.led.set(i,S.LED,50,0) end end
    elseif mode=="S" or mode=="B" then badge.led.set_all(0,70,S.LED)
    elseif mode=="R" then badge.led.set_all(0,S.LED,100)
    elseif mode=="D" then badge.led.set_all(S.LED,0,0)
    elseif mode=="W" then for i=1,6 do if i==step then badge.led.set(i,S.LED,120,20) end end end
    badge.led.show()
  end
end
