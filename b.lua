-- b for "bank"
local version = '1.0.0'

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local shell = require("shell")
local serialization = require("serialization")
local unicode = require("unicode")

-- aliases 
local prn = component.openprinter
local data = component.data
local disk_drive = component.disk_drive

-- dirs aka namespaces

local root = '/home/banking/'

local dir = {
  clients = root..'clients/',
  vexels = root..'vexels/'
}

-- global variables

local users = {}

local currentUser = nil

-------------------- COMMON --------------------

function pt(ndict) for k,v in pairs(ndict) do print(k,v) end end

function log(text)
  -- os.clock()
  print(string.format("%.3f", computer.uptime()), text)
end

function splitBySymbol(nstr, nchar)
  local res={}
  local t="_"
  local cnt=0
  while (true) do
    t=""
    for i = 1, unicode.len(nstr) do 
      if(unicode.sub(nstr, i,i)==nchar) then
        t = unicode.sub(nstr, 1,i-1)
        nstr = unicode.sub(nstr, i+1)
        break
      end
    end
    if(t=="")then
      break
    end
    res[cnt]=t
    cnt = cnt+1
  end
  res[cnt]=nstr
  return res
end 

function readOneliner(filename, default)
  log('readOneliner '..filename)
  local fn = root..filename
  if(not fs.exists(fn)) then
    writeOneliner(filename, default)
  end
  local file = io.open(fn, "r")
  local res = file:read(40)
  file:close()
  log('readOneliner '..filename..' done')
  return res
end

function writeOneliner(filename, nData)
  local fn = root..filename
  local file = io.open(fn, "w")
  file:write(nData)
  file:close() 
end

function objectExists(dir, filename)
  return fs.exists(dir..filename)
end

function saveObject(dir, filename, object)
  log('saveObject '..filename)
  local fn = dir..filename
  local file = io.open(fn, "w")
  local res = serialization.serialize(object)
  -- res = data.deflate(res)
  file:write(res)
  file:close() 
  log('saveObject '..filename..' done')
end

function loadObject(dir, filename)
  log('loadObject '..filename)
  local fn = dir..filename
  if(not fs.exists(fn)) then
    return nil
  end
  local file = io.open(fn, "r")
  local res = file:read()
  file:close()
  -- res = data.inflate(res)
  res = serialization.unserialize(res)
  log('loadObject '..filename..' done')
  return res
end

function getFloppyPath()
  if (disk_drive.isEmpty()) then
    print('Вставьте диск и нажмите "Продолжить"')
    io.read()
  end
  local floppy_id = disk_drive.media()
  local floppy_path = '/mnt/'..string.sub(floppy_id, 1, 3)..'/'
  return floppy_path, floppy_id
end

function getDate() 
  return os.date()
end

-------------------- VEXELS --------------------

function getNewVexelID() 
  local series = '01'
  local res = readOneliner('vexel.last_id', 1)
  writeOneliner('vexel.last_id', res+1)
  
  res = 'V'..series..string.format("%06d", res)
  return res
end

function newVexel(value)
  local id = getNewVexelID()
  -- profit per day, percent of main value
  local profit = 2.5
  local title = "§1Вексель №"..id..", ".. value .. " кон"
  
  -- printer operation
  prn.setTitle("§r"..title)
  --               123456789012345678901234567890
  prn.writeln('§1§l              Вексель')
  prn.writeln('§1§l        Первого Банка Морганы')
  prn.writeln("§r§8               №"..id)
  prn.writeln("")
  prn.writeln(  '§rВыпущен '..getDate())
  prn.writeln(  '§rНоминал: '..value.." кон")
  prn.writeln(  '§rДоходность: '..tostring(value*profit/100).." кон в день")
  prn.writeln("")
  prn.writeln('§r§oНа предъявителя§r')
  prn.writeln("")
  prn.print()
  
  local vexelObj = {
    id = id,
    owner = nil,
    value = value,
    profit = profit,
    regdate = getDate()
  }
  
  if(objectExists(dir.vexels, id)) then
    -- WHOOPSIE
    print('Vexel '..id..' already exists, abort!')
    return nil
  end
  
  saveVexel(vexelObj)
  
  return vexelObj
end

function saveVexel(vexelObj)
  saveObject(dir.vexels, vexelObj.id, vexelObj)
end

-------------------- USERS --------------------
--it should be more like transaction-based - disk IO is slooow

function getNewUserID() 
  local res = readOneliner('user.last_id', 1)
  writeOneliner('user.last_id', res+1)
  
  res = "U"..string.format("%06d", res)
  return res
end

function newUser(username)
  local user = {
    name = username,
    regdate = getDate(),
    vexels = {}
  }
  
  saveObject(dir.clients, username, user)
  return user
end

function loadUser(username, isForce)
  if(users[username] and not isForce) then
    return users[username]
  end 
  
  local user = loadObject(dir.clients, username)
  if(not user) then
    user = newUser(username)
  end
  users[username] = user
  return user
end

function saveUser(username)
  -- TODO if such user doesn't exist...
  saveObject(dir.clients, username, users[username])
end

function giveVexelTo(username, vexelObj)
  -- TODO if all that exists...
  
  -- reown
  if(vexelObj.owner ~= nil) then
    alienateVexel(vexelObj.owner, vexelObj.id)
  end  
  vexelObj.owner = username
  users[username].vexels[vexelObj.id] = 1
  
  saveUser(username)
end

function alienateVexel(username, vexelID)
    users[username].vexels[vexelID] = nil
    saveUser(username)
end

function makeProfitCountFloppy(user)
  local floppy_path, floppy_id = getFloppyPath()
  -- add autorun.lua
  saveObject(floppy_path, 'operation', {operation = 'profitcount'})
  saveObject(floppy_path, user, users[user])
  shell.execute('label -a '..floppy_id..' profit count for '..user)
end

function applyProfitCountFloppy()
  local floppy_path = getFloppyPath()
  loadObject(floppy_path, 'result')
  -- TODO noting of vexels encountered during check
end

-------------------- MAIN --------------------

function Init() 
  if(not fs.exists(root)) then
    fs.makeDirectory(root)
  end
  if(not fs.exists(dir.vexels)) then
    fs.makeDirectory(dir.vexels)
  end
  if(not fs.exists(dir.clients)) then
    fs.makeDirectory(dir.clients)
  end
end

Init()
-- "предъявлено к снятию процентов"

log('start')
loadUser('Test')
-- pt(currentUser)
local vexel = newVexel(10)
giveVexelTo('Test', vexel)
makeProfitCountFloppy('Test')
log('end')