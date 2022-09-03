-- primitives for saving to file and loading from file

Fold = '\x1e'  -- ASCII RS (record separator)

function file_exists(filename)
  local infile = App.open_for_reading(filename)
  if infile then
    infile:close()
    return true
  else
    return false
  end
end

function load_from_disk(State)
  local infile = App.open_for_reading(State.filename)
  State.lines = load_from_file(infile)
  if infile then infile:close() end
end

function load_from_file(infile)
  local result = {}
  if infile then
    local infile_next_line = infile:lines()  -- works with both Lua files and LÖVE Files (https://www.love2d.org/wiki/File)
    while true do
      local line = infile_next_line()
      if line == nil then break end
      local line_info = {}
      if line:find(Fold) then
        _, _, line_info.data, line_info.dataB = line:find('([^'..Fold..']*)'..Fold..'([^'..Fold..']*)')
      else
        line_info.data = line
      end
      table.insert(result, line_info)
    end
  end
  if #result == 0 then
    table.insert(result, {data=''})
  end
  return result
end

function save_to_disk(State)
  local outfile = App.open_for_writing(State.filename)
  if outfile == nil then
    error('failed to write to "'..State.filename..'"')
  end
  for _,line in ipairs(State.lines) do
    outfile:write(line.data)
    if line.dataB and #line.dataB > 0 then
      outfile:write(Fold)
      outfile:write(line.dataB)
    end
    outfile:write('\n')
  end
  outfile:close()
end

function file_exists(filename)
  local infile = App.open_for_reading(filename)
  if infile then
    infile:close()
    return true
  else
    return false
  end
end

-- for tests
function load_array(a)
  local result = {}
  local next_line = ipairs(a)
  local i,line,drawing = 0, ''
  while true do
    i,line = next_line(a, i)
    if i == nil then break end
    local line_info = {}
    if line:find(Fold) then
      _, _, line_info.data, line_info.dataB = line:find('([^'..Fold..']*)'..Fold..'([^'..Fold..']*)')
    else
      line_info.data = line
    end
    table.insert(result, line_info)
  end
  if #result == 0 then
    table.insert(result, {data=''})
  end
  return result
end
