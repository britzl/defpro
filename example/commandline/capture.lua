local profiler = require "defpro.luaprofiler"
local reporter = require "defpro.reporter"

local waiting = true

-- get profiler data async
profiler.capture(10, "127.0.0.1", function(frames)
	reporter.print_scope_data(frames[1])
	reporter.print_sample_data(frames[1])
	reporter.print_counters_data(frames[1])
	waiting = false
end)

-- wait for profiler data
while waiting do
	socket.sleep(0.1)
end