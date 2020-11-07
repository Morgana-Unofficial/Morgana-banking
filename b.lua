-- b for "bank"
local version = '2.0.14'

local require_raw, require_
-- local component
    -- , computer
    -- , unicode
    -- , fs = {}

local isLiskelOS = false
if(_osname == 'Liskel OS') then
  isLiskelOS = true
end

if(isLiskelOS) then
  require_ = function(s) return f.run('/lib/'..s) end
  print = console.print
  f.makeDirectory = f.mkdir
  f.exists = component.filesystem.exists
  fs = f
  os.exit = function () 
    beep(500, 0.08)
    beep(400, 0.16)
    computer.shutdown()
  end
else 
  -- OpenOS
  read = io.read
  component = require("component")
  computer = require("computer")
  unicode = require("unicode")
  fs = require("filesystem")
  require_ = require
end

local event = require_("event")
local serialization = require_("serialization")
local inet = require_('internet')

-- component aliases 
local prn = false
pcall(function () prn = component.openprinter end)
local data = false
pcall(function () data = component.data end)
local disk_drive = false
pcall(function () disk_drive = component.disk_drive end)

if(not prn) then
  print("Нет принтера")
end

if(not data) then
  print("Нет карты данных")
end

if(not disk_drive) then
  print("Нет дисковода")
end

local inet_aval = false
pcall(function () inet_aval = component.internet end)
if(not inet_aval) then
  print("Нет интернет-карты")
end

-- dirs aka namespaces

local root = '/home/Morgana-banking/banking/'

local dir = {
  clients = root..'clients/'
  , accounts = root..'accounts/'
  , deposits = root..'deposits/'
  , credits = root..'credits/'
  , vexels = root..'vexels/'
}

-- global variables

local users = {}

local current_user = nil

local operator_nick = nil
-------------------- COMMON --------------------

function beep(freq, length)
  computer.beep(freq, length)
end

function pause() 
  event.pull(99, "key_down")
end

