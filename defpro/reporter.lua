local M = {}

local ticks_per_second = 1000


function M.print_scope_data(frame)
	assert(frame, "You must provide frame data")
	print("+----------------------------+")
	print(("| %-15s|%10s |"):format("Scope", "Time(ms)"))
	print("+----------------------------+")
	for name,sd in pairs(frame.scopes_data) do
		local e = 100 * sd.elapsed / ticks_per_second / 100
		print(("| %-15s|%10.3f |"):format(name, e))
	end
	print("+----------------------------+")
end



function M.print_sample_data(frame)
	assert(frame, "You must provide frame data")
	local sum = {}
	for _,s in ipairs(frame.samples) do
		if not sum[s.name] then
			sum[s.name] = { elapsed = s.elapsed, count = 1, name = s.scope_name, last_sample = s }
		else
			local tmp = sum[s.name]
			local last_sample = tmp.last_sample
			local end_last = last_sample.start + last_sample.elapsed
			if s.start < last_sample.start and s.start >= end_last then
				tmp = { elapsed = tmp.elapsed + s.elapsed, count = tmp.count + 1, name = tmp.name, last_sample = s }
				sum[s.name] = tmp
			end
		end
	end

	print("+--------------------------------------------+")
	print(("| %-25s|%10s |   # |"):format("Sample", "Time(ms)"))
	print("+--------------------------------------------+")
	for name,tmp in pairs(sum) do
		local e = (100 * tmp.elapsed) / 100
		if e >= 0.03 then
			print(("| %-25s|%10.3f | %3d |"):format(name, e, tmp.count))
		end
	end
	print("+--------------------------------------------+")
end


function M.print_counters_data(frame)
	assert(frame, "You must provide frame data")
	print("+-------------------------------------+")
	print(("| %-25s| %8s |"):format("Counter", "Count"))
	print("+-------------------------------------+")
	for name,cd in pairs(frame.counters_data) do
		print(("| %-25s| %8d |"):format(name, cd.value))
	end
	print("+-------------------------------------+")
end



function M.get_counters(frame, string_format, ...)
	assert(frame, "You must provide frame data")
	
	local counters = {}
	for _,name in ipairs({...}) do
		local cd = frame.counters_data[name]
		if cd then
			table.insert(counters, string_format:format(name, cd.value))
		end
	end
	return table.concat(counters, "\n")
end


return M