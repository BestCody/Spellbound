-- Small recognizer loader; heavy pieces compile separately.
local M={}
local a=require("gesture_sig")
M.raw_sample,M.signature=a.raw_sample,a.signature
if package and package.loaded then package.loaded["gesture_sig"]=nil end
a=nil;badge.sys.gc_step()
local b=require("gesture_dtw")
M.distance,M.class_score,M.calibrate,M.recognize=b.distance,b.class_score,b.calibrate,b.recognize
M.train_max=b.train_max
if package and package.loaded then package.loaded["gesture_dtw"]=nil end
b=nil;badge.sys.gc_step()
return M
