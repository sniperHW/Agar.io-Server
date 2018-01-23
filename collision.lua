local colliQuadTree = require("collisionQuadTree")
local colliGrid = require("collisionGrid")

local M = {}

local collision = {}
collision.__index = collision

function M.new()
	local o = {}
	o = setmetatable(o,collision)
	o.impl = colliQuadTree.new()
	return o
end

function collision:Enter(o)
	self.impl:Enter(o)
end

function collision:Leave(o)
	self.impl:Leave(o)
end

--根据对象坐标更新管理块
function collision:Update(o)
	self.impl:Update(o)		
end

--检测对象是否与其它对象产生碰撞
function collision:CheckCollision(o)
	self.impl:CheckCollision(o)
end

return M