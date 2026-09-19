-- Duel LED effects, loaded only with radio mode.
return function(S)
  local floor=math.floor
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
end
