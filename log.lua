function log(stack_frame_index, obj)
	local info = debug.getinfo(stack_frame_index, 'Sl')
	local msg
	if type(obj) == 'string' then
		msg = obj
	else
		msg = json.encode(obj)
	end
	love.filesystem.append('log', info.short_src..':'..info.currentline..': '..msg..'\n')
end

-- for section delimiters we'll use specific Unicode box characters
function log_start(name, stack_frame_index)
	if stack_frame_index == nil then
		stack_frame_index = 3
	end
	-- I'd like to use the unicode character \u{250c} here, but it doesn't work
	-- in OpenBSD.
	log(stack_frame_index, '[ u250c ' .. name)
end
function log_end(name, stack_frame_index)
	if stack_frame_index == nil then
		stack_frame_index = 3
	end
	-- I'd like to use the unicode character \u{2518} here, but it doesn't work
	-- in OpenBSD.
	log(stack_frame_index, '] u2518 ' .. name)
end

function log_new(name, stack_frame_index)
	if stack_frame_index == nil then
		stack_frame_index = 4
	end
	log_end(name, stack_frame_index)
	log_start(name, stack_frame_index)
end

-- rendering graphical objects within sections/boxes
log_render = {}

-- vim:noexpandtab
