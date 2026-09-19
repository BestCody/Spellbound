if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
S[3]=function(g,p,spell,number,now)
if p==2 and number~=S[56]+1 then return 1 end
S[2](g,now)
local result=0;local mi=3+p;local ti=6+p*3;local ii=10-p;local si=5+p
local cost=spell==1 and 30 or (spell==2 and 25 or 0)
if g[1]~=0 then result=1
elseif spell==4 then g[1]=3-p
elseif g[mi]<cost or now<g[ti+spell] or (spell==1 and g[ii]>0) then result=1
else
g[mi]=math.min(100,math.max(0,g[mi]-cost+(spell==3 and 35 or 0)))
g[ti+spell]=now+(spell==3 and 3000 or 2400)
if spell==1 then g[ii]=now+1800 elseif spell==2 then g[si]=now+2200 end
end
if p==2 then S[56],g[16]=number,result end
return result
end