function readLiskelStr()
  local w, h = g.getResolution()
  -- console init
  local console_header = " "
  local blinkon = true
  local hist = console.history
  local inp = console.input
  print = console.print
  console.lineout(console_header, h)
  inp.SetPrintOffset(#console_header + 1)
  -- console loop start
  while true do
    local evt = table.pack(computer.pullSignal(0.4))
    if evt[1] == 'key_down' then
      -- command
      if evt[4] == 28 then -- enter key
        local t = tostring(inp.GetString())
        hist.AddInp(t) -- add input to history
        inp.Clear() 
        return t
      elseif evt[4] == 14 then -- backspace
        if inp.col > 1 then
          inp.MovePos(-1)
          inp.DelChar()
          hist.ResetRecall()
        end
      elseif evt[4] == 46 and evt[3] == 3 then -- Ctrl+C
        return nil
      -- elseif evt[4] == 203 then -- left key
        -- inp.MovePos(-1)
      -- elseif evt[4] == 205 then --  right key
        -- inp.MovePos(1)
      -- elseif evt[4] == 199 then -- home
        -- inp.MovePos(-99999)
      -- elseif evt[4] == 207 then -- end
        -- inp.MovePos(99999)
      elseif evt[4] ~= 0 then -- printable keys
        local char = unicode.char(evt[3])
        inp.Insert(char)
        inp.MovePos(1)
      end
    end
  end
end

if(isLiskelOS) then
  read = readLiskelStr
end

function pt(ndict) for k,v in pairs(ndict) do print(k,v) end end

function trunc(float)
  return math.ceil(float*100)/100
end

function listKeys(ndict) 
  local res = ''
  for k,_ in pairs(ndict) do 
    res = res..' '..k 
  end 
  return res
end

function log(text)
  -- os.clock()
  -- print(string.format("%.3f", computer.uptime()).." "..text)
end

function splitBySymbol(nstr, nchar)
  local res={}
  local t="_"
  local cnt=1
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
  local file = fs_open(fn, "r")
  local res = fs_read(file)
  fs_close(file)
  log('readOneliner '..filename..' done')
  return res
end

function writeOneliner(filename, nData)
  log('writeOneliner '..filename)
  local fn = root..filename
  local file = fs_open(fn, "w")
  fs_write(file, nData)
  fs_close(file) 
end

function getFloppyPath()
  if (disk_drive.isEmpty()) then
    print('Вставьте диск и нажмите "Продолжить"')
    pause()
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
  print(prompt..": ")
  local t = read()
  if (not t) then
    error("readStr interruption")
  end
  if (#t~=0) then
    return t
  else
    return default
  end
end

function getNickFromMotion()
  print("Пожалуйста, совершите любое движение или прыжок.")
  local _, _, nx, ny, nz, nNick = event.pull(60, "motion")
  print("Считано: "..nNick)
  return nNick
end

function getNickFromInput(nprompt)
  if(nprompt ~= nil) then
    print(nprompt)
  else
    print("Нажмите \"Ввод\" для биометрической идентификации")
  end
  local tNick = nil
  _, _, _, _, tNick = event.pull("key_up")
  print("Считано: "..tNick)
  return tNick
end

function getOperatorNick()
  if(not operator_nick) then
    operator_nick = getNickFromInput("Нажмите \"Ввод\", чтобы подтвердить операцию")
  end
  return operator_nick
end

--------------------  LISKELOS FILE IO --------------------

function fs_open (fn, mode)
  if(isLiskelOS) then
    return component.filesystem.open(fn, mode)
  else
    return io.open(fn, mode)
  end
end

function fs_read(fn)
  if(isLiskelOS) then
    return component.filesystem.read(fn, math.huge)
  else
    return fn:read()
  end
end

function fs_write(fn, data)
  data = tostring(data)
  if(isLiskelOS) then
    return component.filesystem.write(fn, data)
  else
    return fn:write(data)
  end
end

function fs_close(fn)
  if(isLiskelOS) then
    component.filesystem.close(fn)
  else
    fn:close()
  end
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
    if(c2 == nil or c2 == false) then
      res = nil
    else
      cq = c1..c2
      res = dicts[nDictName][cq]
    end
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
  local file = fs_open(fn, "w")
  local res = serialization.serialize(object)
  -- res = data.deflate(res)
  fs_write(file, res)
  fs_close(file) 
  log('saveObject '..filename..' done')
end

function loadObject(dir, filename)
  log('loadObject '..filename)
  local fn = dir..filename
  if(not fs.exists(fn)) then
    return nil
  end
  local file = fs_open(fn, "r")
  local res = fs_read(file)
  fs_close(file)
  -- res = data.inflate(res)
  res = serialization.unserialize(res)
  log('loadObject '..filename..' done')
  return res
end

-------------------- ____ --------------------

function printFooter(regdate, operator, fill_up_to)
  --remember: 20 lines
  for i = 1, (fill_up_to-4) do 
    prn.writeln("")
  end
  prn.writeln('Зарегистрирован:')
  prn.writeln("§r§o"..regdate)
  prn.writeln('Ответственный оператор:')
  prn.writeln("§r§o"..operator)
end

function do_print()
  local fail = true
  while fail do
    local paper = prn.getPaperLevel()
    local color_ink = prn.getColorInkLevel() 
    local black_ink = prn.getBlackInkLevel()
    
    fail = false
  
    if(paper == 0 or paper == false) then
      print("Не могу печатать: кончилась бумага")
      fail = true
      pause()
    end
    
    if(color_ink == 0 or color_ink == false) then
      print("Не могу печатать: нет цветных чернил")
      fail = true
      pause()
    end
    
    if(black_ink == 0 or black_ink == false) then
      print("Не могу печатать: нет чёрных чернил")
      fail = true
      pause()
    end
    
  end
  
  prn.print()
end

-------------------- USERS --------------------
--it should be more like transaction-based - disk IO is slooow

function newUser(username)
  local user
  if(not username) then
    local t = readStr("Имя пользователя")
    user = newUserRaw(t)
  else
    user = newUserRaw(username)
  end
  addAccountToUser(user, consts.acc_types.debit, consts.currency_types.main)
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
  
  users[username] = user
  
  saveObject(dir.clients, username, user)
  return user
end

function loadUser(username, isForce)
  --isForce for forced update
  if(users[username] and not isForce) then
    return users[username]
  end 
  
  local user = loadObject(dir.clients, username)
  if(not user) then
    print("Пользователь не найден в базе! Создание нового...")
    user = newUser(username)
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
  prn.writeln("§r§l            #"..userObj.id)
  prn.writeln("")
  prn.writeln('Настоящим заверяется, что')
  prn.writeln("§r§o"..userObj.name)
  prn.writeln("является уважаемым клиентом")
  prn.writeln("Первого Банка Шеола.")
  prn.writeln("")
  prn.writeln("Номера связанных счетов:")
  prn.writeln("§r§o"..listKeys(userObj.accounts))
  printFooter(userObj.regdate, userObj.operator, 10)
  do_print()
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
  shell.setAlias(floppy_id, ' profit count for '..user)
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

-- тип банковского счёта
createOrderedDict('acc_types', {
  ['Д']={'дебетовый', "debit"},
  ['К']={'кредитный', "credit"},
  ['В']={'вклад', "deposit"},
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

-------------------- DEPOSITS --------------------
createOrderedDict('deposit_plans', {
  ["30"] = "30% ежемесячно, 30 дней",
})

function newDeposit()
  current_user = getNickFromMotion()
  loadUser(current_user)
  local deposit_plan = readFromDict('deposit_plans', "Пожалуйста, выберите вклад", '30')
  local deposit_size = tonumber(readStr("Введите сумму вклада", "1"))
  local deposit = newDepositRaw(current_user, deposit_plan, consts.currency_types.main, deposit_size)
  printDeposit(deposit)
  print("Вклад внесён")
end

function newDepositRaw(owner, deposit_plan, currency_type, currency_amount)
  local id = getNewDepositID(currency_type)
  
  local profit_period, profit_size, deposit_length
  profit_size, deposit_length, t = table.unpack(splitBySymbol(deposit_plan, ","))
  
  deposit_length = tonumber(string.sub(deposit_length, 1, 4))
  
  profit_size, profit_period = table.unpack(splitBySymbol(profit_size, "%"))
  profit_size = tonumber(profit_size)
  
  -- profit per day, percent of main value
  local profit = ''
  
  if(profit_period == " ежемесячно") then
    profit = trunc(profit_size/30)
  elseif(profit_period == " ежедневно") then
    profit = profit_size
  end
  
  local obj = {
    id = id,
    owner = owner,
    profit = profit,
    length = deposit_length, 
    currency_type = currency_type, 
    amount = currency_amount, 
    regdate = getDate(),
    operator = getOperatorNick(),
    cash_dates = {}    
  }
  
  -- FIXME add money accounting!
  saveDeposit(obj)
  
  return obj
end

function printDeposit(obj)
  -- printer operation
  local title = "§1Вклад #"..obj.id..", на ".. obj.length .. " дней"
  prn.setTitle("§r"..title)
  --               123456789012345678901234567890
  prn.writeln('§1§lВклад')
  prn.writeln("§r§l#"..obj.id)
  prn.writeln('§1§lПервый Банк Шеола')
  prn.writeln("")
  prn.writeln(  'Владелец: '..obj.owner)
  prn.writeln(  '§rСумма: '..obj.amount.." кон")
  -- prn.writeln(  '§rПроцент: '..obj.profit.."% в день")
  prn.writeln(  '§rКонечная сумма: '..tostring(obj.amount+obj.amount*obj.profit/100*obj.length).." кон")
  prn.writeln(  '§rСрок: '..obj.length.." дней")
  printFooter(obj.regdate, obj.operator, 12)
  do_print()
end

function getNewDepositID(ncurrency_type) 
  local res = readOneliner('deposit.last_id', 1)
  writeOneliner('deposit.last_id', res+1)
  
  res = 'D'..string.format("%02d", ncurrency_type)..string.format("%05d", res)
  return res
end

function saveDeposit(obj)
  saveObject(dir.deposits, obj.id, obj)
end
-------------------- CREDITS --------------------


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
  prn.writeln('§1§l        Первый Банк Шеола')
  prn.writeln("§r§l               #"..id)
  prn.writeln("")
  prn.writeln(  '§rВыпущен '..getDate())
  prn.writeln(  '§rНоминал: '..value.." кон")
  prn.writeln(  '§rДоходность: '..tostring(value*profit/100).." кон в день")
  prn.writeln("")
  prn.writeln('§r§oНа предъявителя§r')
  prn.writeln("")
  do_print()
  
  local vexelObj = {
    id = id,
    value = value,
    profit = profit,
    regdate = getDate(),
    cash_dates = {}    
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

-------------------- SELF-UPDATE --------------------

function update_from_internet()

  if(not inet_aval) then
    print("Нет интернет-карты, обновление невозможно")
    return
  end

  local url = "https://raw.githubusercontent.com/RollingHog/Morgana-banking/main/b.lua"

  -- it may be liskelOS
  local dest_file = '/b.lua'
  
  if(not component.filesystem.exists(dest_file)) then
    -- definetely NOT liskelOS
    dest_file = os.getenv("PWD")..dest_file
  end
  
  print('updating: '..dest_file)
  
  if(inet == nil) then
    print('Недоступна интернет-карта')
    return false
  end

  local FILE = fs_open(dest_file, "w")
  fs_close(FILE)
  
  local result, response = pcall(inet.request, url)
  if result then
    local result, reason = pcall(function()
      for chunk in response do
        FILE = fs_open(dest_file, "a")
        fs_write(FILE, chunk)
        fs_close(FILE)
      end
    end)
    
    if not result then
      print("HTTP request failed: " .. reason .. "\n")
      return false
    end
    
    print("Обновление выполнено")
    fs_close(FILE)
    
    if(readPlusMinus("Перезагрузиться?")) then
      computer.shutdown(true)
    end

  else -- no result
    print("HTTP request failed: " .. response .. "\n")
    return false
  end
end

-------------------- _ --------------------
createOrderedDict('prog_options', {
  ["-"] = "Выход"
  , ["П"] = "Регистрация пользователя"
  , ["+"] = "Загрузить обновления для программы"
  -- , ["С+"] = "Внести деньги на счёт"
  , ["В"] = "Открыть вклад"
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

  beep(500, 0.08)
  beep(800, 0.16)
  -- FIXME clear it one way or other!
  -- term.clear()
  print('================================================')
  print('АРМ "Банк", вер.'..version)

  local free_mem = tostring( trunc(computer.freeMemory()/computer.totalMemory()*100) )
  print("Free mem : "..free_mem.."%")
  local free_disk = (component.filesystem.spaceTotal()-component.filesystem.spaceUsed())
  free_disk = free_disk / component.filesystem.spaceTotal()
  free_disk = tostring( trunc(free_disk*100) )
  print("Free disk: "..free_disk.."%")
  print("LiskelOS: "..tostring(isLiskelOS))
  
  if (tonumber(free_disk) < 5) then
    print("На диске слишком мало свободного места")
    print('Очистите диск')
    pause()
    os.exit()
  end
end

function showHelp() 
  pt(dicts.ordered['prog_options'])
end

function mainCycle() 
  while true do
    print('================================================')
    _, operator_nick, cmdkey = readFromDict('prog_options', "Выберите режим")
    if(cmdkey=="-" or cmdkey=="/") then
      os.exit()
    elseif(cmdkey=="П") then
      newUser() 
    elseif(cmdkey=="В") then
      newDeposit() 
    elseif(cmdkey=="+") then
      update_from_internet() 
    else
      showHelp()
    end
    operator_nick = nil
    current_user = nil
  end
end

-- "предъявлено к снятию процентов"
Init()

--[[
]]--
while(true) do
  local _, res = pcall(mainCycle)
  if(type(res)~="string") then
    os.exit()
  end  
  --flushing openprinter buffer just in case
  prn.clear()
end


--[[
loadUser('Test')
local vexel = newVexel(10)

-- giveVexelTo('Test', vexel)
-- makeProfitCountFloppy('Test')
]]--