if SPELLBOUND_STATE[4]~=4 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
S[47]=S[47] or {}
S[18]=function(reason)
S[27]=true
if S[29] then S[29][1]=4 end
if S[71] then S[71][1]=4 end
S[49],S[48],S[5]=9,nil,nil
S[16],S[17]=0,0
S[31](reason,nil,60000)
end
S[69]=function(kind,data)
if not S[50] or not S[61] then return false end
local p="SB1|"..kind.."|"..S[61]..(data and ("|"..data) or "")
if #p>44 then return false end
return badge.radio.send(p)
end
S[64]=function(p)
if type(p)~="string" or #p>44 then return nil end
local k,s,d=p:match("^SB1|([IJSKCTPQ])|([0-9A-F]+)|?(.*)$")
if not k or #s~=8 then return nil end
if p~="SB1|"..k.."|"..s..(d~="" and ("|"..d) or "") then return nil end
return k,s,d
end
S[59]=function(now)
if not S[29] then return end
S[56]=(S[56] or 0)+1
if S[56]>65535 then S[29][1]=4;S[56]=65535 end
S[69]("T",string.format("%04X|",S[56])..S[45](S[29],now))
S[25]=now
end
S[20]=function(code,spell)
if code==0 then
S[31](spell==4 and "You surrendered" or (S[63][spell].." cast"),spell==4 and nil or spell)
else
local m=code==1 and "Not enough mana" or
(code==2 and "Spell cooling down" or
(code==3 and "Attack already in flight" or
(code==4 and "Match finished" or "Out-of-order action")))
S[31](m,4)
end
end
S[65]=function(spell)
if S[49]~=8 then return end
local now=S[9]()
if S[57]==1 then
S[20](S[3](S[29],1,spell,0,now),spell);S[59](now)
elseif S[71] then
if S[48] then S[31]("Waiting for cast acknowledgement");return end
if S[60]>=65534 then S[31]("Match limit - start a new duel");return end
S[60]=S[60]+1;S[48]={S[60],spell,now,now}
end
end
S[35]=function(button,kind,now)
local B,K=badge.input.BUTTON,badge.input.KIND
if kind~=K.PRESSED then return end
local phase=S[49]
if button==B.B then
S[5]=nil
if phase==8 then
if now<(S[12] or 0) then S[65](4);S[12]=0
else S[12]=now+1800;S[31]("Press B again to surrender",nil,1800) end
elseif phase==4 then
S[13],S[12]=S[22][1]..S[22][2],now+14000
badge.radio.send("SB1|Q|"..S[22][2]);S[22]=nil;S[49]=3
elseif phase==9 then S[55]()
else
if S[61] and phase~=9 then S[69]("Q") end
S[55]()
end
return
end
if phase==3 then
if button==B.UP then S[58]=math.max(1,S[58]-1)
elseif button==B.DOWN then S[58]=math.min(math.max(1,#S[47]/3),S[58]+1)
elseif button==B.A and S[47][(S[58]-1)*3+1] then
if S[19] then S[19]() end
S[46]=S[47][(S[58]-1)*3+1];S[47]=nil;S[61]=string.format("%08X",badge.sys.random())
S[57],S[49],S[12],S[23],S[41]=1,5,now+12000,now,0
S[60],S[56]=0,0;S[27]=false
end
elseif phase==4 and button==B.A then
if S[19] then S[19]() end
S[46],S[61]=S[22][1],S[22][2];S[22],S[47]=nil,nil
S[57],S[49],S[12],S[23],S[41]=2,7,now+12000,now,0
S[60],S[56]=0,-1;S[27]=false
elseif phase==8 and button==B.A and not S[5] then
if S[7] then S[7](now) else S[31]("Teach spells before duel",4) end
elseif phase==9 and button==B.A then S[55]() end
end
