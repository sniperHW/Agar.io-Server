local objtype = require("objtype")
local config = require("config")
local util = require("util")
local chuck = require("chuck")
local log = chuck.log
local QuadTree = require("QuadTree")

local M = {}


local collisionMgr = {}
collisionMgr.__index = collisionMgr

local function rect(pos,r)
	local bottomLeftX = pos.x - r
	if bottomLeftX < 0 then
		bottomLeftX = 0
	end
	local bottomLeftY = pos.y - r
	if bottomLeftY < 0 then
		bottomLeftY = 0
	end
	local topRightX = pos.x + r
	if topRightX > config.mapWidth then
		topRightX = config.mapWidth
	end
	local topRightY = pos.y + r
	if topRightY > config.mapWidth then
		topRightY = config.mapWidth
	end

	return QuadTree.rect(bottomLeftX,bottomLeftY,topRightX,topRightY)

end

function M.new()
	local o = {}
	o = setmetatable(o,collisionMgr)
	o.QuadTree = QuadTree.new(QuadTree.rect(0,0,config.mapWidth,config.mapWidth))
	return o
end

function collisionMgr:Enter(o)
	if o.colMgr then
		return
	end
	o.rect = rect(o.pos,o.r)
	o.colMgr = self
	self.QuadTree:insert(o)
end

function collisionMgr:Leave(o)
	if o.colMgr then	
		o.tree:remove(o)
		o.colMgr = nil
	end
end

--根据对象坐标更新管理块
function collisionMgr:Update(o)
	if o.colMgr then
		o.rect = rect(o.pos, o.r)
		self.QuadTree:update(o)		
	end
end

local function CheckCollision(o,other)
	--只有小球才主动检测碰撞
	if o.type == objtype.ball then
		local total_r = o.r + other.r
		local distance_pow2 = util.point2D.distancePow2(o.pos,other.pos)
		if distance_pow2 < total_r * total_r then
			o:OnOverLap(other)
		end			
	end
end

--检测对象是否与其它对象产生碰撞
function collisionMgr:CheckCollision(o)
	if o.colMgr then
		self.QuadTree:rectCall(o.rect,function (other)
			if other ~= o then
				CheckCollision(o,other)
			end
		end)
	end
end

return M