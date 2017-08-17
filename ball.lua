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
	o.lastR = r	
	o.color = color
	o.id = id
	o.type = type
	o.otherVelocitys = {}
	o.reqDirection = 0
	o.v = util.vector2D.new(0,0)
	owner.balls[id] = o
	owner.ballCount = owner.ballCount + 1
	owner.battle.colMgr:Enter(o)
	return o
end

function ball:OnDead()
	self.owner.battle.colMgr:Leave(self)
	self.owner:OnBallDead(self)
	self.owner.battle:Broadcast({cmd="EndSee",id=self.id})
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
	local predictVelocitys

	if self.type ~= objtype.spore then
		predictVelocitys = {}
	end

	self.v = util.vector2D.new(0,0)

	if self.moveVelocity then
		self.v = self.moveVelocity:Update(elapse)
		if self.type ~= objtype.spore then
			table.insert(predictVelocitys,self.moveVelocity:Copy())
		end
	end

	for k,v in pairs(self.otherVelocitys) do
		self.v = self.v + v:Update(elapse)
		if v.duration <= 0 then
			self.otherVelocitys[k] = nil
		else
			if self.type ~= objtype.spore then			
				table.insert(predictVelocitys,v:Copy())
			end
		end
	end
		
	if self.v:mag() <= 0 then
		self.moveVelocity = nil
		if self.type ~= objtype.spore and self.lastR ~= self.r then
			self.lastR = self.r
			self.owner.battle:Broadcast({
				cmd = "BallUpdate",
				id = self.id,
				timestamp = self.owner.battle.tickCount,
				r = self.r
			})
		end
		return
	end

	--更新位置
	self:UpdatePosition(self.v,elapse)
	self.owner.battle.colMgr:Update(self)

	if self.type ~= objtype.spore then
		local battle = self.owner.battle
		--计算一个预测速度
		local predictV = util.vector2D.new(0,0)
		for k,v in pairs(predictVelocitys) do
			predictV = predictV + v:Update(battle.tickInterval)
		end	

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
		self.lastR = self.r
	end
end

function ball:Move(direction)
	--print("ball:Move",self.id)
	--首先根据小球半径计算速度标量值
	local speed = config.SpeedByR(self.r)
	self.reqDirection = math.modf(direction,360)
	--将传入的角度和速度标量转换成一个速度向量
	local maxVeLocity = util.TransformV(self.reqDirection,speed)
	if self.moveVelocity then
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,maxVeLocity,200)
	else
		self.moveVelocity = util.velocity.new(util.TransformV(0,0),maxVeLocity,200)
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
	if not self.owner.stop then
		local speed = config.SpeedByR(self.r)
		--将传入的角度和速度标量转换成一个速度向量
		local maxVeLocity = util.TransformV(self.reqDirection,speed)
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,maxVeLocity,200)		
	end
end

function ball:EatSpore(other)
	other:OnDead()
	self.score = self.score + other.score
	self.r = config.Score2R(self.score)
	if not self.owner.stop then
		local speed = config.SpeedByR(self.r)
		--将传入的角度和速度标量转换成一个速度向量
		local maxVeLocity = util.TransformV(self.reqDirection,speed)
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,maxVeLocity,200)		
	end
end

local function canEat(b1,b2)
	local eatFactor = config.EatFactor(b1.score)
	if b1.score/b2.score >= eatFactor then
		return true
	else
		return false
	end
end

function ball:OnOverLap(other)
	if self.type == objtype.spore then
		return
	end
	if other.type == objtype.star then
		self:EatStar(other)
	elseif other.type == objtype.spore then
		local distance = util.point2D.distance(self.pos,other.pos)
		if distance <= self.r and canEat(self,other) then
			self:EatSpore(other)
		end
	end
end

function ball:spit(owner,type,spitScore,spitterScore,dir,v0,duration)
	local spitR = config.Score2R(spitScore)
	local leftBottom = {x = spitR, y = spitR}
	local rightTop = {x = config.mapWidth - spitR, y = config.mapWidth - spitR}
	local spiterR = config.Score2R(spitterScore)
	local bornPoint = util.point2D.moveto(self.pos , self.reqDirection , spiterR + spitR , leftBottom , rightTop)	
	local newBall = M.new(self.owner.battle:GetBallID(),owner,type,bornPoint,spitScore,math.random(1,#config.colors))
	--print(self.score,spitterScore)
	self.score = spitterScore
	self.r = spiterR
	--添加弹射运动量
	local velocity = util.velocity.new(util.TransformV(dir,v0),util.TransformV(0,0),duration,duration)
	table.insert(newBall.otherVelocitys,velocity)
	if not self.owner.stop then
		if type == ball then
			local speed = config.SpeedByR(spitR)
			--将传入的角度和速度标量转换成一个速度向量
			local maxVeLocity = util.TransformV(self.reqDirection,speed)
			newBall.moveVelocity = util.velocity.new(maxVeLocity)
		end
		--自己的积分减少，速度改变了
		local speed = config.SpeedByR(self.r)
		--将传入的角度和速度标量转换成一个速度向量
		local maxVeLocity = util.TransformV(self.reqDirection,speed)
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,maxVeLocity,200)
	end
	local t = {
		cmd = "BeginSee",
		timestamp = self.owner.battle.tickCount,
		balls = {}
	}
	newBall:PackOnBeginSee(t.balls)
	self.owner.battle:Broadcast(t)
end

function ball:Spit()
	local eatFactor = config.EatFactor(self.score)
	if self.score >= config.sp0 * (1 + eatFactor) then
		local spitR = config.Score2R(config.sp0)
		local L = 9 * config.screenSizeFactor
		local v0 = config.SpeedByR(spitR) * config.spitV0Factor
		local spitDuration = math.floor((2*L/v0)*1000)
		self:spit(self.owner.battle.dummyUser , objtype.spore , config.sp0 , self.score - config.sp0 , self.reqDirection , v0 , spitDuration)
	end
end

return M