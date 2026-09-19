if SPELLBOUND_STATE[4]~=4 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
S[34]=S[34] or {}
S[21]=function(sig)
if S[49]==2 and S[68] then
local spell=S[68][1]
if not S[68][2] then
S[68][2]=sig;S[31]("Now test with a NEW repetition",3);return
end
local old=S[34][spell];S[34][spell]=S[68][2]
local id,why=S[53](sig,S[34])
if id~=spell then
S[34][spell]=old
if id then S[31]("Looks like "..S[63][id].." - make it distinct",4)
else S[31](why or "Test failed - repeat",4) end
return
end
S[31](S[63][id].." learned for this session",3,4000)
S[68]=nil;S[49]=1;return
end
local id,why=S[53](sig,S[34])
if id and S[65] then S[65](id) else S[31](why or "Duel unavailable",4) end
end
S[67]=function(now,shown)
local out=""
if S[49]==1 then
for n=1,3 do
out=out..(n==S[58] and "> " or "  ")..S[63][n]..
(S[34][n] and " [learned]" or " [untrained]").."\n"
end
return out.."\n"..(shown~="" and shown or "1 example + fresh test").."\nA open / B back"
end
local tr=S[68]
return S[63][tr[1]].."\n"..
(not tr[2] and "Training example" or "Fresh test repetition")..
"\n\nHold A, move, release.\n"..(shown~="" and shown or "Idle before/after is trimmed").."\nB cancels"
end
S[66]=function(button,kind,now)
local B,K=badge.input.BUTTON,badge.input.KIND
if kind~=K.PRESSED then return end
if button==B.B then
S[5]=nil
if S[49]==2 then S[68]=nil;S[49]=1
else S[55]() end
elseif S[49]==1 then
if button==B.UP then S[58]=(S[58]+1)%3+1
elseif button==B.DOWN then S[58]=S[58]%3+1
elseif button==B.A then S[68]={S[58]};S[49]=2 end
elseif S[49]==2 and button==B.A and not S[5] then S[7](now) end
end
