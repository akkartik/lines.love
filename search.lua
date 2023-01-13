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
  if State.search_text == nil then
    State.search_text = App.newText(love.graphics.getFont(), State.search_term)
  end
  Text.draw_cursor(State, 25+App.width(State.search_text),y-5)
end

function Text.search_next(State)
  -- search current line from cursor
  local pos = find(State.lines[State.cursor1.line].data, State.search_term, State.cursor1.pos, --[[literal]] true)
  if pos then
    State.cursor1.pos = pos
  end
  if pos == nil then
    -- search lines below cursor
    for i=State.cursor1.line+1,#State.lines do
      pos = find(State.lines[i].data, State.search_term, --[[from start]] nil, --[[literal]] true)
      if pos then
        State.cursor1 = {line=i, pos=pos}
        break
      end
    end
  end
  if pos == nil then
    -- wrap around
    for i=1,State.cursor1.line-1 do
      pos = find(State.lines[i].data, State.search_term, --[[from start]] nil, --[[literal]] true)
      if pos then
        State.cursor1 = {line=i, pos=pos}
        break
      end
    end
  end
  if pos == nil then
    -- search current line until cursor
    pos = find(State.lines[State.cursor1.line].data, State.search_term, --[[from start]] nil, --[[literal]] true)
    if pos and pos < State.cursor1.pos then
      State.cursor1.pos = pos
    end
  end
  if pos == nil then
    State.cursor1.line = State.search_backup.cursor.line
    State.cursor1.pos = State.search_backup.cursor.pos
    State.screen_top1.line = State.search_backup.screen_top.line
    State.screen_top1.pos = State.search_backup.screen_top.pos
  end
  if Text.lt1(State.cursor1, State.screen_top1) or Text.lt1(State.screen_bottom1, State.cursor1) then
    State.screen_top1.line = State.cursor1.line
    local pos = Text.pos_at_start_of_screen_line(State, State.cursor1)
    State.screen_top1.pos = pos
  end
end

function Text.search_previous(State)
  -- search current line before cursor
  local pos = rfind(State.lines[State.cursor1.line].data, State.search_term, State.cursor1.pos-1, --[[literal]] true)
  if pos then
    State.cursor1.pos = pos
  end
  if pos == nil then
    -- search lines above cursor
    for i=State.cursor1.line-1,1,-1 do
      pos = rfind(State.lines[i].data, State.search_term, --[[from end]] nil, --[[literal]] true)
      if pos then
        State.cursor1 = {line=i, pos=pos}
        break
      end
    end
  end
  if pos == nil then
    -- wrap around
    for i=#State.lines,State.cursor1.line+1,-1 do
      pos = rfind(State.lines[i].data, State.search_term, --[[from end]] nil, --[[literal]] true)
      if pos then
        State.cursor1 = {line=i, pos=pos}
        break
      end
    end
  end
  if pos == nil then
    -- search current line after cursor
    pos = rfind(State.lines[State.cursor1.line].data, State.search_term, --[[from end]] nil, --[[literal]] true)
    if pos and pos > State.cursor1.pos then
      State.cursor1.pos = pos
    end
  end
  if pos == nil then
    State.cursor1.line = State.search_backup.cursor.line
    State.cursor1.pos = State.search_backup.cursor.pos
    State.screen_top1.line = State.search_backup.screen_top.line
    State.screen_top1.pos = State.search_backup.screen_top.pos
  end
  if Text.lt1(State.cursor1, State.screen_top1) or Text.lt1(State.screen_bottom1, State.cursor1) then
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
  local rs = s:reverse()
  local rpat = pat:reverse()
  if i == nil then i = #s end
  local ri = #s - i + 1
  local rendpos = rs:find(rpat, ri, plain)
  if rendpos == nil then return nil end
  local endpos = #s - rendpos + 1
  assert (endpos >= #pat)
  return endpos-#pat+1
end
