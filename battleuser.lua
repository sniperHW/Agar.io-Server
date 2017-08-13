local config = require("config")
local ball = require("ball")
local M = {}

local battleUser = {}
battleUser.__index = battleUser

function M.new(player)
	local o = {}
	o = setmetatable(o,battleUser)
	o.player = player
	player.battleUser = o
	o.color = math.random(1,#config.colors)
	o.balls = {}
	o.userID = player.userID
	return o
end

function battleUser:Relive()
	local r = math.ceil(config.Score2R(config.initScore))
	local pos = {}
	local mapWidth = self.battle.mapBorder.topRight.x - self.battle.mapBorder.bottomLeft.x
	local mapHeight = self.battle.mapBorder.topRight.y - self.battle.mapBorder.bottomLeft.y	
	pos.x = math.random(r, mapWidth - r)
	pos.y = math.random(r, mapHeight - r)
	local ballID = self.battle:GetBallID()

	local newBall = ball.new(ballID,self,pos,config.initScore,self.color)
	if newBall then
		local t = {
			cmd = "BeginSee",
			timestamp = self.battle.tickCount,
			balls = {}
		}
		newBall:PackOnBeginSee(t.balls)
		self.battle:Broadcast(t)	
	end
end

function battleUser:Update(elapse)
	for k,v in pairs(self.balls) do
		v:Update(elapse)
	end
end

function battleUser:PackBallsOnBeginSee(t)
	for k,v in pairs(self.balls) do
		v:PackOnBeginSee(t)
	end
end

function battleUser:Move(msg)
	for k,v in pairs(self.balls) do
		v:Move(msg.dir)
	end	
end

function battleUser:Stop(msg)
	for k,v in pairs(self.balls) do
		v:Stop()
	end
end

function battleUser:Send2Client(msg)
	if self.player then
		self.player:Send2Client(msg)
	end
end

return M