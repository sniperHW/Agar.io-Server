local battle = require("battle")
local chuck = require("chuck")
local packet = chuck.packet
local log = chuck.log
local M = {}

M.conn2User = {}
M.userID2User = {}

local user = {}
user.__index = user
user.msgHander = {}

local function newUser(conn,userID)
	local o = {}
	o = setmetatable(o,user)
	o.conn = conn
	o.userID = userID
	M.conn2User[conn] = o
	M.userID2User[userID] = o	
	return o
end

function user:onMsg(msg)
	local handler = user.msgHander[msg.cmd]
	if handler then
		xpcall(handler,function (err)
			logger:Log(log.error,string.format("error on call onMsg:%s",err))
		end,self,msg)
	end
end

function user:Send2Client(msg)
	if self.conn then
		local buff = chuck.buffer.New()
		local w = packet.Writer(buff)
		w:WriteTable(msg)		
		self.conn:Send(buff)
	end
end

function user:enterRoom(msg)
	print("user:enterRoom")
end

function M.OnClientMsg(conn,msg)
	print(msg.cmd)
	if msg.cmd == "Login" then
		local user = M.userID2User[msg.userID]
		if not user then
			user = newUser(conn,msg.userID)
		else
			if user.conn ~= nil then
				--同一账号重复登录
				conn:Close()
				return
			else
				user.conn = conn
				M.conn2User[conn] = user
			end
		end
		user:Send2Client(msg)
	else
		local user = M.userID2User[msg.userID]
		if user then
			user:onMsg(msg)
		end
	end
end

function M.OnClientDisconnected(conn)
	local user = M.conn2User[conn]
	if user then
		M.conn2User[conn] = nil
		M.userID2User[user.userID] = nil
	end
end

return M