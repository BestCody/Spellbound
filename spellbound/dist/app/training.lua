local S=SPELLBOUND_STATE
S.models=S.models or {{},{},{}}
S.thresholds=S.thresholds or {}
local function log_meta(m)
if not m then return end
badge.sys.log(string.format("GESTURE hold=%d active=%d samples=%d start=%d end=%d peak=%d rms=%d",
m.hold_ms or -1,m.active_ms or -1,m.samples or -1,m.start_ms or -1,m.end_ms or -1,
m.peak_delta or -1,m.rms_delta or -1))
end
local function log_diag(d,result)
if not d then return end
local s=d.scores or {99,99,99};local best=d.best and S.codes[d.best] or "-"
badge.sys.log(string.format("GESTURE scores F=%.3f S=%.3f R=%.3f best=%s thr=%.3f ratio=%.3f %s",
s[1] or 99,s[2] or 99,s[3] or 99,best,d.threshold or -1,d.ratio or -1,result or ""))
end
function S.handle_signature(sig,meta)
log_meta(meta)
if S.phase=="teach" and S.training then
local spell=S.training[1];local samples=S.training[2]
if #samples<3 then
local nearest=99
for i=1,#samples do nearest=math.min(nearest,S.distance(sig,samples[i])) end
if #samples==1 and nearest>S.train_max then
samples[1]=sig
badge.sys.log(string.format("GESTURE train %s reset-baseline d=%.3f",S.codes[spell],nearest))
S.message("New baseline saved - repeat it","R");return
elseif #samples>1 and nearest>S.train_max then
badge.sys.log(string.format("GESTURE train %s reject sample=%d nearest=%.3f",S.codes[spell],#samples+1,nearest))
S.message("Movement changed too much - repeat","X");return
end
samples[#samples+1]=sig
if #samples>1 then badge.sys.log(string.format("GESTURE train %s sample=%d nearest=%.3f",S.codes[spell],#samples,nearest)) end
if #samples==3 then
local th,spread,mean=S.calibrate(samples);S.training[3]=th
badge.sys.log(string.format("GESTURE calibrate %s spread=%.3f mean=%.3f thr=%.3f",S.codes[spell],spread,mean,th))
S.message("Now test with a NEW repetition","R")
else S.message("Example saved in RAM","R") end
return
end
local oldm,oldt=S.models[spell],S.thresholds[spell]
local th=S.training[3] or S.calibrate(samples)
S.models[spell],S.thresholds[spell]=samples,th
local id,why,_,diag=S.recognize(sig,S.models,S.thresholds)
log_diag(diag,id==spell and "ACCEPT-VALIDATION" or "REJECT-VALIDATION")
if id~=spell then
S.models[spell],S.thresholds[spell]=oldm,oldt
if id then S.message("Looks like "..S.spells[id].." - make it distinct","X")
else S.message(why or "Test failed - repeat","X") end
return
end
S.message(S.spells[id].." learned for this session","R",4000)
S.training=nil;S.phase="train_select";return
end
local id,why,_,diag=S.recognize(sig,S.models,S.thresholds)
log_diag(diag,id and "ACCEPT-CAST" or "REJECT-CAST")
if id and S.submit then S.submit(id) else S.message(why or "Duel unavailable","X") end
end
function S.teach_render(now,shown)
local out=""
if S.phase=="train_select" then
for n=1,3 do
out=out..(n==S.selected and "> " or "  ")..S.spells[n]..
(#S.models[n]>0 and " [learned]" or " [untrained]").."\n"
end
return out.."\n"..(shown~="" and shown or "3 examples + fresh test").."\nA open / B back"
end
local tr=S.training;local samples=tr and tr[2] or {}
return S.spells[tr[1]].."\n"..
(#samples<3 and ("Example "..(#samples+1).." of 3") or "Fresh test repetition")..
"\n\nHold A, move, release.\n"..(shown~="" and shown or "Idle before/after is trimmed").."\nB cancels"
end
function S.teach_button(button,kind,now)
local B,K=badge.input.BUTTON,badge.input.KIND
if kind~=K.PRESSED then return end
if button==B.B then
S.capture=nil
if S.phase=="teach" then S.training=nil;S.phase="train_select"
else S.reset_home() end
elseif S.phase=="train_select" then
if button==B.UP then S.selected=(S.selected+1)%3+1
elseif button==B.DOWN then S.selected=S.selected%3+1
elseif button==B.A then S.training={S.selected,{}};S.phase="teach" end
elseif S.phase=="teach" and button==B.A and not S.capture then S.capture_start(now) end
end
