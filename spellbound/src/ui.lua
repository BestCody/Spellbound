-- Spellbound native UI and LED rendering. Loaded only for foreground display.
return function(S,root)
  local floor=math.floor
  local W=S.widgets
  local function label(parent,key,x,y,w,h,size,color)
    local obj=badge.ui.label(parent,"")
    obj:set_pos(x,y);obj:set_size(w,h)
    obj:style({text_font=size,text_color=color or 0xE8E4F5,pad_all=0})
    W[key]=obj
  end
  local function text(key,value)
    if S.text_cache[key]~=value then W[key]:set_text(value);S.text_cache[key]=value;return true end
  end

  local bg=badge.ui.box(root,320,240);bg:set_pos(0,0)
  bg:style({bg_color=0x100C20,border_width=0,pad_all=0,radius=0})
  label(bg,"title",12,7,296,27,24,0xC3A0FF)
  label(bg,"status",12,37,296,20,14,0xA49BB8)
  label(bg,"body",12,63,296,111,16)
  label(bg,"left",12,63,140,19,14,0xC3A0FF);label(bg,"right",168,63,140,19,14,0xF0CA73)
  label(bg,"score1",12,97,140,18,14);label(bg,"score2",168,97,140,18,14)
  label(bg,"effect",12,128,296,24,18,0xF0CA73)
  label(bg,"hint",12,180,296,36,14,0xE8E4F5)
  label(bg,"footer",12,221,296,17,14,0xB9B2CB)
  for i=1,4 do
    local b=badge.ui.bar(bg,0,100,100)
    b:set_pos(i%2==1 and 12 or 168,i<=2 and 85 or 117);b:set_size(140,i<=2 and 7 or 4)
    b:style({bg_color=0x30263F,radius=3})
    b:style({bg_color=i>2 and 0x69C9C4 or (i==1 and 0xC3A0FF or 0xF0CA73)},"indicator")
    W["bar"..i]=b
  end
  local p=badge.ui.bar(bg,0,2400,0);p:set_pos(12,173);p:set_size(296,4)
  p:style({bg_color=0x30263F});p:style({bg_color=0xE8C573},"indicator");W.progress=p
  for i=1,2 do
    local o=badge.ui.box(bg,9,9);o:style({bg_color=0xFF924E,border_width=0,radius=4});W["orb"..i]=o
  end

  function S.render(now)
    local duel=S.phase=="duel" or S.phase=="result"
    local own=S.role=="host" and 1 or 2
    local g=S.role=="host" and S.match or S.view
    if S.visible_phase~=S.phase then
      S.visible_phase=S.phase;W.body:hidden(duel)
      for _,k in ipairs({"left","right","score1","score2","effect","bar1","bar2","bar3","bar4"}) do W[k]:hidden(not duel) end
    end
    local shown=now<S.note_until and S.note or ""
    local hint,footer="","UP/DOWN select  A open  B back"
    text("title","SPELLBOUND")
    text("status",string.upper(S.phase:gsub("_"," ")).." / MOTION / "..S.me:sub(-4))
    if duel then
      if g then
        for i=1,2 do
          local player=i==1 and own or 3-own
          if text(i==1 and "left" or "right",(i==1 and "YOU  HP " or "FOE  HP ")..g.hp[player]) then W["bar"..i]:set_value(g.hp[player]) end
          if text("score"..i,"MANA "..g.mana[player]) then W["bar"..(i+2)]:set_value(g.mana[player]) end
        end
      end
      local title="READY TO CAST"
      if S.phase=="result" then
        title=(not g or g.result==4) and "MATCH CANCELLED" or (g.result==3 and "DRAW" or (g.result==own and "YOU WIN" or "DEFEAT"))
        footer="A or B returns to menu"
      else
        if g and g.incoming[own]>now then title=g.shield[own]>=g.incoming[own] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
        elseif now<S.effect_until and S.effect=="B" then title="BLOCKED"
        elseif S.capture then title="CHANNELING..."
        elseif S.pending then title="CAST QUEUED - WAIT"
        elseif g and g.shield[own]>now then title="SHIELD ACTIVE" end
        footer="Hold A > move > release"
        hint="FIRE 30  SHIELD 25  MANA +35\nTeach spells first. B twice surrenders."
      end
      text("effect",title)
    else
      local body=""
      if S.phase=="home" or S.phase=="lobby" or S.phase=="train_select" then
        local items=S.phase=="home" and {"Find a duel","Teach a spell"} or {}
        if S.phase=="lobby" then for i,x in ipairs(S.peers) do items[i]="Badge "..x.id:sub(-4) end end
        if S.phase=="train_select" then for i=1,3 do items[i]=S.spells[i]..(#S.models[i]>0 and " [learned]" or " [untrained]") end end
        for i,t in ipairs(items) do body=body..(i==S.selected and "> " or "  ")..t.."\n" end
        if S.phase=="lobby" then
          hint="Your radio code: "..S.me:sub(-4).."\nOne player sends the invitation."
          if #S.peers==0 then body="Searching...\nBoth badges: Find a duel.\nKeep badges nearby." end
        elseif S.phase=="home" then
          hint="Radio "..(S.radio_ok and "ON" or "OFF").."\nTeach spells before motion casting";footer="A open   B back"
        else hint="Three examples, then a fresh test. Session only." end
      elseif S.phase=="offer" then body="Challenge from "..S.invite.peer:sub(-4).."\n\nAccept this player?";footer="A accepts   B declines"
      elseif S.phase=="waiting" then body="Invitation queued.\nWaiting for opponent to accept.";footer="B cancels"
      elseif S.phase=="starting" or S.phase=="joining" then body="Synchronizing...";footer="B cancels"
      elseif S.phase=="teach" then
        body=S.spells[S.training.spell].."\n"..(#S.training.samples<3 and ("Example "..(#S.training.samples+1).." of 3") or "Fresh test repetition").."\n\nHold still; move; release A."
        hint="Keep the same starting pose.\nValid for this app session.";footer="Hold A to record   B cancels"
      end
      text("body",body)
    end
    text("hint",shown~="" and shown or hint);text("footer",S.capture and "Recording... release A" or footer)
    W.progress:hidden(not S.capture);if S.capture then W.progress:set_value(S.clamp(now-S.capture.start,0,2400)) end
    for i=1,2 do
      local active=S.phase=="duel" and g and g.incoming[i]>now
      W["orb"..i]:hidden(not active)
      if active then local f=S.clamp(1-(g.incoming[i]-now)/1800,0,1);W["orb"..i]:set_pos(S.round(i==own and 284-f*268 or 16+f*268),i==own and 151 or 161) end
    end
  end

  function S.leds(now)
    local g=S.role=="host" and S.match or S.view
    local own=S.role=="host" and 1 or 2
    local mode=now<S.effect_until and S.effect or ""
    if S.phase=="result" and g and g.result==own then mode="W"
    elseif S.phase=="duel" and g and g.incoming[own]>now then mode=g.shield[own]>=g.incoming[own] and "S" or "I"
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
