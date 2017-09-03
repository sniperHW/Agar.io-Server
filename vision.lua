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
		local isRealUser = v:IsRealUser()
		if isRealUser and v.player then
			if not v.viewObjs[o] then
				v.viewObjs[o] = {enterSee = true,ref = 1}
				v.beginsee = v.beginsee or {}
				o:PackOnBeginSee(v.beginsee)
			else
				local t = v.viewObjs[o]
				t.ref = t.ref + 1
			end
		elseif not isRealUser then
			if not v.viewObjs[o] then
				v.viewObjs[o] = {ref = 1}
			else
				local t = v.viewObjs[o]
				t.ref = t.ref + 1
			end
		end
	end
end

function block:Remove(o)
	self.objs[o] = nil
	for k,v in pairs(self.observers) do
		local isRealUser = v:IsRealUser()
		if (isRealUser and v.player) or (not isRealUser) then
			if v.viewObjs[o] then
				local t = v.viewObjs[o]
				t.ref = t.ref - 1			
			end	
		end
	end
end

function block:AddObserver(o)
	self.observers[o] = o
	for k,v in pairs(self.objs) do
		local isRealUser = o:IsRealUser()
		if isRealUser and o.player then
			if o.viewObjs[k] then
				local t = o.viewObjs[v]
				t.ref = t.ref + 1		
			else
				o.viewObjs[k] = {enterSee = true,ref = 1}
				if o:IsRealUser() and o.player then
					o.beginsee = o.beginsee or {}
					k:PackOnBeginSee(o.beginsee)
				end
			end
		elseif not isRealUser then
			if o.viewObjs[k] then
				local t = o.viewObjs[v]
				t.ref = t.ref + 1		
			else
				o.viewObjs[k] = {ref = 1}
			end
		end
	end
end

function block:RemoveObserver(o)
	if self.observers[o] then
		self.observers[o] = nil
		local isRealUser = o:IsRealUser()
		if (isRealUser and o.player) or (not isRealUser) then
			for k,v in pairs(self.objs) do
				if o.viewObjs[k] then
					local t = o.viewObjs[k]
					t.ref = t.ref - 1				
				end
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

    local _edgeMaxX = 0
    local _edgeMaxY = 0
    local _edgeMinX = 1000000
    local _edgeMinY = 1000000

	for k,v in pairs(user.balls) do
		local R = math.floor(config.Score2R(v.r))
		local bottomLeft = {x = v.pos.x - R,y = v.pos.y - R}
		local topRight = {x = v.pos.x + R,y = v.pos.y + R}

		if _edgeMaxX < topRight.x then
			_edgeMaxX = topRight.x
		end

		if _edgeMaxY < topRight.y then
			_edgeMaxY = topRight.y
		end

		if _edgeMinX > bottomLeft.x then
			_edgeMinX = bottomLeft.x
		end

		if _edgeMinY > bottomLeft.y then
			_edgeMinY = bottomLeft.y
		end

	end

    local width = _edgeMaxX - _edgeMinX
    local height = _edgeMaxY - _edgeMinY

    local para = 30
    local r = math.max(width,height)
    r = (r * 0.5) / para

    local a1 = 8 / math.sqrt(r)
    local a2 = math.max(a1,1.5)
    local a3 = r * a2
    local a4 = math.max(a3,10)
    local a5 = math.min(a4,100)
    local scale = a5 * para

    scale = scale / (M.visibleSize.height / 2)


    local _visionWidth = math.floor(M.visibleSize.width * scale + 300)
    local _visionHeight = math.floor(M.visibleSize.height * scale + 300)

 	local bottomLeft = {}
	bottomLeft.x = math.max(1,user.visionCenter.x - _visionWidth/2)
	bottomLeft.y = math.max(1,user.visionCenter.y - _visionHeight/2)

	local block = self:getBlockByPoint(bottomLeft)
	bottomLeft.x = block.x
	bottomLeft.y = block.y

	local topRight = {}
	topRight.x = math.max(config.mapWidth-1,user.visionCenter.x + _visionWidth/2)
	topRight.y = math.max(config.mapWidth-1,user.visionCenter.y + _visionHeight/2)

	local block = self:getBlockByPoint(topRight)
	topRight.x = block.x
	topRight.y = block.y
		
	return bottomLeft,topRight  

end

--更新玩家视野
function visionMgr:UpdateUserVision(user)

	if user:IsRealUser() and not user.player then
		return
	end

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