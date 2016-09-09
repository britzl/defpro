--- This is the plain Lua version of DefPro. It should be used
-- from the command line to get profiler data from a running
-- Defold app.
-- It uses a normal TCP socket to connect to the profiler and do
-- an HTTP GET to the requested uri.

-- we need to write this line like this to make sure that the Defold
-- build pipeline doesn't pick this up as a require call and try
-- to find a file names socket.lua
--
-- @usage
-- 
--	local profiler = require "defpro.luaprofiler"
--	
--	profiler.capture(10, "localhost", function(frames)
--		-- do stuff with captured frames
--	end)


local socket = _G["require"]("socket") 

local M = require("defpro.profiler")

function M.http_get(host, port, uri)
	assert(host, "You must provide a host")
	assert(port, "You must provide a port")
	assert(uri, "You must provide a uri")

	local tcp_client = assert(socket.tcp())
	assert(tcp_client:connect(host, port))

	local request = ("GET %s HTTP/1.1\r\nHost: %s:%d\r\nAccept: */*\r\n\r\n"):format(uri, host, port)
	assert(tcp_client:send(request))

	-- read headers
	while true do
		local line = assert(tcp_client:receive("*l"))
		if line == "" then
			break
		end
	end

	-- read chunk length
	local line = assert(tcp_client:receive("*l"))
	local length = tonumber(line, 16)

	-- read chunk
	local chunk = assert(tcp_client:receive(length))
	assert(tcp_client:close())
	return chunk
end



return M