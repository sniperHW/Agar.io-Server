local M = {}

local minheap = {}
minheap.__index = minheap


function M.new()
  local o = {}   
  o = setmetatable(o, minheap)
  o.m_size = 0
  o.m_data = {}
  return o
end


function minheap:Up(index)
    local parent_idx = self:Parent(index)
    while parent_idx > 0 do
        if self.m_data[index].timeout < self.m_data[parent_idx].timeout then
            self:swap(index,parent_idx)
            index = parent_idx
            parent_idx = self:Parent(index)
        else
            break
        end
    end
end

function minheap:Down(index)
    local l = self:Left(index)
    local r = self:Right(index)
    local min = index

    if l <= self.m_size and self.m_data[l].timeout < self.m_data[index].timeout then
        min = l
    end

    if r <= self.m_size and self.m_data[r].timeout < self.m_data[min].timeout then
        min = r
    end

    if min ~= index then
        self:swap(index,min)
        self:Down(min)
    end
end

function minheap:Parent(index)
    local parent = math.modf(index/2)
    return parent
end

function minheap:Left(index)
    return 2*index
end

function minheap:Right(index)
    return 2*index + 1
end

function minheap:Change(o)
    local index = o.index
    if index == 0 then
        return
    end
    self:Down(index)
	if index == o.index then
		self:Up(index)
	end
end

function minheap:Insert(o)
    if o.index ~= 0 then
        return
    end
    self.m_size = self.m_size + 1
    table.insert(self.m_data,o)
    o.index = self.m_size
    self:Up(self.m_size)
end

function minheap:Min()
    if self.m_size == 0 then
        return 0
    end
    return self.m_data[1].timeout
end

function minheap:PopMin()
    local o = self.m_data[1]
    self:swap(1,self.m_size)
    self.m_data[self.m_size] = nil
    self.m_size = self.m_size - 1
    self:Down(1)
    o.index = 0
    return o
end

function minheap:Size()
    return self.m_size
end

function minheap:swap(idx1,idx2)
    local tmp = self.m_data[idx1]
    self.m_data[idx1] = self.m_data[idx2]
    self.m_data[idx2] = tmp

    self.m_data[idx1].index = idx1
    self.m_data[idx2].index = idx2
end

function minheap:Clear()
    while m_size > 0 do
        self:PopMin()
    end
    self.m_size = 0
end

return M