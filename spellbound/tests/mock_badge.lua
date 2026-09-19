-- Desktop-only strict mock. Production code cannot see host filesystem/network.
local M={}
local allowed_style={bg_color=true,bg_opa=true,color=true,opa=true,radius=true,
 border_color=true,border_opa=true,border_width=true,text_color=true,text_opa=true,
 text_font=true,text_align=true,arc_color=true,arc_opa=true,arc_width=true,line_color=true,
 line_opa=true,line_width=true,pad_all=true,pad_top=true,pad_bottom=true,pad_left=true,
 pad_right=true,pad_row=true,pad_column=true,shadow_color=true,shadow_opa=true,
 shadow_width=true,shadow_spread=true,shadow_offset_x=true,shadow_offset_y=true,flex_flow=true}
local function integer(n) assert(type(n)=="number" and n==math.floor(n),"coordinate/value must be integer") end
function M.new(opts)
 opts=opts or {}
 local c={now=0,offset=opts.offset or 0,mac=opts.mac or "AA:00:00:00:00:01",sent={},
  files=opts.files or {},store=opts.store or {},held={},widgets={},logs={},leds={},
  accel={0,0,1000},radio=opts.radio~=false,drop_count=0,disabled=false,write_fail=false,enables=0,sensor_reads=0,store_writes=0,file_writes=0,ui_writes=0}
 local function widget(kind,parent,w,h)
  local obj={kind=kind,parent_handle=parent,w=w or 0,h=h or 0,x=0,y=0,hide=false,styles={},parts={}}
  function obj:set_pos(x,y) integer(x);integer(y);self.x,self.y=x,y;c.ui_writes=c.ui_writes+1 end
  function obj:set_size(w2,h2) integer(w2);integer(h2);self.w,self.h=w2,h2;c.ui_writes=c.ui_writes+1 end
  function obj:style(s,selector)
   local target=self.styles
   if selector then self.parts[selector]=self.parts[selector] or {};target=self.parts[selector] end
   for k,v in pairs(s) do assert(allowed_style[k],"unsupported style: "..k);target[k]=v end
   c.ui_writes=c.ui_writes+1
  end
  function obj:set_text(t) assert(type(t)=="string" and #t<=1024);self.text=t;c.ui_writes=c.ui_writes+1 end
  function obj:hidden(b) assert(type(b)=="boolean");self.hide=b;c.ui_writes=c.ui_writes+1 end
  function obj:set_value(v) integer(v);assert(v>=self.min and v<=self.max);self.value=v;c.ui_writes=c.ui_writes+1 end
  function obj:delete()
   local kept={}
   for _,wgt in ipairs(c.widgets) do
    if wgt~=self and wgt.parent_handle~=self then kept[#kept+1]=wgt end
   end
   c.widgets=kept;self.deleted=true;c.ui_writes=c.ui_writes+1
  end
  c.widgets[#c.widgets+1]=obj
  return setmetatable(obj,{__index=function(_,k) error("Undocumented widget API: "..k) end})
 end
 local function strict(t,name) return setmetatable(t,{__index=function(_,k) error("Undocumented "..name.." API: "..tostring(k)) end}) end
 local badge={
  ui=strict({label=function(root,t) local w=widget("label",root);w.text=t;return w end,
   box=function(root,w,h) return widget("box",root,w,h) end,
   bar=function(root,lo,hi,v) local w=widget("bar",root);w.min,w.max,w.value=lo,hi,v;return w end},"ui"),
  sys=strict({ms=function() return c.now+c.offset end,random=function(n) return n and 12345%n or (opts.seed or 305419896) end,
   log=function(s) c.logs[#c.logs+1]=s end,heap=function() return 50000 end,
   stats=function() return {lua_used=50000,lua_limit=98304,lua_peak=60000,widgets=#c.widgets,free_heap=90000,uptime_ms=c.now} end,
   version=function() return "mock-2026-09-19" end,gc_step=function() collectgarbage("step",1) end},"sys"),
  sensor=strict({accel=function() c.sensor_reads=c.sensor_reads+1;if c.accel then return table.unpack(c.accel) end;return nil,"not available" end},"sensor"),
  radio=strict({mac=function() return c.mac end,enable=function() c.enables=c.enables+1;return c.radio end,
   disable=function() c.disabled=true end,on_recv=function(f) c.receiver=f end,dropped=function() return c.drop_count end,
   send=function(p) assert(#p>=1 and #p<=44,"radio packet exceeds budget");c.sent[#c.sent+1]={payload=p,at=c.now};return true end},"radio"),
  led=strict({set=function(i,r,g,b) assert(i>=1 and i<=6);integer(r);integer(g);integer(b);assert(math.max(r,g,b)<=255 and math.min(r,g,b)>=0);c.leds[i]={r,g,b} end,
   set_all=function(r,g,b) for i=1,6 do c.leds[i]={r,g,b} end end,
   show=function() c.shows=(c.shows or 0)+1 end,clear=function() c.leds={} end},"led"),
  fs=strict({read=function(path) return c.files[path] end,
   write=function(path,data) c.file_writes=c.file_writes+1;assert(#data<=16384);if c.write_fail then return nil,"full" end;c.files[path]=data;return true end},"fs"),
  store=strict({get_int=function(k,d) local v=c.store[k];return v~=nil and v or d end,
   set_int=function(k,v) c.store_writes=c.store_writes+1;assert(#k<=24);c.store[k]=v end},"store"),
  input={BUTTON={A=1,B=2,HOME=3,DOWN=4,LEFT=5,RIGHT=6,UP=7,AUX1=8,START=9},KIND={PRESSED=1,RELEASED=2},
   is_down=function(b) return c.held[b]==true end}}
 c.env={badge=strict(badge,"badge"),SPELLBOUND_TEST=true,assert=assert,error=error,
  ipairs=ipairs,pairs=pairs,next=next,select=select,tonumber=tonumber,tostring=tostring,type=type,
  math=math,string=string,table=table,utf8=utf8}
 if opts.production then c.env.SPELLBOUND_TEST=nil end
 local base=opts.path or "src"
 local cache={}
 c.env.require=function(name)
  assert(name:match("^[A-Za-z0-9_]+$"))
  if not cache[name] then
  local v=assert(loadfile(base.."/"..name..".lua","t",c.env))()
  cache[name]=v==nil and true or v
 end
 return cache[name]
 end
 c.api=(opts.source and assert(load(opts.source,"standalone","t",c.env)) or assert(loadfile(opts.file or (base.."/main.lua"),"t",c.env)))()
 c.root={}
 c.env.on_enter(c.root)
 if type(c.api)=="function" then c.api=c.api() end
 function c:press(name)
  local b=assert(self.env.badge.input.BUTTON[name]);self.held[b]=true
  self.env.on_button(b,1)
 end
 function c:release(name)
  local b=self.env.badge.input.BUTTON[name];self.held[b]=false;self.env.on_button(b,2)
 end
 function c:tap(name) self:press(name);self:release(name) end
 function c:tick(delta) self.now=self.now+(delta or 20);self.env.on_tick() end
 function c:receive(from,p,rssi) if self.receiver then self.receiver(from,rssi or -45,p) end end
 function c:state() return self.api.state() end
 function c:record(fn,duration)
  self.accel={fn(0)};self:press("A")
  for t=20,duration,20 do self.accel={fn(t/duration)};self:tick(20) end
  self:release("A")
 end
 return c
end
return M
