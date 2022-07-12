-- helpers for selecting portions of text

-- Return any intersection of the region from Editor_state.selection1 to Editor_state.cursor1 (or
-- current mouse, if mouse is pressed; or recent mouse if mouse is pressed and
-- currently over a drawing) with the region between {line=line_index, pos=apos}
-- and {line=line_index, pos=bpos}.
-- apos must be less than bpos. However Editor_state.selection1 and Editor_state.cursor1 can be in any order.
-- Result: positions spos,epos between apos,bpos.
function Text.clip_selection(line_index, apos, bpos, left, right)
  if Editor_state.selection1.line == nil then return nil,nil end
  -- min,max = sorted(Editor_state.selection1,Editor_state.cursor1)
  local minl,minp = Editor_state.selection1.line,Editor_state.selection1.pos
  local maxl,maxp
  if App.mouse_down(1) then
    maxl,maxp = Text.mouse_pos(left, right)
  else
    maxl,maxp = Editor_state.cursor1.line,Editor_state.cursor1.pos
  end
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  -- check if intervals are disjoint
  if line_index < minl then return nil,nil end
  if line_index > maxl then return nil,nil end
  if line_index == minl and bpos <= minp then return nil,nil end
  if line_index == maxl and apos >= maxp then return nil,nil end
  -- compare bounds more carefully (start inclusive, end exclusive)
  local a_ge = Text.le1({line=minl, pos=minp}, {line=line_index, pos=apos})
  local b_lt = Text.lt1({line=line_index, pos=bpos}, {line=maxl, pos=maxp})
--?   print(minl,line_index,maxl, '--', minp,apos,bpos,maxp, '--', a_ge,b_lt)
  if a_ge and b_lt then
    -- fully contained
    return apos,bpos
  elseif a_ge then
    assert(maxl == line_index)
    return apos,maxp
  elseif b_lt then
    assert(minl == line_index)
    return minp,bpos
  else
    assert(minl == maxl and minl == line_index)
    return minp,maxp
  end
end

-- draw highlight for line corresponding to (lo,hi) given an approximate x,y and pos on the same screen line
-- Creates text objects every time, so use this sparingly.
-- Returns some intermediate computation useful elsewhere.
function Text.draw_highlight(line, x,y, pos, lo,hi)
  if lo then
    local lo_offset = Text.offset(line.data, lo)
    local hi_offset = Text.offset(line.data, hi)
    local pos_offset = Text.offset(line.data, pos)
    local lo_px
    if pos == lo then
      lo_px = 0
    else
      local before = line.data:sub(pos_offset, lo_offset-1)
      local before_text = App.newText(love.graphics.getFont(), before)
      lo_px = App.width(before_text)
    end
--?     print(lo,pos,hi, '--', lo_offset,pos_offset,hi_offset, '--', lo_px)
    local s = line.data:sub(lo_offset, hi_offset-1)
    local text = App.newText(love.graphics.getFont(), s)
    local text_width = App.width(text)
    App.color(Highlight_color)
    love.graphics.rectangle('fill', x+lo_px,y, text_width,Editor_state.line_height)
    App.color(Text_color)
    return lo_px
  end
end

-- inefficient for some reason, so don't do it on every frame
function Text.mouse_pos(left, right)
  local time = love.timer.getTime()
  if Editor_state.recent_mouse.time and Editor_state.recent_mouse.time > time-0.1 then
    return Editor_state.recent_mouse.line, Editor_state.recent_mouse.pos
  end
  Editor_state.recent_mouse.time = time
  local line,pos = Text.to_pos(App.mouse_x(), App.mouse_y(), left, right)
  if line then
    Editor_state.recent_mouse.line = line
    Editor_state.recent_mouse.pos = pos
  end
  return Editor_state.recent_mouse.line, Editor_state.recent_mouse.pos
end

function Text.to_pos(x,y, left, right)
  for line_index,line in ipairs(Editor_state.lines) do
    if line.mode == 'text' then
      if Text.in_line(line, x,y, left, right) then
        return line_index, Text.to_pos_on_line(line, x,y, left, right)
      end
    end
  end
end

function Text.cut_selection(left, right)
  if Editor_state.selection1.line == nil then return end
  local result = Text.selection()
  Text.delete_selection(left, right)
  return result
end

function Text.delete_selection(left, right)
  if Editor_state.selection1.line == nil then return end
  local minl,maxl = minmax(Editor_state.selection1.line, Editor_state.cursor1.line)
  local before = snapshot(minl, maxl)
  Text.delete_selection_without_undo(left, right)
  record_undo_event({before=before, after=snapshot(Editor_state.cursor1.line)})
end

function Text.delete_selection_without_undo(left, right)
  if Editor_state.selection1.line == nil then return end
  -- min,max = sorted(Editor_state.selection1,Editor_state.cursor1)
  local minl,minp = Editor_state.selection1.line,Editor_state.selection1.pos
  local maxl,maxp = Editor_state.cursor1.line,Editor_state.cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  -- update Editor_state.cursor1 and Editor_state.selection1
  Editor_state.cursor1.line = minl
  Editor_state.cursor1.pos = minp
  if Text.lt1(Editor_state.cursor1, Editor_state.screen_top1) then
    Editor_state.screen_top1.line = Editor_state.cursor1.line
    _,Editor_state.screen_top1.pos = Text.pos_at_start_of_cursor_screen_line(left, right)
  end
  Editor_state.selection1 = {}
  -- delete everything between min (inclusive) and max (exclusive)
  Text.clear_cache(Editor_state.lines[minl])
  local min_offset = Text.offset(Editor_state.lines[minl].data, minp)
  local max_offset = Text.offset(Editor_state.lines[maxl].data, maxp)
  if minl == maxl then
--?     print('minl == maxl')
    Editor_state.lines[minl].data = Editor_state.lines[minl].data:sub(1, min_offset-1)..Editor_state.lines[minl].data:sub(max_offset)
    return
  end
  assert(minl < maxl)
  local rhs = Editor_state.lines[maxl].data:sub(max_offset)
  for i=maxl,minl+1,-1 do
    table.remove(Editor_state.lines, i)
  end
  Editor_state.lines[minl].data = Editor_state.lines[minl].data:sub(1, min_offset-1)..rhs
end

function Text.selection()
  if Editor_state.selection1.line == nil then return end
  -- min,max = sorted(Editor_state.selection1,Editor_state.cursor1)
  local minl,minp = Editor_state.selection1.line,Editor_state.selection1.pos
  local maxl,maxp = Editor_state.cursor1.line,Editor_state.cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  local min_offset = Text.offset(Editor_state.lines[minl].data, minp)
  local max_offset = Text.offset(Editor_state.lines[maxl].data, maxp)
  if minl == maxl then
    return Editor_state.lines[minl].data:sub(min_offset, max_offset-1)
  end
  assert(minl < maxl)
  local result = {Editor_state.lines[minl].data:sub(min_offset)}
  for i=minl+1,maxl-1 do
    if Editor_state.lines[i].mode == 'text' then
      table.insert(result, Editor_state.lines[i].data)
    end
  end
  table.insert(result, Editor_state.lines[maxl].data:sub(1, max_offset-1))
  return table.concat(result, '\n')
end
