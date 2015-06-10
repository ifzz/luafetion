local copas = require 'copas'
local socket = require 'socket'
local http = require 'socket.http'
local ltn12 = require 'ltn12'
local json = require 'dkjson'
local log = require 'log'

-- used to save cookies
local cookie_tab = nil
local debug = true

--base_url = "https://httpbin.org",
--args = {
--  endpoint='/',
--  method='GET',
--  params={age=22,name='wer'},
--  -- a post header with content a=123
--  headers = {
--    ["Content-Type"] = "application/x-www-form-urlencoded",
--    ["Content-Length"] = 5
--  },
--  source = ltn12.source.string('a=123'),
--  step = {},
--  proxy = '',
--  redirect = true,
--  }
local function http_request(base_url, args )

    local resp, r = {}, {}
    args.endpoint = args.endpoint or '/'
    args.method = args.method or 'GET'
    local params = ""
    if args.method == "GET" then
        -- prepare query parameters like http://xyz.com?q=23&a=2
        if args.params then
            for i, v in pairs(args.params) do
                params = params .. i .. "=" .. v .. "&"
            end
        end
    end
    -- remove the last '&'
    params = string.sub(params, 1, -2)
    local url = base_url .. args.endpoint 
    if params ~= '' then 
      url = url .. "?" .. params
    end
    if debug then
      print(url, args.method, args.source)
    end
    local client, code, headers, status = http.request{
            url=url, 
            sink=ltn12.sink.table(resp),
            method=args.method,
            headers=args.headers, 
            source=args.source,
            step=args.step,
            proxy=args.proxy, 
            redirect=args.redirect, 
            create=args.create }
    r['code'], r['headers'], r['status'], r['response'] = code, headers, status, resp
    return r
end

