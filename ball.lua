local util = require("util")
local config = require("config")
local chuck = require("chuck")
local packet = chuck.packet
local buffer = chuck.buffer

local M = {}

local ball = {}
ball.__index = ball

function M.new(id,owner,pos,score,color)
	local o = {}
	o = setmetatable(o,ball)
	o.owner = owner
	o.pos = {x=pos.x , y=pos.y}
	o.score = score
	o.r = config.Score2R(score)
	o.color = color
	o.id = id
	table.insert(owner.balls,o)
	return o
end

function ball:UpdatePosition(averageV,elapse)
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
		self.v = self.moveVelocity:Update(elapse,true)
		if self.v:mag() == 0 then
			return
		end
	else
		return
	end
	--更新位置
	self:UpdatePosition(self.v,elapse)
	--print("ball:Update",self.pos.x,self.pos.y)	
	local msg = {
		cmd = "BallUpdate",
		id = self.id,
		timestamp = self.owner.battle.tickCount,
		pos = {x = self.pos.x, y = self.pos.y},
		elapse = elapse,
		v = {x = self.v.x,y = self.v.y}
	}
	--通告客户端
	self.owner.battle:Broadcast(msg)
end

function ball:Move(direction)
	--print("ball:Move",self.id)
	--首先根据小球半径计算速度标量值
	local speed = config.SpeedByR(self.r)
	self.reqDirection = math.modf(direction,360)
	--将传入的角度和速度标量转换成一个速度向量
	local maxVeLocity = util.Transform2Vector2D(self.reqDirection,speed)
	if self.moveVelocity then
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,maxVeLocity,0.2)
	else
		self.moveVelocity = util.velocity.new(util.Transform2Vector2D(0,0),maxVeLocity,0.2)
	end
end

function ball:Stop()
	if self.moveVelocity then
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,util.vector2D.new(0,0),0.2)
	end
end

function ball:PackOnBeginSee(t)
	local tt = {}
	tt.userID = self.owner.userID
	tt.id = self.id
	tt.r = self.r
	tt.pos = {x = self.pos.x,y = self.pos.y}
	tt.color = self.color
	table.insert(t,tt)
end


return M