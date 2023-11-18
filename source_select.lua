-- helpers for selecting portions of text

-- Return any intersection of the region from State.selection1 to State.cursor1 (or
-- current mouse, if mouse is pressed; or recent mouse if mouse is pressed and
-- currently over a drawing) with the region between {line=line_index, pos=apos}
-- and {line=line_index, pos=bpos}.
-- apos must be less than bpos. However State.selection1 and State.cursor1 can be in any order.
-- Result: positions spos,epos between apos,bpos.
function Text.clip_selection(State, line_index, apos, bpos)
  if State.selection1.line == nil then return nil,nil end
  -- min,max = sorted(State.selection1,State.cursor1)
  local minl,minp = State.selection1.line,State.selection1.pos
  local maxl,maxp
  if App.mouse_down(1) then
    maxl,maxp = Text.mouse_pos(State)
  else
    maxl,maxp = State.cursor1.line,State.cursor1.pos
  end
  if Text.lt1({line=maxl, pos=maxp},
              {line=minl, pos=minp}) then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  end
  -- check if intervals are disjoint
  if line_index < minl then return nil,nil end
  if line_index > maxl then return nil,nil end
  if line_index == minl and bpos <= minp then return nil,nil end
  if line_index == maxl and apos >= maxp then return nil,nil end
  -- compare bounds more carefully (start inclusive, end exclusive)
  local a_ge = Text.le1({line=minl, pos=minp}, {line=line_index, pos=apos})
  local b_lt = Text.lt1({line=line_index, pos=bpos}, {line=maxl, pos=maxp})
  if a_ge and b_lt then
    -- fully contained
    return apos,bpos
  elseif a_ge then
    assert(maxl == line_index, ('maxl %d not equal to line_index %d'):format(maxl, line_index))
    return apos,maxp
  elseif b_lt then
    assert(minl == line_index, ('minl %d not equal to line_index %d'):format(minl, line_index))
    return minp,bpos
  else
    assert(minl == maxl and minl == line_index, ('minl %d, maxl %d and line_index %d are not all equal'):format(minl, maxl, line_index))
    return minp,maxp
  end
end

-- draw highlight for line corresponding to (lo,hi) given an approximate x,y and pos on the same screen line
-- Creates text objects every time, so use this sparingly.
-- Returns some intermediate computation useful elsewhere.
function Text.draw_highlight(State, line, x,y, pos, lo,hi)
  if lo then
    local lo_offset = Text.offset(line.data, lo)
    local hi_offset = Text.offset(line.data, hi)
    local pos_offset = Text.offset(line.data, pos)
    local lo_px
    if pos == lo then
      lo_px = 0
    else
      local before = line.data:sub(pos_offset, lo_offset-1)
      lo_px = App.width(before)
    end
    local s = line.data:sub(lo_offset, hi_offset-1)
    App.color(Highlight_color)
    love.graphics.rectangle('fill', x+lo_px,y, App.width(s),State.line_height)
    App.color(Text_color)
    return lo_px
  end
end

function Text.mouse_pos(State)
  local x,y = App.mouse_x(), App.mouse_y()
  if y < State.line_cache[State.screen_top1.line].starty then
    return State.screen_top1.line, State.screen_top1.pos
  end
  for line_index,line in ipairs(State.lines) do
    if line.mode == 'text' then
      if Text.in_line(State, line_index, x,y) then
        return line_index, Text.to_pos_on_line(State, line_index, x,y)
      end
    end
  end
  return State.screen_bottom1.line, Text.pos_at_end_of_screen_line(State, State.screen_bottom1)
end

function Text.cut_selection(State)
  if State.selection1.line == nil then return end
  local result = Text.selection(State)
  Text.delete_selection(State)
  return result
end

function Text.delete_selection(State)
  if State.selection1.line == nil then return end
  local minl,maxl = minmax(State.selection1.line, State.cursor1.line)
  local before = snapshot(State, minl, maxl)
  Text.delete_selection_without_undo(State)
  record_undo_event(State, {before=before, after=snapshot(State, State.cursor1.line)})
end

function Text.delete_selection_without_undo(State)
  if State.selection1.line == nil then return end
  -- min,max = sorted(State.selection1,State.cursor1)
  local minl,minp = State.selection1.line,State.selection1.pos
  local maxl,maxp = State.cursor1.line,State.cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  -- update State.cursor1 and State.selection1
  State.cursor1.line = minl
  State.cursor1.pos = minp
  if Text.lt1(State.cursor1, State.screen_top1) then
    State.screen_top1.line = State.cursor1.line
    State.screen_top1.pos = Text.pos_at_start_of_screen_line(State, State.cursor1)
  end
  State.selection1 = {}
  -- delete everything between min (inclusive) and max (exclusive)
  Text.clear_screen_line_cache(State, minl)
  local min_offset = Text.offset(State.lines[minl].data, minp)
  local max_offset = Text.offset(State.lines[maxl].data, maxp)
  if minl == maxl then
--?     print('minl == maxl')
    State.lines[minl].data = State.lines[minl].data:sub(1, min_offset-1)..State.lines[minl].data:sub(max_offset)
    return
  end
  assert(minl < maxl, ('minl %d not < maxl %d'):format(minl, maxl))
  local rhs = State.lines[maxl].data:sub(max_offset)
  for i=maxl,minl+1,-1 do
    table.remove(State.lines, i)
    table.remove(State.line_cache, i)
  end
  State.lines[minl].data = State.lines[minl].data:sub(1, min_offset-1)..rhs
end

function Text.selection(State)
  if State.selection1.line == nil then return end
  -- min,max = sorted(State.selection1,State.cursor1)
  local minl,minp = State.selection1.line,State.selection1.pos
  local maxl,maxp = State.cursor1.line,State.cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  local min_offset = Text.offset(State.lines[minl].data, minp)
  local max_offset = Text.offset(State.lines[maxl].data, maxp)
  if minl == maxl then
    return State.lines[minl].data:sub(min_offset, max_offset-1)
  end
  assert(minl < maxl, ('minl %d not < maxl %d'):format(minl, maxl))
  local result = {State.lines[minl].data:sub(min_offset)}
  for i=minl+1,maxl-1 do
    if State.lines[i].mode == 'text' then
      table.insert(result, State.lines[i].data)
    end
  end
  table.insert(result, State.lines[maxl].data:sub(1, max_offset-1))
  return table.concat(result, '\n')
end
