--- This is the core of the profiler. It is responsible for
-- getting and parsing profiling data from a running Defold app.
-- It should not be used by itself since it doesn't provide any
-- code to do the actual HTTP request to the Defold profiler to
-- get profiling data. You need to replace the @{http_get} function
-- with your own implementation to do the actual request.
-- This project provides two implementations of the http_get()
-- function, one using Defold's http.request() function and one
-- using LuaSocket
 
local bit = _G.bit32 or _G.bit
if not bit then
	error("You need either bit or bit32 module")
end

local M = {}

local ticks_per_second = 1000


local function read_uint16(d, offset)
	assert(d, "You must provide some data to parse")
	assert(offset, "You must provide an offset")
	--print("read_uint16", offset)
	local a1 = d:byte(offset + 1)
	local a2 = d:byte(offset)
	return bit.lshift(a1, 8) + a2
end

local function read_uint32(d, offset)
	assert(d, "You must provide some data to parse")
	assert(offset, "You must provide an offset")
	--print("read_uint32", offset)
	local a1 = d:byte(offset + 3)
	local a2 = d:byte(offset + 2)
	local a3 = d:byte(offset + 1)
	local a4 = d:byte(offset + 0)
	return bit.lshift(a1, 24) + bit.lshift(a2, 16) + bit.lshift(a3, 8) + a4
end

local function read_ptr(d, offset, size)
	assert(d, "You must provide some data to parse")
	assert(offset, "You must provide an offset")
	assert(size, "You must provide a size")
	return d:sub(offset, offset + size - 1)
end

local function parse_strings(d)
	assert(d, "You must provide some data to parse")

	local strings = {}
	local ptr_size = read_uint16(d, 1)
	local str_count = read_uint32(d, 3)

	local offset = 7
	for i=1,str_count do
		local id = read_ptr(d, offset, ptr_size); offset = offset + ptr_size
		local length = read_uint16(d, offset); offset = offset + 2
		strings[id] = d:sub(offset, offset + length - 1)
		offset = offset + length
	end
	return strings
end

local function parse_frame(d, strings)
	assert(d, "You must provide some data to parse")
	assert(strings, "You must provide strings")

	local offset = 1
	local ptr_size = read_uint16(d, offset); offset = offset + 2
	local ticks_per_second = read_uint32(d, offset); offset = offset + 4

	local samples = {}
	local sample_count = read_uint32(d, offset); offset = offset + 4
	local frame_time = 0
	for i=1, sample_count do
		local name_id = read_ptr(d, offset, ptr_size); offset = offset + ptr_size
		local scope = read_ptr(d, offset, ptr_size); offset = offset + ptr_size

		local start = read_uint32(d, offset); offset = offset + 4
		local elapsed = read_uint32(d, offset); offset = offset + 4
		local thread_id = read_uint16(d, offset); offset = offset + 2
		local name = strings[name_id] or "?"
		local scope_name = strings[scope] or "?"
		offset = offset + 6

		frame_time = math.max(frame_time, elapsed / ticks_per_second)

		local s = {
			scope_name = scope_name,
			name = scope_name .. "." .. name,
			start = start / ticks_per_second,
			elapsed = elapsed / ticks_per_second
		}
		table.insert(samples, s)
	end

	local scopes_data = {}
	local scope_count = read_uint32(d, offset); offset = offset + 4
	for i=1,scope_count do
		local name_id = read_ptr(d, offset, ptr_size); offset = offset + ptr_size
		local elapsed = read_uint32(d, offset); offset = offset + 4
		local count = read_uint32(d, offset); offset = offset + 4
		local name = strings[name_id]
		scopes_data[name] = {
			elapsed = elapsed,
			count = count,
		}
	end

	local counters_data = {}
	local counter_count = read_uint32(d, offset); offset = offset + 4
	for i=1,counter_count do
		local name_id = read_ptr(d, offset, ptr_size); offset = offset + ptr_size
		local value = read_uint32(d, offset); offset = offset + 4
		-- the struct is padded on 64 bit systems
		if ptr_size == 8 then
			offset = offset + 4
		end
		local name = strings[name_id]
		counters_data[name] = {
			value = value,
		}
	end

	return {
		samples = samples,
		frame_time = frame_time,
		scopes_data = scopes_data,
		counters_data = counters_data,
	}
end


function M.http_get(host, port, uri)
	error("You need to replace this function stub with an actual implementation that does an HTTP GET") 
end


function M.capture(sample_count, host, callback)
	host = host or "localhost"
	sample_count = sample_count or 10
	coroutine.wrap(function()
		local chunk = M.http_get(host, 8002, "/strings")
		assert(chunk)
		local strings = parse_strings(chunk:sub(5))
		
		local frames = {}
		for i=1,sample_count do
			local chunk = M.http_get(host, 8002, "/profile")
			local frame = parse_frame(chunk:sub(5), strings)
			table.insert(frames, frame)
		end
	
		if callback then callback(frames) end
	end)()
end

return M
