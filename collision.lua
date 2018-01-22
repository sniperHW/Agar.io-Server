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

function M.new(battle)
	local o = {}
	o = setmetatable(o,collisionMgr)
	o.QuadTree = QuadTree.new(QuadTree.rect(0,0,config.mapWidth,config.mapWidth))
	return o
end

function collisionMgr:Enter(o)
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

--[[

--网格碰撞

M.blockWidth = config.mapWidth/100

local collisionMgr = {}
collisionMgr.__index = collisionMgr

local block = {}
block.__index = block

function M.newBlock(mgr,x,y)
	local o = {}
	o = setmetatable(o,block)
	o.mgr = mgr
	o.x = x
	o.y = y
	o.objs = {}
	return o
end


function block:Add(o)
	self.objs[o] = o
end

function block:Remove(o)
	self.objs[o] = nil
end

local function CheckCollision(o,other)
	--星星是不需要主动检测与其它对象碰撞的
	if o.type ~= objtype.star then
		local total_r = o.r + other.r
		local distance_pow2 = util.point2D.distancePow2(o.pos,other.pos)
		if distance_pow2 < total_r * total_r then
			o:OnOverLap(other)
		end			
	end
end

function block:CheckCollision(o,alreayCheck)
	for k,v in pairs(self.objs) do
		if o ~= v then
			if v.type == objtype.star then
				CheckCollision(o,v)
			else
				if not v.checked then
					table.insert(alreayCheck,v)
					CheckCollision(o,v)
				end
			end
		end
	end
end

function M.new(battle)
	local o = {}
	o = setmetatable(o,collisionMgr)
	o.blocks = {}
	local xCount = math.floor(config.mapWidth % M.blockWidth == 0 and (config.mapWidth / M.blockWidth) or (config.mapWidth / M.blockWidth) + 1)
	for y = 1,xCount do
		o.blocks[y] = {}
		for x = 1,xCount do
			o.blocks[y][x] = M.newBlock(o,x,y)
		end
	end
	return o
end

function collisionMgr:getBlockByPoint(pos)
	local x = pos.x
	local y = pos.y
	x = math.max(0,x)
	y = math.max(0,y)
	x = math.min(config.mapWidth-1 , x)
	y = math.min(config.mapWidth-1 , y)
	x = math.floor(x / M.blockWidth)
	y = math.floor(y / M.blockWidth)
	return self.blocks[y+1][x+1]
end

function collisionMgr:calBlocks(o)
	local blocks = {}
	blocks.block_info = {}
	blocks.blocks = {}
	local bottom_left = {x = math.max(0,o.pos.x - o.r) , y = math.max(0 , o.pos.y - o.r)}
	local top_right = {x = math.min(config.mapWidth - 1 , o.pos.x + o.r), y = math.min(config.mapWidth - 1 , o.pos.y + o.r)}

	local block_bottom_left = self:getBlockByPoint(bottom_left)
	local block_top_right = self:getBlockByPoint(top_right)

	blocks.block_info.bottom_left = {x = block_bottom_left.x , y = block_bottom_left.y }
	blocks.block_info.top_right = {x = block_top_right.x , y = block_top_right.y }

	for y = block_bottom_left.y,block_top_right.y do
		for x = block_bottom_left.x,block_top_right.x do
			table.insert(blocks.blocks,self.blocks[y][x])
		end
	end
	return blocks
end

function collisionMgr:Enter(o)
	o.blocks = self:calBlocks(o)
	for k,v in pairs(o.blocks.blocks) do
		v:Add(o)
	end
	o.colMgr = self
end

function collisionMgr:Leave(o)
	if o.colMgr then	
		for k,v in pairs(o.blocks.blocks) do
			v:Remove(o)
		end
		o.blocks = nil
		o.colMgr = nil
	end
end

local function in_range(top_right,bottom_left,x,y)
	if x >= bottom_left.x and y >= bottom_left.y and x <= top_right.x and y <= top_right.y then
		return true
	else
		return false
	end
end

--根据对象坐标更新管理块
function collisionMgr:Update(o)
	if o.colMgr then
		--计算出新管理块
		local blocks = self:calBlocks(o)
		
		for k,v in pairs(blocks.blocks) do
			--向新加入的管理块加入对象（在新单元,不在老管理单元范围内的块）
			if not in_range(o.blocks.block_info.top_right, o.blocks.block_info.bottom_left , v.x , v.y) then			
				v:Add(o)
			end
		end

		for k,v in pairs(o.blocks.blocks) do
			--从离开的管理块移除对象(在老单元,不在新单元范围内的块)
			if not in_range(blocks.block_info.top_right, blocks.block_info.bottom_left , v.x , v.y) then
				v:Remove(o)
			end
		end

		o.blocks = blocks
	end
end

--检测对象是否与其它对象产生碰撞
function collisionMgr:CheckCollision(o)
	if o.colMgr then
		local alreayCheck = {}
		for k,v in pairs(o.blocks.blocks) do
			v:CheckCollision(o,alreayCheck)
		end

		for k,v in pairs(alreayCheck) do
			v.checked = nil
		end

	end
end
]]--

return M