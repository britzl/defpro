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

	local response_handler = nil
	response_handler = function(self, id, response)
		if response.status == 302 then
			-- The gsub() is a temp fix for broken header parsing in Defold 1.2.143
			-- where the http client always expects a space between the colon and the
			-- header value
			url = response.headers.location:gsub("^ttp", "http")
			http.request(url, "GET", response_handler)
		else
			local ok, err = coroutine.resume(co, response.response)
			if not ok then print(err) end
		end
	end
	http.request(url, "GET", response_handler)
	return coroutine.yield()
end

return M