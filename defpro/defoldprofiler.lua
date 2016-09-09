--- This is the Defold version of DefPro. This should be used when
-- accessing profiler data from within a running Defold app. 

local M = require "defpro.profiler"

function M.http_get(host, port, uri)
	assert(host, "You must provide a host")
	assert(port, "You must provide a port")
	assert(uri, "You must provide a uri")

	local co = coroutine.running()
	assert(co, "You must call this function from within a coroutine")
	
	local url = ("http://%s:%d%s"):format(host, port, uri)
	http.request(url, "GET", function(self, id, response)
		coroutine.resume(co, response.response)
	end)
	return coroutine.yield()
end

return M