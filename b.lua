-- b for "bank"
local version = '1.1.0'

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local shell = require("shell")
local term = require("term")
local event = require("event")
local serialization = require("serialization")
local unicode = require("unicode")

-- component aliases 
local prn = component.openprinter
local data = component.data
local disk_drive = component.disk_drive

if(not prn) then
  print("Нет принтера")
end

if(not data) then
  print("Нет карты данных")
end

if(not disk_drive) then
  print("Нет дисковода")
end

-- dirs aka namespaces

local root = '/home/Morgana-banking/banking/'

local dir = {
  clients = root..'clients/'
  , accounts = root..'accounts/'
  , debets = root..'debets/'
  , credits = root..'credits/'
  , vexels = root..'vexels/'
}

-- global variables

local users = {}

local current_user = nil

local operator_nick = nil
-------------------- COMMON --------------------

function pt(ndict) for k,v in pairs(ndict) do print(k,v) end end

function listKeys(ndict) 
  local res = ''
  for k,_ in pairs(ndict) do 
    res = res..' '..k 
  end 
  return res
end

function log(text)
  -- os.clock()
  -- print(string.format("%.3f", computer.uptime()), text)
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

function doScan()
  while (true) do
    scan_title, scan_text = prn.scan()
    if (scan_title) then
      return scan_title, scan_text
    else
      print('Положите лист в сканер и нажмите "Ввод"')
    end
  end
end

-------------------- INPUT --------------------

function readKey()
  local specCode, code, playerName
  while true do
    if code == nil
      or code == 15 and specCode == 9 
      or code == 42 and specCode == 0
      or code == 56 and specCode == 0
      or code == 58 and specCode == 0
    then
      _, _, specCode, code, playerName = event.pull(15, "key_down")
    elseif code == 28 and specCode == 13 then
      return false, playerName
    elseif code == 46 and specCode == 3 then
      error("readKey interruption")
    else
      break
    end
  end
  -- print(specCode, code)
  local c = unicode.char(specCode) 
  print(c)
  return c, playerName
end

