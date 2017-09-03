--视野模块
local config = require("config")
local util = require("util")
local chuck = require("chuck")
local log = chuck.log

local M = {}

M.blockWidth = config.mapWidth/50
M.visibleSize = {width = 1024,height = 768}

local block = {}
block.__index = block

function M.newBlock(mgr,x,y)
	local o = {}
	o = setmetatable(o,block)
	o.mgr = mgr
	o.x = x
	o.y = y
	o.objs = {}
	o.observers = {}
	return o
end

function block:Add(o)
	self.objs[o] = o
	for k,v in pairs(self.observers) do
		if not v.viewObjs[o] then
			v.viewObjs[o] = {enterSee = true,ref = 1}
			v.beginsee = v.beginsee or {}
			o:PackOnBeginSee(v.beginsee)
		else
			local t = v.viewObjs[o]
			t.ref = t.ref + 1
		end
	end
end

function block:Remove(o)
	self.objs[o] = nil
	for k,v in pairs(self.observers) do
		if v.viewObjs[o] then
			local t = v.viewObjs[o]
			t.ref = t.ref - 1			
		end
	end
end

function block:AddObserver(o)
	self.observers[o] = o
	for k,v in pairs(self.objs) do
		if o.viewObjs[k] then
			local t = o.viewObjs[v]
			t.ref = t.ref + 1		
		else
			o.viewObjs[k] = {enterSee = true,ref = 1}
			o.beginsee = o.beginsee or {}
			k:PackOnBeginSee(o.beginsee)
		end
	end
end

function block:RemoveObserver(o)
	if self.observers[o] then
		self.observers[o] = nil
		for k,v in pairs(self.objs) do
			if o.viewObjs[k] then
				local t = o.viewObjs[k]
				t.ref = t.ref - 1				
			end
		end
	end
end

local visionMgr = {}
visionMgr.__index = visionMgr

function M.new()
	local o = {}
	o = setmetatable(o,visionMgr)
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

function visionMgr:getBlockByPoint(pos)
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

function visionMgr:calBlocks(o)
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

function visionMgr:calUserVisionBlocks(user)
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


--对象进入视野系统
function visionMgr:Enter(o)
	o.visionblocks = self:calBlocks(o)
	for k,v in pairs(o.visionblocks.blocks) do
		v:Add(o)
	end
	o.visionMgr = self
end

--对象离开视野系统
function visionMgr:Leave(o)
	if o.visionMgr then	
		for k,v in pairs(o.visionblocks.blocks) do
			v:Remove(o)
		end
		o.visionblocks = nil
		o.visionMgr = nil
	end
end

local function in_range(top_right,bottom_left,x,y)
	if x >= bottom_left.x and y >= bottom_left.y and x <= top_right.x and y <= top_right.y then
		return true
	else
		return false
	end
end

--更新对象的视野块
function visionMgr:UpdateVisionObj(o)
	if o.colMgr then
		--计算出新管理块
		local blocks = self:calBlocks(o)
		
		for k,v in pairs(o.visionblocks.blocks) do
			--从离开的管理块移除对象(在老单元,不在新单元范围内的块)
			if not in_range(blocks.block_info.top_right, blocks.block_info.bottom_left , v.x , v.y) then
				v:Remove(o)
			end
		end

		for k,v in pairs(blocks.blocks) do
			--向新加入的管理块加入对象（在新单元,不在老管理单元范围内的块）
			if not in_range(o.visionblocks.block_info.top_right, o.visionblocks.block_info.bottom_left , v.x , v.y) then			
				v:Add(o)
			end
		end


		o.visionblocks = blocks
	end

end


