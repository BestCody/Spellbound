if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
S[34]=function(button,kind,now)
if not now then
local shown=kind;now=button
local out="";local phase=S[45]
if phase==3 then
if #S[43]==0 then out="Searching..."
else for i=1,#S[43],3 do
local n=(i+2)/3;out=out..string.format("%sBadge %s\n",n==S[54] and "> " or "  ",S[43][i]:sub(-6))
end end
return out.."\nA invite / B back"
elseif phase==4 then return "Challenge "..S[21][1]:sub(-6).."\n\nA accept / B decline"
elseif phase==5 then return "Waiting...\n\nB cancels"
elseif phase==6 then return "Syncing...\n\nB cancels" end
local own=S[53]==1 and 1 or 2;local g=own==1 and S[28] or S[64]
if g then
local hi=1+own;local mi=3+own
out=string.format("YOU HP %d  MANA %d\nFOE HP %d  MANA %d\n\n",g[hi],g[mi],g[5-hi],g[9-mi])
end
local title="READY TO CAST"
if phase==8 then
title=(not g or g[1]==4) and "MATCH CANCELLED" or (g[1]==3 and "DRAW" or (g[1]==own and "YOU WIN" or "DEFEAT"))
return out..title.."\n"..(shown~="" and shown or "A/B: menu")
end
if g then
local si=5+own;local ii=7+own
if g[ii]>now then title=g[si]>=g[ii] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
elseif now<S[16] and S[15]==6 then title="BLOCKED"
elseif S[5] then title="CHANNELING..."
elseif S[44] then title="CAST QUEUED - WAIT"
elseif g[si]>now then title="SHIELD ACTIVE" end
end
return out..title.."\n"..(shown~="" and shown or "Hold A, move, release").."\nB twice: surrender"
end
local B=badge.input.BUTTON
local phase=S[45]
if button==B.B then
S[5]=nil
if phase==7 then
if now<(S[11] or 0) then S[60](4);S[11]=0 else S[11]=now+1800;S[30]("B again: surrender",nil,1800) end
elseif phase==4 then
S[12],S[11]=S[21][1]..S[21][2],now+14000
badge.radio.send("SB2Q"..S[21][2]);S[21]=nil;S[45]=3
elseif phase==8 then S[51]()
else if S[57] then S[63]("Q") end;S[51]() end
return
end
local role,next_phase,revision
if phase==3 then
if button==B.UP then S[54]=math.max(1,S[54]-1)
elseif button==B.DOWN then S[54]=math.min(math.max(1,#S[43]/3),S[54]+1)
elseif button==B.A and S[43][(S[54]-1)*3+1] then
S[42]=S[43][(S[54]-1)*3+1];S[43]=nil;S[57]=string.format("%08X",badge.sys.random())
role,next_phase,revision=1,5,0
end
elseif phase==4 and button==B.A then
S[42],S[57]=S[21][1],S[21][2];S[21],S[43]=nil,nil
role,next_phase,revision=2,6,-1
elseif phase==7 and button==B.A and not S[5] then
if S[6] then S[6](now,0) else S[30]("Teach before duel",4) end
elseif phase==8 and button==B.A then S[51]() end
if role then
S[53],S[45],S[11],S[22],S[38]=role,next_phase,now+12000,now,0
S[56],S[52],S[24]=0,revision,0;S[26]=false;if S[18] then S[18]() end
end
end
S[25]=function(now)
local mode=now<S[16] and S[15] or 0
badge.led.clear();local step=math.floor(now/150)%6+1
if mode==1 then badge.led.set(step,160,50,0)
elseif mode==2 or mode==6 then badge.led.set_all(0,70,160)
elseif mode==3 then badge.led.set_all(0,160,100)
elseif mode==5 then badge.led.set_all(160,0,0)
elseif mode==7 then badge.led.set(step,160,120,20) end
badge.led.show()
end
