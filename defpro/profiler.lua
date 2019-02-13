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

local function dump(s)
	for i=1,#s do
		local b = s:byte(i)
		print(("#%d %d (%s)"):format(i, b, string.char(b)))
	end
end

local function mem_file(data)
	assert(data, "You must provide some data")
	local file = {}

	local offset = 1

	function file.read_uint8()
		local b = data:byte(offset)
		offset = offset + 1
		return b
	end
	
	function file.read_uint16()
		local lower = file.read_uint8()
		local upper = file.read_uint8()
		return bit.lshift(upper, 8) + lower
	end

	function file.read_uint32()
		local a4 = file.read_uint8()
		local a3 = file.read_uint8()
		local a2 = file.read_uint8()
		local a1 = file.read_uint8()
		return bit.lshift(a1, 24) + bit.lshift(a2, 16) + bit.lshift(a3, 8) + a4
	end

	function file.read_uint64()
		return file.read_uint32() .. file.read_uint32()
	end

	function file.read_string()
		local length = file.read_uint16()
		local s = data:sub(offset, offset + length - 1)
		offset = offset + length
		return s
	end

	function file.eof()
		return offset > #data
	end

	function file.offset()
		return offset
	end

	function file.data()
		return data
	end
		
	return file
end	


local function parse_strings(file)
	assert(file, "You must provide some data to parse")

	local strings = {}
	while not file.eof() do
		local id = file.read_uint64()
		local s = file.read_string()
		strings[id] = s
	end
	return strings
end

local function parse_frame(file, strings)
	assert(file, "You must provide some data to parse")
	assert(strings, "You must provide strings")

	ticks_per_second = file.read_uint32() / 1000

	local function is_end(file)
		local s = file.data():sub(file.offset() + 2, file.offset() + 5)
		return s == "ENDD"
	end
	
	local samples = {}
	local frame_time = 0
	while not file.eof() do
		if is_end(file) then
			break
		end

		local name_id = file.read_uint64()
		local scope_id = file.read_uint64()
		local start = file.read_uint32()
		local elapsed = file.read_uint32()
		local thread_id = file.read_uint16()

		frame_time = math.max(frame_time, elapsed / ticks_per_second)

		local name = strings[name_id] or "?name"
		local scope_name = strings[scope_id] or "?scope"

		local s = {
			scope_name = scope_name,
			name = scope_name .. "." .. name,
			start = start / ticks_per_second,
			elapsed = elapsed / ticks_per_second
		}
		table.insert(samples, s)
	end	

	file.read_string() -- ENDD

	local scopes_data = {}
	while not file.eof() do
		if is_end(file) then
			break
		end

		local name_id = file.read_uint64()
		local elapsed = file.read_uint32()
		local count = file.read_uint32()
		local name = strings[name_id] or "?name"
		scopes_data[name] = {
			elapsed = elapsed,
			count = count,
		}
	end	

	file.read_string() -- ENDD

	local counters_data = {}
	while not file.eof() do
		if is_end(file) then
			break
		end
		local name_id = file.read_uint64()
		local value = file.read_uint32()
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


local function parse_gameobjects(file)
	assert(file, "You must provide some data to parse")

	local game_objects = {}
	while not file.eof() do
		local game_object = {
			name = file.read_string(), 
			resource = file.read_string(),
			type = file.read_string(),
			index = file.read_uint32(),
			parent = file.read_uint32(),
			children = {}
		}
		game_objects[game_object.index] = game_object

		local p = game_objects[game_object.parent]
		if p then
			p.children[#p.children + 1] = game_object
		end
	end
	return game_objects
end

local function parse_resources(file)
	assert(file, "You must provide some data to parse")

	local resources = {}
	while not file.eof() do
		resources[#resources + 1] = {
			name = file.read_string(),
			type = file.read_string(),
			size = file.read_uint32(),
			size_on_disk = file.read_uint32(),
			ref_count = file.read_uint32()
		}
	end
	return resources
end

function M.http_get(host, port, uri)
	error("You need to replace this function stub with an actual implementation that does an HTTP GET") 
end


function M.capture(sample_count, host, callback)
	host = host or "localhost"
	sample_count = sample_count or 10
	local co = coroutine.create(function()
		local chunk = M.http_get(host, 8002, "/profile_strings")
		assert(chunk)
		local file = mem_file(chunk)
		assert(file.read_string() == "STRS")
		local strings = parse_strings(file)
		
		local frames = {}
		for i=1,sample_count do
			local chunk = M.http_get(host, 8002, "/profile_frame")
			assert(chunk)
			local file = mem_file(chunk)
			assert(file.read_string() == "PROF")
			local frame = parse_frame(file, strings)
			table.insert(frames, frame)
		end

		local chunk = M.http_get(host, 8002, "/gameobjects_data")
		assert(chunk)
		local file = mem_file(chunk)
		assert(file.read_string() == "GOBJ")
		local game_objects = parse_gameobjects(file)

		local chunk = M.http_get(host, 8002, "/resources_data")
		assert(chunk)
		local file = mem_file(chunk)
		assert(file.read_string() == "RESS")
		local resources = parse_resources(file)

		if callback then callback(frames, game_objects, resources) end
	end)
	local ok, err = coroutine.resume(co)
	if not ok then print(err) end
end

return M
