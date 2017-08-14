local chuck = require("chuck")
local packet = chuck.packet
local config = require("config")
local battleuser = require("battleuser")
local M = {}
M.battles = {}
M.userID2BattleUser = {}
M.battleIDCounter = 1

local battle = {}
battle.__index = battle

function battle.new()
	local o = {}
	o = setmetatable(o,battle)
	o.users = {}
	o.id = M.battleIDCounter
	o.tickCount = 0
	o.gameOverTick = 10*60*1000  --游戏时间10分钟
	o.lastSysTick = chuck.time.systick() 
	o.mapBorder = {}
	o.mapBorder.bottomLeft = {x = 0, y = 0}
	o.mapBorder.topRight = {x = config.mapWidth,y = config.mapWidth}
	o.ballIDCounter = 1
	M.battleIDCounter = M.battleIDCounter + 1
	return o
end

function battle:GetBallID()
	local id = self.ballIDCounter
	self.ballIDCounter = self.ballIDCounter + 1
	return id
end

function battle:Broadcast(msg,except)
	for k,v in pairs(self.users) do
		if v ~= except then
			v:Send2Client(msg)
		end
	end
end

function battle:GameOver()
	if self.timer then
		self.timer:UnRegister()
		self.timer = nil
	end
	self:Broadcast({cmd="GameOver"})
	for k,v in pairs(self.users) do
		if v.player then
			v.player.battleUser = nil
		end
		M.userID2BattleUser[v.userID] = nil
	end
	self.users = {}
end

function battle:Update()
	local nowSysTick = chuck.time.systick()
	local elapse = nowSysTick - self.lastSysTick
	self.lastSysTick = nowSysTick
	self.tickCount = self.tickCount + elapse

	if self.tickCount >= self.gameOverTick then
		--游戏结束
		self:GameOver()	
		M.battles[self.id] = nil
	else
		for k,v in pairs(self.users) do
			v:Update(elapse)
		end
	end
end

function battle:Enter(battleUser)
	if not battleUser.battle then
		print("first enter")
		self.users[battleUser.userID] = battleUser
		battleUser.battle = self
	else
		print("reenter",#battleUser.balls)
	end
	local elapse = chuck.time.systick() - self.lastSysTick
	battleUser:Send2Client({cmd="ServerTick",serverTick = self.tickCount + elapse})
	local balls = {}
	for k,v in pairs(self.users) do
		v:PackBallsOnBeginSee(balls)
	end
	
	if #balls > 0 then
		battleUser:Send2Client({cmd = "BeginSee",timestamp = self.tickCount,balls = balls})
	end

	if #battleUser.balls == 0 then
		--创建玩家的球
		battleUser:Relive()
	end

end

--获得一个可用房间，如果没有就创建一个并返回
function M.getFreeRoom()
	local room
	for k,v in pairs(M.battles) do
		room = v
		break
	end

	if not room then
		room = battle.new()
		room.tickInterval = 50
		room.timer = event_loop:AddTimer(room.tickInterval,function ()
			room:Update()
		end)
	end

	return room
end

function M.EnterRoom(player)
	local userID = player.userID
	print("userID",userID)
	local battleUser = M.userID2BattleUser[userID]
	local room
	if battleUser then
		battleUser.player = player
		player.battleUser = battleUser
		room = battleUser.battle
	else
		print("new battleuser")
		battleUser = battleuser.new(player)
		M.userID2BattleUser[userID] = battleUser 
		room = M.getFreeRoom()
	end
	room:Enter(battleUser)
end

return M