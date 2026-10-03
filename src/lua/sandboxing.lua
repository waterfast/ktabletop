-- reference: https://luau.org/sandbox/

-- prevent them revived by require()
for _, v in ipairs { "io", "os", "package", "debug" } do
  package.loaded[v] = nil
end

io = nil
package = nil
os = {
  clock = os.clock,
  date = os.date,
  difftime = os.difftime,
  time = os.time,
}
debug = {
  traceback = debug.traceback,
  getinfo = debug.getinfo,
}
loadfile = nil
dofile = nil

string.dump = nil
string.load = nil

-- NOTE: not possible to implement read-only table in standard Lua.

-- disabled because it's used by C++ code
warn = nil

local cl = collectgarbage
collectgarbage = function(opt)
  if opt ~= "count" then return end
  return cl("count")
end
