package.path = './lib/?.lua;./Agar.io-Server/?.lua'
package.cpath = './lib/?.so;'
local chuck = require("chuck")
local socket = chuck.socket
local packet = chuck.packet


local event_loop = chuck.event_loop.New()

local msgHandler = {}

msgHandler.Login = function (conn,msg)
	print("Login OK")
	local buff = chuck.buffer.New()
	local w = packet.Writer(buff)
	w:WriteTable({cmd="EnterBattle"})
	conn:Send(buff)	
end

msgHandler.ServerTick = function (conn,msg)
	print("ServerTick")
end

msgHandler.BeginSee = function (conn,msg)
	print("BeginSee")
end



local function main()
	if not arg then
		print("useage lua testclient.lua ip port userID")
	else
		socket.stream.ip4.dail(event_loop,arg[1],arg[2],function (fd,errCode)
			if errCode then
				print("connect error:" .. errCode)
				return
			end
			local conn = socket.stream.New(fd,4096,packet.Decoder(65536))
			if conn then
				conn:Start(event_loop,function (msg)
					if msg then
						local reader = packet.Reader(msg)
						msg = reader:ReadTable()
						local handler = msgHandler[msg.cmd]
						if handler then
							handler(conn,msg)
						end
					else
						conn:Close()
					end
				end)
				--发送login
				local buff = chuck.buffer.New()
				local w = packet.Writer(buff)
				w:WriteTable({cmd="Login",userID=arg[3]})
				conn:Send(buff)
			end
		end)
		

		event_loop:WatchSignal(chuck.signal.SIGINT,function()
			print("recv SIGINT stop client")
			event_loop:Stop()
		end)

		event_loop:Run()

	end

end

main()