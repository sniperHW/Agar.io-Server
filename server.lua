package.path = './lib/?.lua;./Agar.io-Server/?.lua'
package.cpath = './lib/?.so;'

math.randomseed(os.time())

local chuck = require("chuck")
local socket = chuck.socket
local buffer = chuck.buffer
local packet = chuck.packet
event_loop = chuck.event_loop.New()
local log = chuck.log
logger = log.CreateLogfile("Agar.io")

local addr = socket.addr(socket.AF_INET,"0.0.0.0",9100)

local user = require("user")

local server = socket.stream.listen(event_loop,addr,function (fd)
	local conn = socket.stream.socket(fd,4096,packet.Decoder(4096))
	if conn then
		conn:Start(event_loop,function (msg)
			if msg then
				local reader = packet.Reader(msg)
				msg = reader:ReadTable()
				user.OnClientMsg(conn,msg)
			else
				log.SysLog(log.info,"client disconnected") 
				conn:Close()
				user.OnClientDisconnected(conn) 
			end
		end)
	end
end)


if server then
	log.SysLog(log.info,"server start")	
	local timer1 = event_loop:AddTimer(1000,function ()
		collectgarbage("collect")
	end)	
	event_loop:WatchSignal(chuck.signal.SIGINT,function()
		log.SysLog(log.info,"recv SIGINT stop server")
		event_loop:Stop()
	end)	
	event_loop:Run()
end
