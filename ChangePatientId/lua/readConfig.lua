local configEnv = {} -- to keep it separate from the global env

local readConfig = {}

function readConfig.readFile()
  local f,err = loadfile("/etc/lua/_config.lua", "t", configEnv)
  if f then
     f() -- run the chunk
     -- now configEnv should contain your data
     return configEnv.config;
  else
     print(err)
  end
end


return readConfig