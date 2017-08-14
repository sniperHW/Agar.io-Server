local chuck = require("chuck")
local packet = chuck.packet
local config = require("config")
local minheap = require("minheap")
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
	return o	
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
			local star = self.minheap:Min()
			star:Relive()
			table.insert(reliveStars,star.id)
		end
	end

	if #reliveStars then
		--将复活的星星通告给客户端
		self.room:Broadcast({cmd="StarRelive",stars=reliveStars})
	end
end

return M