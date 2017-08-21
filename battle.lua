local chuck = require("chuck")
local packet = chuck.packet
local config = require("config")
local battleuser = require("battleuser")
local star = require("star")
local collision = require("collision")
local ai = require("ai")
local ball = require("ball")
local objtype = require("objtype")
local M = {}
M.battles = {}
M.userID2BattleUser = {}
M.battleIDCounter = 1

local thornMgr = {}
thornMgr.__index = thornMgr

function thornMgr.new(battle)
	local o = {}
	o = setmetatable(o,thornMgr)
	o.battle = battle
	for i = 0,config.thornCount do
		local score = math.random(config.minThornScore,config.maxThornScore)
		local r = math.ceil(config.Score2R(score))
		local pos = {x = math.random(r , config.mapWidth - r) , y = math.random(r , config.mapWidth - r)}
		local thorn = ball.new(battle:GetBallID(),battle.dummyUser,objtype.thorn,pos,score,config.thornColorID)
		battle.beginsee = battle.beginsee or {}
		thorn:PackOnBeginSee(battle.beginsee)
	end
	return o
end

function thornMgr:OnThornDead()
	local score = math.random(config.minThornScore,config.maxThornScore)
	local r = math.ceil(config.Score2R(score))
	local pos = {x = math.random(r , config.mapWidth - r) , y = math.random(r , config.mapWidth - r)}
	local thorn = ball.new(self.battle:GetBallID(),self.battle.dummyUser,objtype.thorn,pos,score,config.thornColorID)
	self.battle.beginsee = self.battle.beginsee or {}
	thorn:PackOnBeginSee(self.battle.beginsee)	
end

local battle = {}
battle.__index = battle
battle.__gc = function ()
	print("battle gc")
end

function battle.new()
	local o = {}
	o = setmetatable(o,battle)
	o.users = {}
	o.id = M.battleIDCounter
	o.tickCount = 0
	o.gameOverTick = config.gameTime * 1000
	o.lastSysTick = chuck.time.systick() 
	o.mapBorder = {}
	o.mapBorder.bottomLeft = {x = 0, y = 0}
	o.mapBorder.topRight = {x = config.mapWidth,y = config.mapWidth}
	o.ballIDCounter = 1
	o.colMgr = collision.new(o)
	o.starMgr = star.newMgr(o)
	o.dummyUser = battleuser.new(nil,0)
	o.dummyUser.battle = o
	o.AiMgr = ai.new(o,20)
	o.thornMgr = thornMgr.new(o)
	o.updateCount = 0
	o.lastSyncBallUpdate = 0	
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
	self:Broadcast({cmd="GameOver" , timestamp=self.tickCount})
	for k,v in pairs(self.users) do
		if v.player then
			v.player.battleUser = nil
			v.player = nil
		end
		v.balls = nil
		M.userID2BattleUser[v.userID] = nil
	end

	self.dummyUser.balls = nil
	self.dummyUser = nil
	self.users = {}

	self.colMgr = nil
	self.starMgr = nil
	self.AiMgr = nil
	self.thornMgr = nil

end

function battle:Update()
	self.updateCount = self.updateCount + 1
	local nowSysTick = chuck.time.systick()
	local elapse = nowSysTick - self.lastSysTick
	self.lastSysTick = nowSysTick
	self.tickCount = self.tickCount + elapse

	local needSyncBallUpdate
	local syncElapse

	if self.updateCount % 1 == 0 then
		needSyncBallUpdate = true
		syncElapse = self.tickCount - self.lastSyncBallUpdate
		self.lastSyncBallUpdate = self.tickCount
	end

	if self.tickCount >= self.gameOverTick then
		--游戏结束
		self:GameOver()	
		M.battles[self.id] = nil
		return
	else
		self.dummyUser:Update(elapse)
		self.AiMgr:Update()
		self.ballUpdate = {}
		for k,v in pairs(self.users) do
			v:Update(elapse)
			if needSyncBallUpdate then
				v:PackBallUpdate(self.ballUpdate)
			end 
		end
	end
	self:NotifyBegsee()
	if needSyncBallUpdate then
		self:NotifyBallUpdate(syncElapse)
	end
	self:NotifyEndSee()
	self.starMgr:Update()
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
	battleUser:Send2Client({cmd="EnterRoom" , timestamp = self.tickCount , stars = self.starMgr:GetStarBits()})
	local balls = {}
	for k,v in pairs(self.users) do
		v:PackBallsOnBeginSee(balls)
	end
	self.dummyUser:PackBallsOnBeginSee(balls)
	
	if #balls > 0 then
		battleUser:Send2Client({cmd = "BeginSee",timestamp = self.tickCount,balls = balls})
	end

	if battleUser.ballCount == 0 then
		--创建玩家的球
		battleUser:Relive()
	end

	print("user enter OK")

end

function battle:NotifyBegsee()
	if self.beginsee and #self.beginsee > 0 then
		local t = {
			cmd = "BeginSee",
			timestamp = self.tickCount,
			balls = self.beginsee
		}
		self:Broadcast(t)
		self.beginsee = nil
	end
end

function battle:NotifyEndSee()
	if self.endsee and #self.endsee > 0 then
		local t = {
			cmd = "EndSee",
			timestamp = self.tickCount,
			balls = self.endsee
		}
		self:Broadcast(t)
		self.endsee = nil
	end
end

function battle:NotifyBallUpdate(elapse)
	if self.ballUpdate and #self.ballUpdate > 0 then
		local t = {
			cmd = "BallUpdate",
			timestamp = self.tickCount,
			elapse = elapse,
			balls = self.ballUpdate
		}
		self:Broadcast(t)
		self.ballUpdate = nil
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
	local battleUser = M.userID2BattleUser[userID]
	local room
	if battleUser then
		battleUser.player = player
		player.battleUser = battleUser
		room = battleUser.battle
	else
		print("new battleuser")
		battleUser = battleuser.new(player,userID)
		M.userID2BattleUser[userID] = battleUser 
		room = M.getFreeRoom()
	end
	room:Enter(battleUser)
end



return M