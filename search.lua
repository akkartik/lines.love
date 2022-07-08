-- helpers for the search bar (C-f)

function Text.draw_search_bar()
  local h = Line_height+2
  local y = App.screen.height-h
  love.graphics.setColor(0.9,0.9,0.9)
  love.graphics.rectangle('fill', 0, y-10, App.screen.width-1, h+8)
  love.graphics.setColor(0.6,0.6,0.6)
  love.graphics.line(0, y-10, App.screen.width-1, y-10)
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle('fill', 20, y-6, App.screen.width-40, h+2, 2,2)
  love.graphics.setColor(0.6,0.6,0.6)
  love.graphics.rectangle('line', 20, y-6, App.screen.width-40, h+2, 2,2)
  love.graphics.setColor(0,0,0)
  App.screen.print(Search_term, 25,y-5)
  love.graphics.setColor(1,0,0)
  if Search_text == nil then
    Search_text = App.newText(love.graphics.getFont(), Search_term)
  end
  love.graphics.circle('fill', 25+App.width(Search_text),y-5+h, 2)
  love.graphics.setColor(0,0,0)
end

function Text.search_next()
  -- search current line
  local pos = Lines[Cursor1.line].data:find(Search_term, Cursor1.pos)
  if pos then
    Cursor1.pos = pos
  end
  if pos == nil then
    for i=Cursor1.line+1,#Lines do
      pos = Lines[i].data:find(Search_term)
      if pos then
        Cursor1.line = i
        Cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    -- wrap around
    for i=1,Cursor1.line-1 do
      pos = Lines[i].data:find(Search_term)
      if pos then
        Cursor1.line = i
        Cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    Cursor1.line = Search_backup.cursor.line
    Cursor1.pos = Search_backup.cursor.pos
    Screen_top1.line = Search_backup.screen_top.line
    Screen_top1.pos = Search_backup.screen_top.pos
  end
  if Text.lt1(Cursor1, Screen_top1) or Text.lt1(Screen_bottom1, Cursor1) then
    Screen_top1.line = Cursor1.line
    local _, pos = Text.pos_at_start_of_cursor_screen_line(Margin_left, App.screen.width-Margin_right)
    Screen_top1.pos = pos
  end
end

function Text.search_previous()
  -- search current line
  local pos = rfind(Lines[Cursor1.line].data, Search_term, Cursor1.pos)
  if pos then
    Cursor1.pos = pos
  end
  if pos == nil then
    for i=Cursor1.line-1,1,-1 do
      pos = rfind(Lines[i].data, Search_term)
      if pos then
        Cursor1.line = i
        Cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    -- wrap around
    for i=#Lines,Cursor1.line+1,-1 do
      pos = rfind(Lines[i].data, Search_term)
      if pos then
        Cursor1.line = i
        Cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    Cursor1.line = Search_backup.cursor.line
    Cursor1.pos = Search_backup.cursor.pos
    Screen_top1.line = Search_backup.screen_top.line
    Screen_top1.pos = Search_backup.screen_top.pos
  end
  if Text.lt1(Cursor1, Screen_top1) or Text.lt1(Screen_bottom1, Cursor1) then
    Screen_top1.line = Cursor1.line
    local _, pos = Text.pos_at_start_of_cursor_screen_line(Margin_left, App.screen.width-Margin_right)
    Screen_top1.pos = pos
  end
end

function rfind(s, pat, i)
  local rs = s:reverse()
  local rpat = pat:reverse()
  if i == nil then i = #s end
  local ri = #s - i + 1
  local rendpos = rs:find(rpat, ri)
  if rendpos == nil then return nil end
  local endpos = #s - rendpos + 1
  assert (endpos >= #pat)
  return endpos-#pat+1
end
