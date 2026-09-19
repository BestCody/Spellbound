-- Spellbound original source, MIT license.
local floor=math.floor
local function checksum(s)
  local v=0
  for i=1,#s do v=(v+s:byte(i)*i)%65536 end
  return string.char(floor(v/256),v%256)
end
local function encode_models(model)
  local parts={"SBG1"}
  for i=1,3 do
    parts[#parts+1]=string.char(#model[i])
    for _,s in ipairs(model[i]) do parts[#parts+1]=s end
  end
  local s=table.concat(parts);return s..checksum(s)
end
local function decode_models(s)
  if type(s)~="string" or #s<9 or #s>441 or s:sub(1,4)~="SBG1" then return nil end
  if checksum(s:sub(1,-3))~=s:sub(-2) then return nil end
  local result,pos={{},{},{}},5
  for i=1,3 do
    local n=s:byte(pos);pos=pos+1
    if not n or (n~=0 and n~=3) then return nil end
    for j=1,n do
      local t=s:sub(pos,pos+47); if #t~=48 then return nil end
      result[i][j]=t;pos=pos+48
    end
  end
  if pos~=#s-1 then return nil end
  return result
end

return {encode=encode_models,decode=decode_models}