function visionMgr:updateViewPort(user)
	if user.ballCount == 0 then
		return user.viewPort.bottomLeft,user.viewPort.topRight
	end

	local viewPortWidth , viewPortHeight

	if user.ballCount == 1 then
		local ball
		for k,v in pairs(user.balls) do
			ball = v
		end
		local baseR = config.Score2R(config.initScore)
		local R = config.Score2R(ball.r)
		if R == baseR then
			viewPortWidth = M.visibleSize.width
			viewPortHeight = M.visibleSize.height
		else
			viewPortWidth =  math.floor((1+(R/baseR)/10) * M.visibleSize.width)
			viewPortWidth = math.min(viewPortWidth,config.mapWidth)
			viewPortHeight = math.floor((M.visibleSize.height * viewPortWidth)/M.visibleSize.width)
		end
	else
		local maxDeltaX = 0
		local maxDeltaY = 0
		for k,v in pairs(user.balls) do
			local vv = util.vector2D.new(v.pos.x - user.visionCenter.x , v.pos.y - user.visionCenter.y)
			local p = util.point2D.moveto(v.pos,vv:getDirAngle(),v.r)
			local deltaX = math.abs(p.x - user.visionCenter.x)
			local deltaY = math.abs(p.y - user.visionCenter.y)
			maxDeltaX = math.max(deltaX , maxDeltaX)
			maxDeltaY = math.max(deltaY , maxDeltaY)
		end

		if maxDeltaX/M.visibleSize.width > maxDeltaY/M.visibleSize.height then
			if maxDeltaX > M.visibleSize.width/4 then
				viewPortWidth = user.viewPort.width/2 + maxDeltaX + 200
				viewPortWidth = math.min(viewPortWidth,config.mapWidth)
				viewPortHeight = math.floor((M.visibleSize.height * viewPortWidth)/M.visibleSize.width)			
			else
				viewPortWidth = M.visibleSize.width
				viewPortHeight = M.visibleSize.height
			end
		else
			if maxDeltaY > M.visibleSize.height/4 then
				viewPortHeight = user.viewPort.height/2 + maxDeltaY + 200
				viewPortHeight = math.min(viewPortHeight,config.mapWidth)
				viewPortWidth = math.floor((M.visibleSize.width * viewPortHeight)/M.visibleSize.height)			
			else
				viewPortWidth = M.visibleSize.width
				viewPortHeight = M.visibleSize.height
			end
		end

	end


	local bottomLeft = {}
	bottomLeft.x = math.max(1,user.visionCenter.x - viewPortWidth/2 - 120)
	bottomLeft.y = math.max(1,user.visionCenter.y - viewPortHeight/2 - 120)

	local block = self:getBlockByPoint(bottomLeft)
	bottomLeft.x = block.x
	bottomLeft.y = block.y

	local topRight = {}
	topRight.x = math.max(config.mapWidth-1,user.visionCenter.x + viewPortWidth/2 + 120)
	topRight.y = math.max(config.mapWidth-1,user.visionCenter.y + viewPortHeight/2 + 120)

	local block = self:getBlockByPoint(topRight)
	topRight.x = block.x
	topRight.y = block.y

	user.viewPort.width = viewPortWidth
	user.viewPort.height = viewPortHeight		

	return bottomLeft,topRight
	
end

--更新玩家视野
function visionMgr:UpdateUserVision(user)

	--首先计算玩家视野中心点
	if	user.ballCount > 0 then
		local cx = 0
		local cy = 0
		for k,v in pairs(user.balls) do
			cx = cx + v.pos.x
			cy = cy + v.pos.y
		end
		cx = cx / user.ballCount
		cy = cy / user.ballCount
		user.visionCenter = {x = cx,y = cy}
	end

	--计算视野范围
	local bottomLeft,topRight = self:updateViewPort(user)
	if not user.viewPort.bottomLeft or not user.viewPort.topRight then
		user.viewPort.bottomLeft = bottomLeft
		user.viewPort.topRight = topRight
		for y = bottomLeft.y,topRight.y do
			for x = bottomLeft.x,topRight.x do
				self.blocks[y][x]:AddObserver(user)
			end
		end
	else

		local oldBottomLeft = user.viewPort.bottomLeft
		local oldTopRight = user.viewPort.topRight

		if oldBottomLeft.x ~= bottomLeft.x or oldBottomLeft.y ~= bottomLeft.y or
		   oldTopRight.x ~= topRight.x or oldTopRight.y ~= topRight.y then
			user.viewPort.bottomLeft = bottomLeft
			user.viewPort.topRight = topRight

			for y = oldBottomLeft.y,oldTopRight.y do
				for x = oldBottomLeft.x,oldTopRight.x do
					--在老单元，不在新单元中
					if not in_range(bottomLeft,topRight,x,y) then
						self.blocks[y][x]:RemoveObserver(user)
					end 
				end
			end

			for y = bottomLeft.y,topRight.y do
				for x = bottomLeft.x,topRight.x do
					--在新单元，不在老单元中
					if not in_range(oldBottomLeft,oldTopRight,x,y) then
						self.blocks[y][x]:AddObserver(user)
					end 
				end
			end
		end
	end 
end

return M