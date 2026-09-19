local Mock=dofile("tests/mock_badge.lua")
local a=Mock.new({file="dist/Badge-check.lua",production=true,mac="AA:00:00:00:00:01"})
local b=Mock.new({file="dist/Badge-check.lua",production=true,mac="AA:00:00:00:00:02"})
a:tap("A");assert(a.sent[1].payload=="SBC1 ping")
b:receive(a.mac,a.sent[1].payload);b:tick(200)
local got=false
for _,w in ipairs(b.widgets) do if rawget(w,"text") and w.text:find("RX ping from") then got=true end end
assert(got,"Checker did not display received ping")
a.env.on_exit();b.env.on_exit()
print("PASS standalone hardware checker mock transmit/receive and cleanup")