local function printtable(t,name,ptab)
  if debug ~= true then return end
	if type(t)~='table' then
		print(t)
		return
	end
	local tab = ptab or ''
	local s = string.format('%s[%s](%s):',tab,name,tostring(t))
	print(s)

	tab = tab..'      '
	for i,v in pairs(t) do
		if type(v)~='table' then
			local s = string.format('%s%s  (%s)%s = %s',tab,i,type(v),type(v)=='string' and '('..#v..')' or '', tostring(v))
			print(s)
		else
			printtable(v,i,tab)
		end
	end
end



local token_class =  '[^%c%s%(%)%<%>%@%,%;%:%\\%"%/%[%]%?%=%{%}]'

local function unquote(t, quoted) 
    local n = string.match(t, "%$(%d+)$")
    if n then n = tonumber(n) end
    if quoted[n] then return quoted[n]
    else return t end
end

local function parse_set_cookie(c, quoted, cookie_table)
    c = c .. ";$last=last;"
    local _, __, n, v, i = string.find(c, "(" .. token_class .. 
        "+)%s*=%s*(.-)%s*;%s*()")
    local cookie = {
        name = n, 
        value = unquote(v, quoted), 
        attributes = {}
    }
    while 1 do
        _, __, n, v, i = string.find(c, "(" .. token_class .. 
            "+)%s*=?%s*(.-)%s*;%s*()", i)
        if not n or n == "$last" then break end
        cookie.attributes[#cookie.attributes+1] = {
            name = n, 
            value = unquote(v, quoted)
        }
    end
    cookie_table[#cookie_table+1] = cookie
end

local function split_set_cookie(s, cookie_table)
    cookie_table = cookie_table or {}
    -- remove quoted strings from cookie list
    local quoted = {}
    s = string.gsub(s, '"(.-)"', function(q)
        quoted[#quoted+1] = q
        return "$" .. #quoted
    end)
    -- add sentinel
    s = s .. ",$last="
    -- split into individual cookies
    i = 1
    while 1 do
        local _, __, cookie, next_token
        _, __, cookie, i, next_token = string.find(s, "(.-)%s*%,%s*()(" .. 
            token_class .. "+)%s*=", i)
        if not next_token then break end
        parse_set_cookie(cookie, quoted, cookie_table)
        if next_token == "$last" then break end
    end
    return cookie_table
end
local function quote(s)
    if string.find(s, "[ %,%;]") then return '"' .. s .. '"'
    else return s end
end

local _empty = {}
local function build_cookies(cookies) 
    s = ""
    for i,v in ipairs(cookies or _empty) do
        if v.name then
            s = s .. v.name
            if v.value and v.value ~= "" then 
                s = s .. '=' .. quote(v.value)
            end
        end
        if v.name and #(v.attributes or _empty) > 0 then s = s .. "; "  end
        for j,u in ipairs(v.attributes or _empty) do
            if u.name then
                s = s .. u.name
                if u.value and u.value ~= "" then
                    s = s .. '=' .. quote(u.value)
                end
            end
            if j < #v.attributes then s = s .. "; "  end
        end
        if i < #cookies then s = s .. ", " end
    end
    return s 
end

local function http_post_ex(url, data)
  data = data or ''
  local resp = http_request("http://webim.feixin.10086.cn/", {
           endpoint=url,
           method = 'POST',
           headers= {
             ['User-Agent']='Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:37.0) Gecko/20100101 Firefox/37.0',
             ['Content-Type']='application/x-www-form-urlencoded; charset=UTF-8',
             ['Cache-Control']='no-cache',
             ['Accept']='*/*',
             ['Connection']='keep-alive',
             ['Content-Length'] = #data,
             ['Cookie'] = build_cookies(cookie_tab),
             ['Host']='webim.feixin.10086.cn',
             ['Referer']='https://webim.feixin.10086.cn/loginform.aspx'
             }, 
          source = ltn12.source.string(data)
          })
  printtable(resp, 'resp')
  if (type(resp.headers) == 'table' and type(resp.headers['set-cookie']) == 'string') then
    cookie_tab = split_set_cookie(resp.headers['set-cookie'])
  end
  return resp
end

local function http_get_ex(url, params)
  local resp = http_request("http://webim.feixin.10086.cn/", {
           endpoint=url,
           method = 'GET',
           headers= {
             ['User-Agent']='Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:37.0) Gecko/20100101 Firefox/37.0',
             ['Accept']='*/*',
             ['Connection']='keep-alive',
             ['Cookie'] = build_cookies(cookie_tab),
             ['Host']='webim.feixin.10086.cn',
             ['Referer']='https://webim.feixin.10086.cn/main.aspx'
             }, 
          params=params,
          })
  printtable(resp, 'resp')
  if (type(resp.headers) == 'table' and type(resp.headers['set-cookie']) == 'string') then
    cookie_tab = split_set_cookie(resp.headers['set-cookie'])
  end
  return resp
end

local function listContact(self)
  for i, v in ipairs(self.contactList) do
    local uid = v.uid
    local ln = v.ln
    if ln == nil or #ln == 0 then
      -- find it in contact info
      for _, info in ipairs(self.contactInfo) do
        if info.DataType == 2 then -- avaliable
          if uid == info.Data.uid then
            ln = info.Data.nn
            if ln == nil or #ln == 0 then ln = info.Data.mn end
            break
          end
        end
      end -- end of find it in contact info loop
    end -- end of ln = nil
    print('['..i..']', uid, ln)
  end
end

local function sendMsg(self, index, msg)
  -- send msg
  local resp = http_post_ex('/WebIM/SendSMS.aspx?Version='..self.version, 
    'Msg=' .. msg .. '&Receivers='.. self.contactList[index].uid .. '&UserName=' .. self.uid .. '&ssid=' .. self.ssid)
  self.version = self.version + 1
  if type(resp.response) == 'table' and type(resp.response[1]) == 'string' then
    local jsonTbl = json.decode(resp.response[1])
    if (tonumber(jsonTbl.rc) == 200) then
      log.i('Send SMS Success')
    else
      log.e('Send SMS Failed with return code ', jsonTbl.rc)
    end
  end
end

local function logout(self)
  local resp = http_post_ex('/WebIM/Logout.aspx?Version='..self.version, 'ssid=' .. self.ssid)
  self.version = self.version + 1
  if type(resp.response) == 'table' and type(resp.response[1]) == 'string' then
    local jsonTbl = json.decode(resp.response[1])
    if (tonumber(jsonTbl.rc) == 200) then
      log.i('Logout Success')
    else
      log.e('Logout Failed with return code ', jsonTbl.rc)
    end
  end
end

local function usage()
  log.i('Usage:')
  log.i('$> lua fetion.lua 136XXXXXXXX true')
  log.i('# "136XXXXXXXX" is your mobile number for login')
  log.i('# "true" is a debug flag to print more info')
end

local function main( arg )
  if #arg < 1 then usage(); os.exit(1) end
  self = {}
  self.version = 1
  self.mob = arg[1]
  if arg[2] == 'true' then
    debug = true
  else
    debug = false
  end
  http_post_ex('/WebIM/GetSmsPwd.aspx', 'uname=' .. self.mob)
  io.stdout:write('Input the password: ')
  local pass = io.stdin:read('*l')
  log.v('login with ... ', pass)
  -- login
  local resp = http_post_ex('/WebIM/Login.aspx', 'AccountType=1&Ccp=&OnlineStatus=400&Pwd=' .. pass .. '&UserName=' .. self.mob)
  
  if type(resp.response) == 'table' and type(resp.response[1]) == 'string' then
    local jsonTbl = json.decode(resp.response[1])
    if (tonumber(jsonTbl.rc) == 200) then
      log.i('Login Success')
    else
      log.e('Login Failed with return code ', jsonTbl.rc)
      os.exit(1)
    end
  end
  if type(resp.headers) == 'table' then
    for k,v in pairs(resp.headers) do
      if k:lower() == 'set-cookie' then
        self.ssid = v:match('webim_sessionid=(.-);')
        log.v('ssid', self.ssid)
        break
      end
    end
  end
  if self.ssid == nil then 
    log.e('SSID is nil')
    os.exit(1)
  end
  -- get personal info
  local resp = http_post_ex('/WebIM/GetPersonalInfo.aspx?Version='..self.version, 'ssid=' .. self.ssid)
  self.version = self.version + 1
  if type(resp.response) == 'table' and type(resp.response[1]) == 'string' then
    local jsonTbl = json.decode(resp.response[1])
    if (tonumber(jsonTbl.rc) == 200) then
      log.i('Get Personal Info Success')
      if type(jsonTbl.rv) == 'table' then
        printtable(jsonTbl.rv, 'Personal Info')
        self.uid = jsonTbl.rv.uid
      end
    else
      log.e('Get Personal Info Failed with return code ', jsonTbl.rc)
      os.exit(1)
    end
  end
  -- get contact list
  local resp = http_get_ex('/WebIM/GetContactList.aspx',{Version=self.version, ssid=self.ssid})
  self.version = self.version + 1
  if type(resp.response) == 'table' and type(resp.response[1]) == 'string' then
    local data = ''
    for _, v in ipairs(resp.response) do data = data .. v end
    local jsonTbl = json.decode(data)
    if (tonumber(jsonTbl.rc) == 200) then
      log.i('Get Contact List Success')
      if type(jsonTbl.rv) == 'table' then
        printtable(jsonTbl.rv, 'Contact List')
        if type(jsonTbl.rv.bds) == 'table' then
          self.contactList = jsonTbl.rv.bds
        end
      end
    else
      log.e('Get Contact List Failed with return code ', jsonTbl.rc)
      os.exit(1)
    end
  end
  -- get connect info
  local resp = http_post_ex('/WebIM/GetConnect.aspx?Version='..self.version, 'ssid=' .. self.ssid)
  self.version = self.version + 1

  if type(resp.response) == 'table' and type(resp.response[1]) == 'string' then
    local data = ''
    for _, v in ipairs(resp.response) do data = data .. v end
    local jsonTbl = json.decode(data)
    if (tonumber(jsonTbl.rc) == 200) then
      log.i('Get Connect Info Success')
      if type(jsonTbl.rv) == 'table' then
        printtable(jsonTbl.rv, 'Connect Info')
        self.contactInfo = jsonTbl.rv
      end
    else
      log.e('Get Connect Info Failed with return code ', jsonTbl.rc)
      os.exit(1)
    end
  end

  copas.addthread(function()
    while true do
      copas.sleep(5) -- 5 second interval
      log.v("send heart beat")
      http_post_ex('/WebIM/GetConnect.aspx?Version='..self.version, 'ssid=' .. self.ssid)
      self.version = self.version + 1
    end
  end)

  copas.addthread(function()
    while true do
      copas.sleep(1)
      print([[
-----------------------------------------------------------------------------
Welcome to use
Now the commands supports:
ls   --> list all your friends. Every friend start with a index like [1] XXX
send --> send the msg to some one, the format will be 'send 1 msg_to_send'
exit --> logout fetion and exit
-----------------------------------------------------------------------------
]])
      io.stdout:write('Input Command :> ')
      local cmd = io.stdin:read('*l')
      if cmd:sub(1,2) == 'ls' then
        listContact(self)
      elseif cmd:sub(1,4) == 'send' then
        local index, msg = cmd:match('send%s+(%d+)%s+(.+)')
        sendMsg(self, tonumber(index), msg)
      elseif cmd:sub(1,4) == 'exit' then
        logout(self)
        os.exit(0)
      end
    end
  end)

  copas.loop()
end
main(arg)