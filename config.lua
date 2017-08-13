local M = {}

M.screenSizeFactor = 30.0
M.initScore = 10
M.maxScore = 100000
M.sp0 = 14
M.starScore = 1
M.maxUserBallCount = 16
M.spitV0Factor = 3.2
M.splitV0Factor	= 25.0
M.spitDuration = 0.8
M.splitDuration	= 0.8
M.mapWidth = 10000
M.colors = {
	{0.85,0.40,0.79,1},
	{0.80,0.92,0.20,1},
	{0.34,0.77,0.28,1},
	{0.56,0.48,0.63,1},
	{0.37,0.52,0.96,1},
	{0.92,0.64,0.72,1},
	{0.15,0.61,0.02,1},
	{0.25,0.14,0.81,1},
	{0.16,0.41,0.13,1},
	{0.11,1.00,0.22,1},
	{0.52,0.84,0.62,1},
	{0.30,0.64,0.53,1},
	{0.50,0.98,0.30,1},
	{0.78,0.53,0.77,1},
	{0.41,0.90,0.29,1},
	{0.36,0.81,0.92,1},
	{0.07,0.95,0.53,1},
	{0.09,0.20,0.67,1},
	{0.90,0.35,0.07,1},
	{0.03,0.46,0.07,1},
	{0.24,0.98,0.91,1},	
}

local function min(a,b)
	return a < b and b or a
end

function M.Score2R(score)
	return math.sqrt((score * 0.165 + 0.6)) * 50.0 * 0.01 * M.screenSizeFactor
end

function M.SpeedByR(r,speedLev)
	speedLev = speedLev or 1.0
	r = r / M.screenSizeFactor
	return 1.6 * min(5.0, 9.0 / (r + 1.0) + 0.7) * M.screenSizeFactor * speedLev
end

function M.EatFactor(score)
	if score <= 20.0 then
		return 1.3
	elseif score >= 10000.0 then
		return 1.05
	else
		return (-0.000025)*score + 1.3
	end
end


return M