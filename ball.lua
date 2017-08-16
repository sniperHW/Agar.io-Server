local util = require("util")
local config = require("config")
local chuck = require("chuck")
local objtype = require("objtype")
local packet = chuck.packet
local buffer = chuck.buffer

local M = {}

local ball = {}
ball.__index = ball

function M.new(id,owner,type,pos,score,color)
	local o = {}
	o = setmetatable(o,ball)
	o.owner = owner
	o.pos = {x=pos.x , y=pos.y}
	o.score = score
	o.r = config.Score2R(score)
	o.color = color
	o.id = id
	o.type = type
	owner.balls[id] = o
	owner.ballCount = owner.ballCount + 1
	owner.battle.colMgr:Enter(o)
	return o
end

function ball:OnDead()
	self.owner.battle.colMgr:Leave(self)
	self.owner:OnBallDead(self)
end

function ball:UpdatePosition(averageV,elapse)
	elapse = elapse/1000
	self.pos.x = self.pos.x + averageV.x * elapse
	self.pos.y = self.pos.y + averageV.y * elapse
	local mapBorder = self.owner.battle.mapBorder
	local bottomLeft = mapBorder.bottomLeft
	local topRight = mapBorder.topRight
	local R = self.r * math.sin(util.PI/4)
	self.pos.x = util.max(R + bottomLeft.x,self.pos.x)
	self.pos.x = util.min(topRight.x - R,self.pos.x)
	self.pos.y = util.max(R + bottomLeft.y,self.pos.y)
	self.pos.y = util.min(topRight.y - R,self.pos.y)
end

function ball:Update(elapse)
	--更新速度
	if self.moveVelocity then
		self.v = self.moveVelocity:Update(elapse)
		if self.v:mag() <= 0 then
			self.moveVelocity = nil
			return
		end
	else
		return
	end

	local battle = self.owner.battle

	--计算一个预测速度
	local predictV = self.moveVelocity:Copy():Update(battle.tickInterval)

	--更新位置
	self:UpdatePosition(self.v,elapse)
	battle.colMgr:Update(self)
	local msg = {
		cmd = "BallUpdate",
		id = self.id,
		timestamp = battle.tickCount,
		pos = {x = self.pos.x, y = self.pos.y},
		elapse = elapse,
		v = {x = predictV.x,y = predictV.y},
		r = self.r
	}
	--通告客户端
	battle:Broadcast(msg)
end

function ball:Move(direction)
	--print("ball:Move",self.id)
	--首先根据小球半径计算速度标量值
	local speed = config.SpeedByR(self.r)
	self.reqDirection = math.modf(direction,360)
	--将传入的角度和速度标量转换成一个速度向量
	local maxVeLocity = util.Transform2Vector2D(self.reqDirection,speed)
	if self.moveVelocity then
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,maxVeLocity,200)
	else
		self.moveVelocity = util.velocity.new(util.Transform2Vector2D(0,0),maxVeLocity,200)
	end
end

function ball:Stop()
	if self.moveVelocity then
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,util.vector2D.new(0,0),200,200)
	end
end

function ball:PackOnBeginSee(t)
	local tt = {}
	tt.userID = self.owner.userID
	tt.id = self.id
	tt.r = self.r
	tt.pos = {x = self.pos.x,y = self.pos.y}
	tt.color = self.color
	local velocitys = {}
	if self.moveVelocity then
		self.moveVelocity:Pack(velocitys)
	end

	if self.otherVelocitys then
		for k,v in pairs(self.otherVelocitys) do
			v:Pack(velocitys)
		end
	end

	if #velocitys > 0 then
		tt.velocitys = velocitys
	end

	table.insert(t,tt)
end

function ball:EatStar(star)
	self.owner.battle.starMgr:OnStarDead(star)
	self.score = self.score + config.starScore
	self.r = config.Score2R(self.score)
end

function ball:OnOverLap(other)
	if other.type == objtype.star then
		self:EatStar(other)
	else

	end
end

return M