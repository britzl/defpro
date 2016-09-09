local socket = _G["require"]("socket")

local M = require("defpro.profiler")

function M.http_get(host, port, uri)
	assert(host, "You must provide a host")
	assert(port, "You must provide a port")
	assert(uri, "You must provide a uri")

	local tcp_client = socket.try(socket.tcp())
	socket.try(tcp_client:connect(host, port))

	local request = ("GET %s HTTP/1.1\r\nHost: %s:%d\r\nAccept: */*\r\n\r\n"):format(uri, host, port)
	socket.try(tcp_client:send(request))

	-- read headers
	while true do
		local line = socket.try(tcp_client:receive("*l"))
		if line == "" then
			break
		end
	end

	-- read chunk length
	local line = socket.try(tcp_client:receive("*l"))
	local length = tonumber(line, 16)

	-- read chunk
	local chunk = socket.try(tcp_client:receive(length))
	socket.try(tcp_client:close())
	return chunk
end



return M