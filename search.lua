-- helpers for the search bar (C-f)

function Text.draw_search_bar(State)
  local h = State.line_height+2
  local y = App.screen.height-h
  love.graphics.setColor(0.9,0.9,0.9)
  love.graphics.rectangle('fill', 0, y-10, App.screen.width-1, h+8)
  love.graphics.setColor(0.6,0.6,0.6)
  love.graphics.line(0, y-10, App.screen.width-1, y-10)
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle('fill', 20, y-6, App.screen.width-40, h+2, 2,2)
  love.graphics.setColor(0.6,0.6,0.6)
  love.graphics.rectangle('line', 20, y-6, App.screen.width-40, h+2, 2,2)
  App.color(Text_color)
  App.screen.print(State.search_term, 25,y-5)
  Text.draw_cursor(State, 25+State.font:getWidth(State.search_term),y-5)
end

function Text.search_next(State)
  -- search current line from cursor
  local curr_pos = State.cursor1.pos
  local curr_line = State.lines[State.cursor1.line].data
  local curr_offset = Text.offset(curr_line, curr_pos)
  local offset = find(curr_line, State.search_term, curr_offset, --[[literal]] true)
  if offset then
    State.cursor1.pos = utf8.len(curr_line, 1, offset)
  end
  if offset == nil then
    -- search lines below cursor
    for i=State.cursor1.line+1,#State.lines do
      local curr_line = State.lines[i].data
      offset = find(curr_line, State.search_term, --[[from start]] nil, --[[literal]] true)
      if offset then
        State.cursor1 = {line=i, pos=utf8.len(curr_line, 1, offset)}
        break
      end
    end
  end
  if offset == nil then
    -- wrap around
    for i=1,State.cursor1.line-1 do
      local curr_line = State.lines[i].data
      offset = find(curr_line, State.search_term, --[[from start]] nil, --[[literal]] true)
      if offset then
        State.cursor1 = {line=i, pos=utf8.len(curr_line, 1, offset)}
        break
      end
    end
  end
  if offset == nil then
    -- search current line until cursor
    local curr_line = State.lines[State.cursor1.line].data
    offset = find(curr_line, State.search_term, --[[from start]] nil, --[[literal]] true)
    local pos = utf8.len(curr_line, 1, offset)
    if pos and pos < State.cursor1.pos then
      State.cursor1.pos = pos
    end
  end
  if offset == nil then
    State.cursor1.line = State.search_backup.cursor.line
    State.cursor1.pos = State.search_backup.cursor.pos
    State.screen_top1.line = State.search_backup.screen_top.line
    State.screen_top1.pos = State.search_backup.screen_top.pos
  end
  local screen_bottom1 = Text.screen_bottom1(State)
  if Text.lt1(State.cursor1, State.screen_top1) or Text.lt1(screen_bottom1, State.cursor1) then
    State.screen_top1.line = State.cursor1.line
    local pos = Text.pos_at_start_of_screen_line(State, State.cursor1)
    State.screen_top1.pos = pos
  end
end

function Text.search_previous(State)
  -- search current line before cursor
  local curr_pos = State.cursor1.pos
  local curr_line = State.lines[State.cursor1.line].data
  local curr_offset = Text.offset(curr_line, curr_pos)
  local offset = rfind(curr_line, State.search_term, curr_offset-1, --[[literal]] true)
  if offset then
    State.cursor1.pos = utf8.len(curr_line, 1, offset)
  end
  if offset == nil then
    -- search lines above cursor
    for i=State.cursor1.line-1,1,-1 do
      local curr_line = State.lines[i].data
      offset = rfind(curr_line, State.search_term, --[[from end]] nil, --[[literal]] true)
      if offset then
        State.cursor1 = {line=i, pos=utf8.len(curr_line, 1, offset)}
        break
      end
    end
  end
  if offset == nil then
    -- wrap around
    for i=#State.lines,State.cursor1.line+1,-1 do
      local curr_line = State.lines[i].data
      offset = rfind(curr_line, State.search_term, --[[from end]] nil, --[[literal]] true)
      if offset then
        State.cursor1 = {line=i, pos=utf8.len(curr_line, 1, offset)}
        break
      end
    end
  end
  if offset == nil then
    -- search current line after cursor
    local curr_line = State.lines[State.cursor1.line].data
    offset = rfind(curr_line, State.search_term, --[[from end]] nil, --[[literal]] true)
    local pos = utf8.len(curr_line, 1, offset)
    if pos and pos > State.cursor1.pos then
      State.cursor1.pos = pos
    end
  end
  if offset == nil then
    State.cursor1.line = State.search_backup.cursor.line
    State.cursor1.pos = State.search_backup.cursor.pos
    State.screen_top1.line = State.search_backup.screen_top.line
    State.screen_top1.pos = State.search_backup.screen_top.pos
  end
  local screen_bottom1 = Text.screen_bottom1(State)
  if Text.lt1(State.cursor1, State.screen_top1) or Text.lt1(screen_bottom1, State.cursor1) then
    State.screen_top1.line = State.cursor1.line
    local pos = Text.pos_at_start_of_screen_line(State, State.cursor1)
    State.screen_top1.pos = pos
  end
end

function find(s, pat, i, plain)
  if s == nil then return end
  return s:find(pat, i, plain)
end

-- TODO: avoid the expensive reverse() operations
-- Particularly if we only care about literal matches, we don't need all of string.find
function rfind(s, pat, i, plain)
  if s == nil then return end
  if #pat == 0 then return #s end
  local rs = s:reverse()
  local rpat = pat:reverse()
  if i == nil then i = #s end
  local ri = #s - i + 1
  local rendpos = rs:find(rpat, ri, plain)
  if rendpos == nil then return nil end
  local endpos = #s - rendpos + 1
  assert (endpos >= #pat, ('rfind: endpos %d should be >= #pat %d at this point'):format(endpos, #pat))
  return endpos-#pat+1
end

function test_rfind()
  check_eq(rfind('abc', ''), 3, 'empty pattern')
  check_eq(rfind('abc', 'c'), 3, 'final char')
  check_eq(rfind('acbc', 'c', 3), 2, 'previous char')
  check_nil(rfind('abc', 'd'), 'missing char')
  check_nil(rfind('abc', 'c', 2), 'no more char')
end