function readPlusMinus(prompt)
  print(prompt.." (+/-)")
  local res = readKey()
  if(res=='+' or #res==0) then
    return true
  else
    return false
  end
end

function readStr(prompt, default)
  io.write(prompt..": ")
  local t = io.read()
  if (not t) then
    error("readStr interruption")
  end
  if (#t~=0) then
    return t
  else
    return default
  end
end

function getNickFromInput(nprompt)
  if(nprompt ~= nil) then
    print(nprompt)
  else
    print("Нажмите \"Ввод\" для биометрической идентификации")
  end
  local tNick = nil
  _, _, _, _, tNick = event.pull("key_up")
  return tNick
end

function getOperatorNick()
  operator_nick = getNickFromInput("Нажмите \"Ввод\", чтобы подтвердить операцию")
  print("Биометрия получена")
  return operator_nick
end

-------------------- ORDERED DICTS --------------------

local dicts = {}
local consts = {}
dicts.ordered={}

function createOrderedDict(nName, nDict)  
  dicts[nName] = nDict
  consts[nName] = {}
  local t
  for k, v in pairs(dicts[nName]) do 
    if(type(v) == "table") then
      dicts[nName][k] = v[1]
      consts[nName][v[2]] = k
    else -- string
      dicts[nName][k] = v
    end
  end
  -- pt(dicts[nName])
  -- pt(consts[nName])

  local tt={}
  for k in pairs(dicts[nName]) do table.insert(tt, k) end
  table.sort(tt)
  dicts.ordered[nName] = tt
end

function readFromDict(nDictName, prompt, default)
  local cq
  print("\n"..prompt..": ")
  for _, k in pairs(dicts.ordered[nDictName]) do 
    print(k..": "..dicts[nDictName][k]) 
  end
  if(default ~= nil) then
    print("По умолч.: "..dicts[nDictName][default])
  end
  print(">")
  local c1, tNick = readKey()
  if(not c1) then
    print(dicts[nDictName][default])
    return dicts[nDictName][default], tNick, default
  end
  
  c1 = unicode.upper(c1)
  local res
  if(dicts[nDictName][c1]==nil)then
    local c2, _ = readKey()
    cq = c1..c2
    res = dicts[nDictName][cq]
  else
    res = dicts[nDictName][c1]
    cq = c1
  end
  if(res == nil) then
    print("Ключ не найден, ещё раз!")
    return readFromDict(nDictName, prompt), tNick
  end
  print(res.."\n---------")
  return res, tNick, cq
end

-------------------- OBJECTS OPERATION --------------------

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

-------------------- VEXELS --------------------

function getNewVexelID() 
  local series = '01'
  local res = readOneliner('vexel.last_id', 1)
  writeOneliner('vexel.last_id', res+1)
  
  res = 'V'..series..string.format("%05d", res)
  return res
end

function newVexel(value)
  local id = getNewVexelID()
  -- profit per day, percent of main value
  local profit = 2.5

  -- printer operation
  local title = "§1Вексель #"..id..", ".. value .. " кон"
  prn.setTitle("§r"..title)
  --               123456789012345678901234567890
  prn.writeln('§1§l              Вексель')
  prn.writeln('§1§l        Первого Банка Морганы')
  prn.writeln("§r§8               #"..id)
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
    value = value,
    profit = profit,
    regdate = getDate(),
    cashed = {}    
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

function newUser()
  local user = newUserRaw(readStr("Имя пользователя"))
  addAccountToUser(user, consts.acc_types.deposit, consts.currency_types.main)
  printUser(user)
  print("Пользователь создан, удостоверение отпечатано!")


  saveObject(dir.clients, user.name, user)
end

function newUserRaw(username)
  local user = {
    id = getNewUserID(), 
    name = username,
    regdate = getDate(),
    operator = getOperatorNick(),
    
    accounts = {},
    deposits = {},
    credits = {},

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
    user = newUserRaw(username)
  end
  users[username] = user
  return user
end

function saveUser(username)
  -- TODO if such user doesn't exist...
  saveObject(dir.clients, username, users[username])
end

function getNewUserID() 
  local res = readOneliner('user.last_id', 1)
  writeOneliner('user.last_id', res+1)
  
  res = "U"..string.format("%05d", res)
  return res
end

function printUser(userObj)
  -- printer operation
  local title = "§1Удостоверение клиента #"..userObj.id
  prn.setTitle("§r"..title)
  --               123456789012345678901234567890
  prn.writeln('§1§l       Удостоверение клиента')
  prn.writeln("§r§8               #"..userObj.id)
  prn.writeln("")
  prn.writeln('Настоящим заверяется, что')
  prn.writeln("§r§o"..userObj.name)
  prn.writeln("является уважаемым клиентом")
  prn.writeln("Первого Банка Шеола.")
  prn.writeln("")
  prn.writeln("Номера связанных счетов:")
  prn.writeln("§r§o"..listKeys(userObj.accounts))
  prn.writeln("")
  prn.writeln("")
  prn.writeln("")
  prn.writeln("")
  prn.writeln("")
  prn.writeln("")
  prn.writeln('Зарегистрирован:')
  prn.writeln("§r§o"..userObj.regdate)
  prn.writeln('Ответственный оператор:')
  prn.writeln("§r§o"..userObj.operator)
  prn.print()
end

function addAccountToUser(userObj, acc_type, currency_type)
  userObj.accounts[ newBankAccount(acc_type, consts.owner_types.user, userObj.id, currency_type).id ] = 1
  print("Аккаунт добавлен")
  return userObj
end

--[[

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
  log('shell.execute')
  shell.execute('label -a '..floppy_id..' profit count for '..user)
  log('shell.execute end')
end

-- floppy has a default program, 
function applyProfitCountFloppy()
  local floppy_path, _ = getFloppyPath()
  loadObject(floppy_path, 'result')
  -- TODO noting of vexels encountered during check
end

]]--

-------------------- ACCOUNT --------------------
createOrderedDict("owner_types", {
  ['Г']={'государство', 'government'},
  ['Ф']={'физлицо', 'user'},
  ['К']={'компания', 'company'}
})

createOrderedDict('acc_types', {
  ['Д']={'дебет', "deposit"},
  ['К']={'кредит', "credit"},
  ['Э']={'эскроу', "escrow"}
})


createOrderedDict('currency_types', {
  ['1']={'главная',"main"},
  ['2']={'свободная', "free"}
})

function newBankAccount(nacc_type, nowner_type, nowner_id, ncurrency_type)
  print("Регистрация нового банковского аккаунта...")
  pcall(function() 
    print(nacc_type.." "..nowner_type.." "..nowner_id.." "..ncurrency_type)
  end)
 
  local accountObj = {      
    id = "",
    acc_type = nacc_type,
    owner_type = nowner_type,
    owner_id = nowner_id,
    currency_type = ncurrency_type,
    currency_amount = 0,
    registrator_id = operator_nick,
  }
  
  if(nacc_type == nil) then
    accountObj.acc_type = readFromDict('acc_types', "Тип аккаунта", 'Д')
  end
  if(nowner_type == nil) then
    accountObj.owner_type = readFromDict('acc_owner_types', "Тип владельца аккаунта", "Ф")
  end
  if(nowner_id == nil) then
    accountObj.owner_id = readStr("ID владельца счёта", 0)
  end
  if(ncurrency_type == nil) then
    accountObj.currency_type = readFromDict('currency_types', "Тип валюты", "1")
  end

  accountObj.id = getNewAccountID(nacc_type, nowner_type, ncurrency_type)

  saveObject(dir.accounts, accountObj.id, accountObj)

  return accountObj
end

function getNewAccountID(nacc_type, nowner_type, ncurrency_type) 
  local res = readOneliner('account.last_id', 1)
  writeOneliner('account.last_id', res+1)
  
  res = "A"..nacc_type..nowner_type..ncurrency_type..string.format("%05d", res)
  return res
end
-------------------- CREDITS --------------------
-------------------- DEPOSITS --------------------
-------------------- _ --------------------
createOrderedDict('prog_options', {
  ["-"] = "Выход"
  , ["П"] = "Регистрация пользователя"
  -- , ["Э"] = "Эмитировать (отпечатать) вексели Банка"
  -- , ["%s"] = "Сохранить на дискету"
})

-------------------- MAIN --------------------

function Init() 

  if(not fs.exists(root)) then
    fs.makeDirectory(root)
  end

  for k,v in pairs(dir) do 
    if(not fs.exists(v)) then
      fs.makeDirectory(v)
    end
  end

  -- term.clear()
end

function showHelp() 
  pt(dicts.ordered['prog_options'])
end

function mainCycle() 
  while true do
    _, operator_nick, cmdkey = readFromDict('prog_options', "Выберите режим")
    if(cmdkey=="-" or cmdkey=="/") then
      os.exit()
    elseif(cmdkey=="П") then
      newUser() 
    else
      showHelp()
    end
  end
end

-- "предъявлено к снятию процентов"
Init()
mainCycle() 

--[[
while(true) do
  local _, res = pcall(mainCycle)
  if(type(res)~="string") then
    os.exit()
  end  
  print(res)
end
]]--

--[[
loadUser('Test')
local vexel = newVexel(10)

-- giveVexelTo('Test', vexel)
-- makeProfitCountFloppy('Test')
]]--