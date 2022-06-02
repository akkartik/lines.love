-- undo/redo by managing the sequence of events in the current session
-- based on https://github.com/akkartik/mu1/blob/master/edit/012-editor-undo.mu

-- Incredibly inefficient; we make a copy of lines on every single keystroke.
-- The hope here is that we're either editing small files or just reading large files.
-- TODO: highlight stuff inserted by any undo/redo operation
-- TODO: coalesce multiple similar operations

function record_undo_event(data)
  History[Next_history] = data
  Next_history = Next_history+1
  for i=Next_history,#History do
    History[i] = nil
  end
end

function undo_event()
  if Next_history > 1 then
--?     print('moving to history', Next_history-1)
    Next_history = Next_history-1
    local result = History[Next_history]
    return result
  end
end

function redo_event()
  if Next_history <= #History then
--?     print('restoring history', Next_history+1)
    local result = History[Next_history]
    Next_history = Next_history+1
    return result
  end
end

-- Make copies of objects; the rest of the app may mutate them in place, but undo requires immutable histories.
function snapshot()
  -- compare with App.initialize_globals
  local event = {
    screen_top=deepcopy(Screen_top1),
    selection=deepcopy(Selection1),
    cursor=deepcopy(Cursor1),
    current_drawing_mode=Drawing_mode,
    previous_drawing_mode=Previous_drawing_mode,
    zoom=Zoom,
    lines={},
    -- no filename; undo history is cleared when filename changes
  }
  -- deep copy lines without cached stuff like text fragments
  for _,line in ipairs(Lines) do
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
