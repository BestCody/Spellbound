if SPELLBOUND_STATE[4]~=3 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
S[38]=S[38] or {{},{},{}}
S[22]=function(sig)
if S[53]=="teach" and S[73] then
local spell=S[73][1];local samples=S[73][2]
if #samples==0 then
samples[1]=sig;S[35]("Now test with a NEW repetition","R");return
end
local old=S[38][spell];S[38][spell]=samples
local id,why=S[58](sig,S[38])
if id~=spell then
S[38][spell]=old
if id then S[35]("Looks like "..S[68][id].." - make it distinct","X")
else S[35](why or "Test failed - repeat","X") end
return
end
S[35](S[68][id].." learned for this session","R",4000)
S[73]=nil;S[53]="train_select";return
end
local id,why=S[58](sig,S[38])
if id and S[70] then S[70](id) else S[35](why or "Duel unavailable","X") end
end
S[72]=function(now,shown)
local out=""
if S[53]=="train_select" then
for n=1,3 do
out=out..(n==S[63] and "> " or "  ")..S[68][n]..
(#S[38][n]>0 and " [learned]" or " [untrained]").."\n"
end
return out.."\n"..(shown~="" and shown or "1 example + fresh test").."\nA open / B back"
end
local tr=S[73];local samples=tr and tr[2] or {}
return S[68][tr[1]].."\n"..
(#samples==0 and "Training example" or "Fresh test repetition")..
"\n\nHold A, move, release.\n"..(shown~="" and shown or "Idle before/after is trimmed").."\nB cancels"
end
S[71]=function(button,kind,now)
local B,K=badge.input.BUTTON,badge.input.KIND
if kind~=K.PRESSED then return end
if button==B.B then
S[5]=nil
if S[53]=="teach" then S[73]=nil;S[53]="train_select"
else S[60]() end
elseif S[53]=="train_select" then
if button==B.UP then S[63]=(S[63]+1)%3+1
elseif button==B.DOWN then S[63]=S[63]%3+1
elseif button==B.A then S[73]={S[63],{}};S[53]="teach" end
elseif S[53]=="teach" and button==B.A and not S[5] then S[7](now) end
end
