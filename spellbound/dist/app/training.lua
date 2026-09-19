if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
S[33]=S[33] or {}
S[20]=function(sig)
if S[45]==2 and S[62] then
local spell=S[62][1]
if not S[62][2] then
S[62][2]=sig;S[30]("Now: fresh test",3);return
end
if S[14](sig,S[62][2])>0.48 then S[30]("Test again",4);return end
S[33][spell]=S[62][2]
S[30](S[59][spell].." learned",3,4000)
S[62]=nil;S[45]=1;return
end
local id,why=S[49](sig,S[33])
if id and S[60] then S[60](id) else S[30](why or "Duel unavailable",4) end
end
S[61]=function(button,kind,now)
if not now then
local shown=kind;local out=""
if S[45]==1 then
for n=1,3 do out=out..string.format("%s%s %s\n",n==S[54] and "> " or "  ",S[59][n],S[33][n] and "[ok]" or "[ ]") end
return out.."\n"..(shown~="" and shown or "1 example + test").."\nA open / B back"
end
local tr=S[62]
return S[59][tr[1]].."\n"..(not tr[2] and "Example" or "Fresh test")..
"\n\nHold A, move, release\n"..(shown~="" and shown or "Ready").."\nB cancels"
end
local B=badge.input.BUTTON
if button==B.B then
S[5]=nil
if S[45]==2 then S[62]=nil;S[45]=1
else S[51]() end
elseif S[45]==1 then
if button==B.UP then S[54]=(S[54]+1)%3+1
elseif button==B.DOWN then S[54]=S[54]%3+1
elseif button==B.A then S[62]={S[54]};S[45]=2 end
elseif S[45]==2 and button==B.A and not S[5] then S[6](now,0) end
end
