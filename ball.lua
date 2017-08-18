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
	o.otherVelocitys = {}
	o.reqDirection = 0
	o.v = util.vector2D.new(0,0)
	owner.balls[id] = o
	owner.ballCount = owner.ballCount + 1
	owner.battle.colMgr:Enter(o)
	o.clientR = o.r
	o.clientPos = {x=pos.x , y=pos.y}
	return o
end



function ball:OnDead()
	self.owner.battle.colMgr:Leave(self)
	self.owner:OnBallDead(self)
	self.owner.battle.endsee = self.owner.battle.endsee or {}
	table.insert(self.owner.battle.endsee,self.id)
end

function ball:fixBorder()
	local mapBorder = self.owner.battle.mapBorder
	local bottomLeft = mapBorder.bottomLeft
	local topRight = mapBorder.topRight
	local R = self.r * math.sin(util.PI/4)
	self.pos.x = util.max(R + bottomLeft.x,self.pos.x)
	self.pos.x = util.min(topRight.x - R,self.pos.x)
	self.pos.y = util.max(R + bottomLeft.y,self.pos.y)
	self.pos.y = util.min(topRight.y - R,self.pos.y)
end

function ball:UpdatePosition(averageV,elapse)
	elapse = elapse/1000
	self.pos.x = self.pos.x + averageV.x * elapse
	self.pos.y = self.pos.y + averageV.y * elapse
	self:fixBorder()
end

function ball:PredictV()
	--计算一个预测速度
	local predictVelocitys = {}

	if self.moveVelocity then
		table.insert(predictVelocitys,self.moveVelocity:Copy())
	end

	for k,v in pairs(self.otherVelocitys) do
		table.insert(predictVelocitys,v:Copy())
	end

	local predictV = util.vector2D.new(0,0)
	for k,v in pairs(predictVelocitys) do
		predictV = predictV + v:Update(battle.tickInterval)
	end	

	local predictV = predictV/3
end

function ball:Update(elapse)

	if self.splitTimeout and self.owner.battle.tickCount > self.splitTimeout then
		self.splitTimeout = nil
	end

	self.v = util.vector2D.new(0,0)

	if self.moveVelocity then
		self.v = self.moveVelocity:Update(elapse)
	end

	for k,v in pairs(self.otherVelocitys) do
		self.v = self.v + v:Update(elapse)
		if v.duration <= 0 then
			self.otherVelocitys[k] = nil
		end
	end
		
	if self.v:mag() <= 0 then
		self.moveVelocity = nil
		return
	end

	--更新位置
	self:UpdatePosition(self.v,elapse)
	self.owner.battle.colMgr:Update(self)

	if self.type ~= objtype.spore then
		local battle = self.owner.battle
		battle.colMgr:Update(self)
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

local function calSplitTimeout(score)
	return math.floor(math.sqrt(score*4))*1000
end

function ball:EatStar(star)
	self.owner.battle.starMgr:OnStarDead(star)
	self.score = self.score + config.starScore
	self.r = config.Score2R(self.score)
	if not self.owner.stop and self.moveVelocity then
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
	if not self.owner.stop and self.moveVelocity then
		local speed = config.SpeedByR(self.r)
		--将传入的角度和速度标量转换成一个速度向量
		local maxVeLocity = util.TransformV(self.reqDirection,speed)
		self.moveVelocity = util.velocity.new(self.moveVelocity.v,maxVeLocity,200)		
	end
end

function ball:EatBall(other)
	other:OnDead()
	self.score = self.score + other.score
	self.r = config.Score2R(self.score)
	if self.owner == other.owner then
		self.splitTimeout = self.owner.battle.tickCount + calSplitTimeout(self.score)
	end
	if not self.owner.stop and self.moveVelocity then
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

local function checkCellCollision(ball1,ball2)
	local totalR = ball1.r + ball2.r
	local dx = ball2.pos.x - ball1.pos.x
	local dy = ball2.pos.y - ball1.pos.y
	local squared = dx * dx + dy * dy
	if squared > totalR * totalR then
		return nil
	else
		return {totalR = totalR , dx = dx , dy = dy, squared = squared}
	end

