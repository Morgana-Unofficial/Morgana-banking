local shell = require("shell")
local strs_bank = {
  'echo "f.run(\'b\')" > autorun.lua',
  'wget -f -q https://raw.githubusercontent.com/RollingHog/Morgana-banking/main/b.lua b.lua',
  'wget -f -q https://raw.githubusercontent.com/RollingHog/Morgana-banking/main/download.lua download.lua',
  'wget -f -q https://raw.githubusercontent.com/RollingHog/LiskelOS/master/src/liskel2c.lua init.lua',
  'mkdir lib',
  'wget -f -q https://raw.githubusercontent.com/MightyPirates/OpenComputers/master-MC1.7.10/src/main/resources/assets/opencomputers/loot/openos/lib/serialization.lua lib/serialization.lua',
  'wget -f -q https://raw.githubusercontent.com/RollingHog/Morgana-banking/main/lib/internet.lua lib/internet.lua',
  'wget -f -q https://raw.githubusercontent.com/RollingHog/Morgana-banking/main/lib/event.lua lib/event.lua'
}

local root = string.sub(computer.getBootAddress(), 1, 3)
print("avaliable mounts are: ")
shell.execute('ls -l /mnt')
print("your root is "..root)
print("enter one of the mounts, better not root")
local target = io.read()
target = "/mnt/"..target
print("selected: "..target)

print('loading...')
shell.setWorkingDirectory(target)
for _,v in pairs(strs_bank) do 
  shell.execute(v)
end
print("done")