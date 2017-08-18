local chuck = require("chuck")
local packet = chuck.packet
local config = require("config")
local minheap = require("minheap")
local objtype = require("objtype")
local M = {}

local star = {}
star.__index = star

local function newStar(id,mgr)
	local o = {}
	o = setmetatable(o,star)
	o.id = id
	o.mgr = mgr
	local s = config.stars[id]
	o.pos = {x = s.x , y = s.y}
	o.type = objtype.star
	o.r = 1
	o.index = 0
	mgr.room.colMgr:Enter(o)
	return o	
end

function star:Relive()
	local offset1 = math.floor((self.id - 1) / 32) + 1
	local offset2 = (self.id - 1) % 32
	--关闭星星标记
	self.mgr.starBits[offset1] = self.mgr.starBits[offset1] | (1 << offset2)
	self.mgr.room.colMgr:Enter(self)
end

local starMgr = {}
starMgr.__index = starMgr

function M.newMgr(room)
	local o = {}
	o = setmetatable(o,starMgr)
	local cc = #config.stars / 32
	o.starBits = {}
	o.stars = {}
	o.room = room
	o.minheap = minheap.new()
	for i = 1,cc do
		table.insert(o.starBits,0xffffffff)
	end
	local starCount = cc * 32
	for i = 1,starCount do
		--创建星星
		table.insert(o.stars,newStar(i,o))
	end
	return o
end

function starMgr:GetStarBits()
	return self.starBits
end

function starMgr:Update()
	local nowTick = self.room.tickCount
	local reliveStars = {}
	while self.minheap:Size() > 0 do
		if self.minheap:Min() > nowTick then
			break
		else
			--print("StarRelive")
			local star = self.minheap:PopMin()
			star:Relive()
			table.insert(reliveStars,star.id)
		end
	end

	if #reliveStars > 0 then
		--将复活的星星通告给客户端
		self.room:Broadcast({cmd="StarRelive",stars=reliveStars,timestamp=self.room.tickCount})
	end

	self:NotifyDead()
end

function starMgr:OnStarDead(star)
	--从碰撞管理器中移除
	self.room.colMgr:Leave(star)
	local offset1 = math.floor((star.id - 1) / 32) + 1
	local offset2 = (star.id - 1) % 32
	--关闭星星标记
	self.starBits[offset1] = self.starBits[offset1] ~ (1 << offset2)
	--复活时间
	star.timeout = self.room.tickCount + math.random(5000,8000)
	self.minheap:Insert(star)

	self.deads = self.deads or {}
	table.insert(self.deads,star.id)
	--print("minheap.size()",self.minheap:Size())
	--self.room:Broadcast({cmd="StarDead",id=star.id,timestamp=self.room.tickCount + 25})
end

function starMgr:NotifyDead()
	if self.deads and #self.deads > 0 then
		self.room:Broadcast({cmd="StarDead",stars=self.deads,timestamp=self.room.tickCount})
		self.deads = nil
	end
end

return M