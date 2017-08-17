local config = require("config")
math.randomseed(os.time())

print("M.stars = {")

for i = 1,2048 do
	print(string.format("	{x=%d,y=%d,color=%d},",math.random(1,config.mapWidth),math.random(1,config.mapWidth),math.random(1,#config.colors)))
end

print("}")