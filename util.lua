local M = {}
M.point2D = {}
M.vector2D = {}
M.velocity = {}
M.PI = 3.1415926

function M.min(a,b)
	return a < b and a or b
end

function M.max(a,b)
	return a > b and a or b
end

function M.point2D.new(x,y)
	return {x=x,y=y}
end

function M.point2D.equal(p1,p2)
	return p1.x == p2.x and p1.y == p2.y	
end

function M.point2D.distance(p1,p2)
	local xx = p1.x - p2.x
	local yy = p1.y - p2.y
	return math.sqrt(xx * xx + yy * yy)
end

function M.point2D.distancePow2(p1,p2)
	local xx = p1.x - p2.x
	local yy = p1.y - p2.y
	return xx * xx + yy * yy	
end

local vector2D = {}
vector2D.__index = vector2D
vector2D.__vector2D = true

local function isTypeVector2D(o)
	return type(o) == "table" and o.__vector2D
end

vector2D.__add = function (p1,p2)
	if isTypeVector2D(p1) and isTypeVector2D(p2) then
		return M.vector2D.new(p1.x + p2.x, p1.y + p2.y)
	else
		return nil
	end
end

vector2D.__sub = function (p1,p2)
	if isTypeVector2D(p1) and isTypeVector2D(p2) then
		return M.vector2D.new(p1.x - p2.x, p1.y - p2.y)
	else
		return nil
	end
end

vector2D.__mul = function (p1,p2)
	if isTypeVector2D(p1) and type(p2) == "number" then
		return M.vector2D.new(p1.x * p2, p1.y * p2)
	end
	return nil
end

vector2D.__div = function (p1,p2)
	if isTypeVector2D(p1) and type(p2) == "number" then
		return M.vector2D.new(p1.x / p2, p1.y / p2)
	else
		return nil
	end
end

vector2D.__eq = function(p1,p2)
	if isTypeVector2D(p1) and isTypeVector2D(p2) then
		return p1.x == p2.x and p1.y == p2.y
	else
		return false
	end	
end

function M.vector2D.new(x,y)
	local o = {}
	o = setmetatable(o,vector2D)
	o.x = x
	o.y = y
	return o
end

--向量去模
function vector2D:mag()
	return math.sqrt(self.x * self.x + self.y * self.y);
end

--标准化向量
function vector2D:normalize()
	local len = math.sqrt(self.x * self.x + self.y * self.y)
	return self/len
end

--向量点乘
function vector2D:dotProduct(other)
	return M.vector2D.new(self.x * other.x, self.y * v2.y)
end

function vector2D:copy()
	return M.vector2D.new(self.x,self.y)
end

local velocity = {}
velocity.__index = velocity

function M.velocity.new(v0,v1,accelerateTime)
	local o = {}
	o = setmetatable(o,velocity)
	o.runTime = 0
	o.duration = accelerateTime or 0
	if o.duration > 0 then
		--变速运动分量从v0经过accelerateTime变到v1 
		o.v = v0:copy()
		o.a = (v1 - v0) / accelerateTime
		o.targetV = v1:copy()
	else
		--匀速运动分量
		o.targetV = v0:copy()
		o.v = v0:copy()
	end
	return o
end

--更新速度分量，并返回当前速度
function velocity:Update(elapse,holdTargetV)
	self.runTime = self.runTime + elapse
	local delta = M.min(elapse,self.duration)
	self.duration = self.duration - delta
	if self.duration == 0 then
		if self.v == self.targetV then 
			return self.v
		else
			local backV = self.v:copy()
			self.v = self.targetV:copy()
			local ret = (backV + self.targetV) / 2 * (delta/elapse)
			if holdTargetV then
				ret = ret + self.targetV * ((elapse - delta)/elapse)
			end
			return ret
		end
	else
		local lastV = self.v:copy()
		self.v = self.v + (self.a * delta)
		return (lastV + self.v)/2
	end
end

function M.Transform2Vector2D(direction,v)
	direction = math.modf(direction,360.0)
	local rad = M.PI/180.0*direction
	return M.vector2D.new(math.cos(rad) * v, math.sin(rad) * v)
end

--[[
for i=0,20 do
	print(string.format("{%.02f,%.02f,%.02f,1},",math.random(1,100)/100,math.random(1,100)/100,math.random(1,100)/100))
end
]]--

return M