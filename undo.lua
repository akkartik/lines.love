-- undo/redo by managing the sequence of events in the current session
-- based on https://github.com/akkartik/mu1/blob/master/edit/012-editor-undo.mu

-- Incredibly inefficient; we make a copy of lines on every single keystroke.
-- The hope here is that we're either editing small files or just reading large files.
-- TODO: highlight stuff inserted by any undo/redo operation
-- TODO: coalesce multiple similar operations

function record_undo_event(data)
  Editor_state.history[Editor_state.next_history] = data
  Editor_state.next_history = Editor_state.next_history+1
  for i=Editor_state.next_history,#Editor_state.history do
    Editor_state.history[i] = nil
  end
end

function undo_event()
  if Editor_state.next_history > 1 then
--?     print('moving to history', Editor_state.next_history-1)
    Editor_state.next_history = Editor_state.next_history-1
    local result = Editor_state.history[Editor_state.next_history]
    return result
  end
end

function redo_event()
  if Editor_state.next_history <= #Editor_state.history then
--?     print('restoring history', Editor_state.next_history+1)
    local result = Editor_state.history[Editor_state.next_history]
    Editor_state.next_history = Editor_state.next_history+1
    return result
  end
end

-- Copy all relevant global state.
-- Make copies of objects; the rest of the app may mutate them in place, but undo requires immutable histories.
function snapshot(s,e)
  -- Snapshot everything by default, but subset if requested.
  assert(s)
  if e == nil then
    e = s
  end
  assert(#Editor_state.lines > 0)
  if s < 1 then s = 1 end
  if s > #Editor_state.lines then s = #Editor_state.lines end
  if e < 1 then e = 1 end
  if e > #Editor_state.lines then e = #Editor_state.lines end
  -- compare with App.initialize_globals
  local event = {
    screen_top=deepcopy(Editor_state.screen_top1),
    selection=deepcopy(Editor_state.selection1),
    cursor=deepcopy(Editor_state.cursor1),
    current_drawing_mode=Drawing_mode,
    previous_drawing_mode=Editor_state.previous_drawing_mode,
    lines={},
    start_line=s,
    end_line=e,
    -- no filename; undo history is cleared when filename changes
  }
  -- deep copy lines without cached stuff like text fragments
  for i=s,e do
    local line = Editor_state.lines[i]
    if line.mode == 'text' then
      table.insert(event.lines, {mode='text', data=line.data})
    elseif line.mode == 'drawing' then
      local points=deepcopy(line.points)
--?       print('copying', line.points, 'with', #line.points, 'points into', points)
      local shapes=deepcopy(line.shapes)
--?       print('copying', line.shapes, 'with', #line.shapes, 'shapes into', shapes)
      table.insert(event.lines, {mode='drawing', y=line.y, h=line.h, points=points, shapes=shapes, pending={}})
--?       table.insert(event.lines, {mode='drawing', y=line.y, h=line.h, points=deepcopy(line.points), shapes=deepcopy(line.shapes), pending={}})
    else
      print(line.mode)
      assert(false)
    end
  end
  return event
end

function patch(lines, from, to)
--?   if #from.lines == 1 and #to.lines == 1 then
--?     assert(from.start_line == from.end_line)
--?     assert(to.start_line == to.end_line)
--?     assert(from.start_line == to.start_line)
--?     lines[from.start_line] = to.lines[1]
--?     return
--?   end
  assert(from.start_line == to.start_line)
  for i=from.end_line,from.start_line,-1 do
    table.remove(lines, i)
  end
  assert(#to.lines == to.end_line-to.start_line+1)
  for i=1,#to.lines do
    table.insert(lines, to.start_line+i-1, to.lines[i])
  end
end

-- https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value/26367080#26367080
function deepcopy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local result = setmetatable({}, getmetatable(obj))
  s[obj] = result
  for k,v in pairs(obj) do
    result[deepcopy(k, s)] = deepcopy(v, s)
  end
  return result
end

function minmax(a, b)
  return math.min(a,b), math.max(a,b)
end
