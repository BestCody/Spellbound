if SPELLBOUND_STATE[4]~=3 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
S[51]=S[51] or {}
S[55]=S[55] or false
S[19]=function(reason)
S[31]=true
if S[33] then S[33][1]=4 end
if S[76] then S[76][1]=4 end
S[53],S[52],S[5]="result",nil,nil
S[17],S[18]="",0
S[35](reason,nil,60000)
end
S[74]=function(kind,data)
if not S[54] or not S[66] then return false end
local p="SB1|"..kind.."|"..S[66]..(data and ("|"..data) or "")
if #p>44 then return false end
return badge.radio.send(p)
end
S[69]=function(p)
if type(p)~="string" or #p>44 then return nil end
local k,s,d=p:match("^SB1|([IJSKCTPQ])|([0-9A-F]+)|?(.*)$")
if not k or #s~=8 then return nil end
if p~="SB1|"..k.."|"..s..(d~="" and ("|"..d) or "") then return nil end
return k,s,d
end
S[64]=function(now)
if not S[33] then return end
S[61]=(S[61] or 0)+1
if S[61]>65535 then S[33][1]=4;S[61]=65535 end
S[74]("T",string.format("%04X|",S[61])..S[49](S[33],now))
S[28]=now
end
S[21]=function(code,spell)
if code==0 then
S[35](spell==4 and "You surrendered" or (S[68][spell].." cast"),spell==4 and nil or S[10][spell])
else
local m=code==1 and "Not enough mana" or
(code==2 and "Spell cooling down" or
(code==3 and "Attack already in flight" or
(code==4 and "Match finished" or "Out-of-order action")))
S[35](m,"X")
end
end
S[70]=function(spell)
if S[53]~="duel" then return end
local now=S[9]()
if S[62]=="host" then
S[21](S[3](S[33],1,spell,0,now),spell);S[64](now)
elseif S[76] then
if S[52] then S[35]("Waiting for cast acknowledgement");return end
if S[65]>=65534 then S[35]("Match limit - start a new duel");return end
S[65]=S[65]+1;S[52]={S[65],spell,now,now}
end
end
S[39]=function(button,kind,now)
local B,K=badge.input.BUTTON,badge.input.KIND
if kind~=K.PRESSED then return end
if button==B.B then
S[5]=nil
if S[53]=="duel" then
if now<(S[29] or 0) then S[70](4);S[29]=0
else S[29]=now+1800;S[35]("Press B again to surrender",nil,1800) end
elseif S[53]=="offer" then
S[13],S[14]=S[23][1]..S[23][2],now+14000
badge.radio.send("SB1|Q|"..S[23][2]);S[23]=nil;S[53]="lobby"
elseif S[53]=="result" then S[60]()
else
if S[66] and S[53]~="result" then S[74]("Q") end
S[60]()
end
return
end
if S[53]=="lobby" then
if button==B.UP then S[63]=math.max(1,S[63]-1)
elseif button==B.DOWN then S[63]=math.min(math.max(1,#S[51]/3),S[63]+1)
elseif button==B.A and S[51][(S[63]-1)*3+1] then
if S[20] then S[20]() end
S[50]=S[51][(S[63]-1)*3+1];S[66]=string.format("%08X",badge.sys.random())
S[62],S[53],S[12],S[26],S[45]="host","waiting",now+12000,now,0
S[65],S[61],S[25]=0,0,-1;S[31]=false
end
elseif S[53]=="offer" and button==B.A then
if S[20] then S[20]() end
S[50],S[66]=S[23][1],S[23][2];S[23]=nil
S[62],S[53],S[12],S[26],S[45]="guest","joining",now+12000,now,0
S[65],S[61],S[25]=0,0,-1;S[31]=false
elseif S[53]=="duel" and button==B.A and not S[5] then
if S[7] then S[7](now) else S[35]("Teach spells before duel","X") end
elseif S[53]=="result" and button==B.A then S[60]() end
end
