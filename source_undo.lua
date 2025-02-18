-- undo/redo by managing the sequence of events in the current session
-- based on https://github.com/akkartik/mu1/blob/master/edit/012-editor-undo.mu

-- Incredibly inefficient; we make a copy of lines on every single keystroke.
-- The hope here is that we're either editing small files or just reading large files.
-- TODO: highlight stuff inserted by any undo/redo operation
-- TODO: coalesce multiple similar operations

function record_undo_event(State, data)
  State.history[State.next_history] = data
  State.next_history = State.next_history+1
  for i=State.next_history,#State.history do
    State.history[i] = nil
  end
end

function undo_event(State)
  if State.next_history > 1 then
--?     print('moving to history', State.next_history-1)
    State.next_history = State.next_history-1
    local result = State.history[State.next_history]
    return result
  end
end

function redo_event(State)
  if State.next_history <= #State.history then
--?     print('restoring history', State.next_history+1)
    local result = State.history[State.next_history]
    State.next_history = State.next_history+1
    return result
  end
end

-- Copy all relevant global state.
-- Make copies of objects; the rest of the app may mutate them in place, but undo requires immutable histories.
function snapshot(State, s,e)
  -- Snapshot everything by default, but subset if requested.
  assert(s, 'failed to snapshot operation for undo history')
  if e == nil then
    e = s
  end
  assert(#State.lines > 0, 'failed to snapshot operation for undo history')
  if s < 1 then s = 1 end
  if s > #State.lines then s = #State.lines end
  if e < 1 then e = 1 end
  if e > #State.lines then e = #State.lines end
  -- compare with App.initialize_globals
  local event = {
    screen_top=deepcopy(State.screen_top1),
    selection=deepcopy(State.selection1),
    cursor=deepcopy(State.cursor1),
    current_drawing_mode=Drawing_mode,
    previous_drawing_mode=State.previous_drawing_mode,
    lines={},
    start_line=s,
    end_line=e,
    -- no filename; undo history is cleared when filename changes
  }
  for i=s,e do
    table.insert(event.lines, deepcopy(State.lines[i]))
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
  assert(from.start_line == to.start_line, 'failed to patch undo operation')
  for i=from.end_line,from.start_line,-1 do
    table.remove(lines, i)
  end
  assert(#to.lines == to.end_line-to.start_line+1, 'failed to patch undo operation')
  for i=1,#to.lines do
    table.insert(lines, to.start_line+i-1, to.lines[i])
  end
end

-- https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value/26367080#26367080
function deepcopy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  seen = seen or {}
  if seen[obj] then return seen[obj] end
  local result = setmetatable({}, getmetatable(obj))
  seen[obj] = result
  for k,v in pairs(obj) do
    result[deepcopy(k, seen)] = deepcopy(v, seen)
  end
  return result
end

function minmax(a, b)
  return math.min(a,b), math.max(a,b)
end