end


function ball:OnSelfBallOverLap(other)
	local manifold = checkCellCollision(self,other)
	if manifold then
		local ball1 = self
		local ball2 = other
		local d = math.sqrt(manifold.squared)
		if d <= 0 then
			return
		end

		local invd = 1 / d
		local nx = math.floor(manifold.dx) * invd
		local ny = math.floor(manifold.dy) * invd
		local penetration =(manifold.totalR - d) * 0.75
		if penetration <= 0 then
			return
		end

		local px = penetration * nx;
		local py = penetration * ny;

		local totalMass,invTotalMass,impulse1,impulse2


		totalMass = ball1.score + ball2.score
		if totalMass <= 0 then
			return
		end


		--发生冲撞时两圆心向量
		local vv = util.vector2D.new(ball1.pos.x - ball2.pos.x , ball1.pos.y - ball2.pos.y)

		invTotalMass = 1 / totalMass;
		impulse1 = ball2.score * invTotalMass
		impulse2 = ball1.score * invTotalMass

		ball1.pos.x = ball1.pos.x - (px * impulse1)
		ball1.pos.y = ball1.pos.y - (py * impulse1)
		ball2.pos.x = ball2.pos.x + (px * impulse2)
		ball2.pos.y = ball2.pos.y + (py * impulse2)

		ball1:fixBorder()
		ball2:fixBorder()

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
	elseif other.type == objtype.ball then
		if other.owner == self.owner then
			--print(other.splitTimeout , self.splitTimeout)
			if other.splitTimeout or self.splitTimeout then
				self:OnSelfBallOverLap(other)
			else
				local distance = util.point2D.distance(self.pos,other.pos)
				if distance <= self.r then
					self:EatBall(other)
				end
			end
		else
			local distance = util.point2D.distance(self.pos,other.pos)
			if distance <= self.r and canEat(self,other) then
				self:EatBall(other)
			end
		end
	end
end

function ball:spit(owner,newtype,spitScore,spitterScore,dir,v0,duration)
	local spitR = config.Score2R(spitScore)
	local leftBottom = {x = spitR, y = spitR}
	local rightTop = {x = config.mapWidth - spitR, y = config.mapWidth - spitR}
	local spiterR = config.Score2R(spitterScore)
	local bornPoint = util.point2D.moveto(self.pos , self.reqDirection , spiterR + spitR , leftBottom , rightTop)	

	local color 

	if newtype == objtype.ball then
		color = self.color
	else
		color = math.random(1,#config.colors)
	end

	self.score = spitterScore
	self.r = spiterR

	local newBall = M.new(self.owner.battle:GetBallID(),owner,newtype,bornPoint,spitScore,color)
	
	if newtype == objtype.ball then
		newBall.splitTimeout = self.owner.battle.tickCount + calSplitTimeout(newBall.score)		
	end


	--添加弹射运动量
	local velocity = util.velocity.new(util.TransformV(dir,v0),util.TransformV(0,0),duration,duration)
	table.insert(newBall.otherVelocitys,velocity)
	if not self.owner.stop then
		if newtype == objtype.ball then
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

	self.owner.battle.beginsee = self.owner.battle.beginsee or {}
	newBall:PackOnBeginSee(self.owner.battle.beginsee)

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

function ball:splitAble()
	local eatFactor = config.EatFactor(self.score)
	if self.score < config.sp0 * eatFactor * 2 then
		return false
	else
		return true
	end

end

function ball:Split()
	if self.owner.ballCount >= config.maxUserBallCount then
		return
	end

	if not self:splitAble() then
		return
	end

	local newR = config.Score2R(self.score/2)
	local L = newR + 5.5 * config.screenSizeFactor
	local v0 = math.floor(2 * L * 1000 / config.splitDuration)
	self:spit(self.owner , objtype.ball , self.score/2 , self.score/2 , self.reqDirection , v0 , config.splitDuration)
	self.splitTimeout = self.owner.battle.tickCount + calSplitTimeout(self.score)	
end

return M