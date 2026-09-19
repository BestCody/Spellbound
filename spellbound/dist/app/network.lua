if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
S[43]=S[43] or {}
S[17]=function()
S[26]=true
if S[28] then S[28][1]=4 end
if S[64] then S[64][1]=4 end
S[45],S[44],S[5]=8,nil,nil
S[15],S[16]=0,0
S[30]("Link ended",nil,60000)
end
S[63]=function(kind,data)
if S[57] then return badge.radio.send("SB2"..kind..S[57]..(data or "")) end
end
S[55]=function(now)
S[52]=(S[52] or 0)+1
if S[52]>65535 then S[28][1]=4;S[52]=65535 end
S[63]("T",string.format("%04X",S[52])..S[8](0,S[28],now))
S[24]=now
end
S[19]=function(code,spell)
if code~=0 then S[30]("Cast rejected",4);return end
S[30](spell==4 and "You surrendered" or (S[59][spell].." cast"),spell==4 and nil or spell)
end
S[60]=function(spell)
if S[45]~=7 then return end
local now=S[7]()
if S[53]==1 then
S[19](S[3](S[28],1,spell,0,now),spell);S[55](now)
else
if S[44] then S[30]("Wait for cast");return end
if S[56]>=65534 then S[30]("Match ended");return end
S[56]=S[56]+1;S[44]={S[56],spell,now,now}
end
end
