-- primitives for editing text
Text = {}

local utf8 = require 'utf8'

local New_render = true

function Text.draw(line, line_width, line_index)
  love.graphics.setColor(0,0,0)
  -- wrap long lines
  local x = 25
  local y = line.y
  local pos = 1
  if line.fragments == nil then
    Text.compute_fragments(line, line_width)
  end
  line.screen_line_starting_pos = nil
  if New_render then print('--') end
  for _, f in ipairs(line.fragments) do
    local frag, frag_text = f.data, f.text
    -- render fragment
    local frag_width = math.floor(frag_text:getWidth()*Zoom)
    if x + frag_width > line_width then
      assert(x > 25)  -- no overfull lines
      if line_index > Screen_top_line or pos > Top_screen_line_starting_pos then
        y = y + math.floor(15*Zoom)
        if New_render then print('y', y) end
      end
      if y > Screen_height then
        if line.screen_line_starting_pos then
          Bottom_screen_line_starting_pos = line.screen_line_starting_pos[#line.screen_line_starting_pos]
        else
          Bottom_screen_line_starting_pos = 1
        end
      end
      x = 25
      if line.screen_line_starting_pos == nil then
        line.screen_line_starting_pos = {1, pos}
      else
        table.insert(line.screen_line_starting_pos, pos)
      end
    end
    if New_render then print('checking to draw', pos, Top_screen_line_starting_pos) end
    if line_index > Screen_top_line or pos >= Top_screen_line_starting_pos then
      if New_render then print('drawing '..frag) end
      love.graphics.draw(frag_text, x,y, 0, Zoom)
    end
    -- render cursor if necessary
    local frag_len = utf8.len(frag)
    if line_index == Cursor_line then
      if pos <= Cursor_pos and pos + frag_len > Cursor_pos then
        Text.draw_cursor(x+Text.cursor_x2(frag, Cursor_pos-pos+1), y)
      end
    end
    x = x + frag_width
    pos = pos + frag_len
  end
  if line_index == Cursor_line and Cursor_pos == pos then
    Text.draw_cursor(x, y)
  end
  New_render = false
  return y
end
-- manual tests:
--  draw with small line_width of 100
--  short words break on spaces
--  long words break when they must

function Text.draw_cursor(x, y)
  love.graphics.setColor(1,0,0)
  love.graphics.circle('fill', x,y+math.floor(15*Zoom), 2)
  love.graphics.setColor(0,0,0)
  Cursor_x = x
  Cursor_y = y+math.floor(15*Zoom)
end

function Text.compute_fragments(line, line_width)
  line.fragments = {}
  local x = 25
  -- try to wrap at word boundaries
  for frag in line.data:gmatch('%S*%s*') do
    local frag_text = love.graphics.newText(love.graphics.getFont(), frag)
    local frag_width = math.floor(frag_text:getWidth()*Zoom)
--?     print('x: '..tostring(x)..'; '..tostring(line_width-x)..'px to go')
--?     print('frag: ^'..frag..'$ is '..tostring(frag_width)..'px wide')
    if x + frag_width > line_width then
      while x + frag_width > line_width do
        if x < 0.8*line_width then
          -- long word; chop it at some letter
          -- We're not going to reimplement TeX here.
          local b = Text.nearest_cursor_pos(frag, line_width - x)
--?           print('space for '..tostring(b)..' graphemes')
          local frag1 = string.sub(frag, 1, b)
          local frag1_text = love.graphics.newText(love.graphics.getFont(), frag1)
          local frag1_width = math.floor(frag1_text:getWidth()*Zoom)
--?           print('inserting '..frag1..' of width '..tostring(frag1_width)..'px')
          table.insert(line.fragments, {data=frag1, text=frag1_text})
          frag = string.sub(frag, b+1)
          frag_text = love.graphics.newText(love.graphics.getFont(), frag)
          frag_width = math.floor(frag_text:getWidth()*Zoom)
        end
        x = 25  -- new line
      end
    end
    if #frag > 0 then
--?       print('inserting '..frag..' of width '..tostring(frag_width)..'px')
      table.insert(line.fragments, {data=frag, text=frag_text})
    end
  end
end

function love.textinput(t)
  if love.mouse.isDown('1') then return end
  if Lines[Cursor_line].mode == 'drawing' then return end
  Text.insert_at_cursor(t)
  save_to_disk(Lines, Filename)
end

function Text.insert_at_cursor(t)
  local byte_offset
  if Cursor_pos > 1 then
    byte_offset = utf8.offset(Lines[Cursor_line].data, Cursor_pos-1)
  else
    byte_offset = 0
  end
  Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_offset)..t..string.sub(Lines[Cursor_line].data, byte_offset+1)
  Lines[Cursor_line].fragments = nil
  Cursor_pos = Cursor_pos+1
end

-- Don't handle any keys here that would trigger love.textinput above.
function Text.keychord_pressed(chord)
  New_render = true
  if chord == 'return' then
    local byte_offset = utf8.offset(Lines[Cursor_line].data, Cursor_pos)
    table.insert(Lines, Cursor_line+1, {mode='text', data=string.sub(Lines[Cursor_line].data, byte_offset)})
    Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_offset-1)
    Lines[Cursor_line].fragments = nil
    Cursor_line = Cursor_line+1
    Cursor_pos = 1
    save_to_disk(Lines, Filename)
  elseif chord == 'tab' then
    Text.insert_at_cursor('\t')
    save_to_disk(Lines, Filename)
  elseif chord == 'left' then
    assert(Lines[Cursor_line].mode == 'text')
    if Cursor_pos > 1 then
      Cursor_pos = Cursor_pos-1
    else
      local new_cursor_line = Cursor_line
      while new_cursor_line > 1 do
        new_cursor_line = new_cursor_line-1
        if Lines[new_cursor_line].mode == 'text' then
          Cursor_line = new_cursor_line
          Cursor_pos = utf8.len(Lines[Cursor_line].data) + 1
          break
        end
      end
      if Cursor_line < Screen_top_line then
        Screen_top_line = Cursor_line
      end
    end
  elseif chord == 'right' then
    assert(Lines[Cursor_line].mode == 'text')
    if Cursor_pos <= utf8.len(Lines[Cursor_line].data) then
      Cursor_pos = Cursor_pos+1
    else
      local new_cursor_line = Cursor_line
      while new_cursor_line <= #Lines-1 do
        new_cursor_line = new_cursor_line+1
        if Lines[new_cursor_line].mode == 'text' then
          Cursor_line = new_cursor_line
          Cursor_pos = 1
          break
        end
      end
      if Cursor_line > Screen_bottom_line then
        Screen_top_line = Cursor_line
      end
    end
  elseif chord == 'home' then
    Cursor_pos = 1
  elseif chord == 'end' then
    Cursor_pos = utf8.len(Lines[Cursor_line].data) + 1
  elseif chord == 'backspace' then
    if Cursor_pos > 1 then
      local byte_start = utf8.offset(Lines[Cursor_line].data, Cursor_pos-1)
      local byte_end = utf8.offset(Lines[Cursor_line].data, Cursor_pos)
      if byte_start then
        if byte_end then
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)..string.sub(Lines[Cursor_line].data, byte_end)
        else
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)
        end
        Lines[Cursor_line].fragments = nil
        Cursor_pos = Cursor_pos-1
      end
    elseif Cursor_line > 1 then
      if Lines[Cursor_line-1].mode == 'drawing' then
        table.remove(Lines, Cursor_line-1)
      else
        -- join lines
        Cursor_pos = utf8.len(Lines[Cursor_line-1].data)+1
        Lines[Cursor_line-1].data = Lines[Cursor_line-1].data..Lines[Cursor_line].data
        Lines[Cursor_line-1].fragments = nil
        table.remove(Lines, Cursor_line)
      end
      Cursor_line = Cursor_line-1
    end
    save_to_disk(Lines, Filename)
  elseif chord == 'delete' then
    if Cursor_pos <= utf8.len(Lines[Cursor_line].data) then
      local byte_start = utf8.offset(Lines[Cursor_line].data, Cursor_pos)
      local byte_end = utf8.offset(Lines[Cursor_line].data, Cursor_pos+1)
      if byte_start then
        if byte_end then
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)..string.sub(Lines[Cursor_line].data, byte_end)
        else
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)
        end
        Lines[Cursor_line].fragments = nil
        -- no change to Cursor_pos
      end
    elseif Cursor_line < #Lines then
      if Lines[Cursor_line+1].mode == 'drawing' then
        table.remove(Lines, Cursor_line+1)
      else
        -- join lines
        Lines[Cursor_line].data = Lines[Cursor_line].data..Lines[Cursor_line+1].data
        Lines[Cursor_line].fragments = nil
        table.remove(Lines, Cursor_line+1)
      end
    end
    save_to_disk(Lines, Filename)
  elseif chord == 'up' then
    assert(Lines[Cursor_line].mode == 'text')
    print('up', Cursor_pos, Top_screen_line_starting_pos)
    local screen_line_index,screen_line_starting_pos = Text.pos_at_start_of_cursor_screen_line()
    if screen_line_starting_pos == 1 then
      print('cursor is at first screen line of its line')
      -- line is done; skip to previous text line
      local new_cursor_line = Cursor_line
      while new_cursor_line > 1 do
        new_cursor_line = new_cursor_line-1
        if Lines[new_cursor_line].mode == 'text' then
          Cursor_line = new_cursor_line
          if Lines[Cursor_line].screen_line_starting_pos == nil then
            Cursor_pos = Text.nearest_cursor_pos(Lines[Cursor_line].data, Cursor_x)
            break
          end
          -- previous text line found, pick its final screen line
          local screen_line_starting_pos = Lines[Cursor_line].screen_line_starting_pos
          screen_line_starting_pos = screen_line_starting_pos[#screen_line_starting_pos]
          print('previous screen line starts at pos '..tostring(screen_line_starting_pos)..' of its line')
          if Screen_top_line == Cursor_line and Top_screen_line_starting_pos == screen_line_starting_pos then
            Top_screen_line_starting_pos = screen_line_starting_pos
            print('pos of top of screen is also '..tostring(Top_screen_line_starting_pos)..' of the same line')
          end
          local s = string.sub(Lines[Cursor_line].data, screen_line_starting_pos)
          Cursor_pos = screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
          break
        end
      end
      if Cursor_line < Screen_top_line then
        Screen_top_line = Cursor_line
      end
    else
      -- move up one screen line in current line
      print('cursor is NOT at first screen line of its line')
      assert(screen_line_index > 1)
      new_screen_line_starting_pos = Lines[Cursor_line].screen_line_starting_pos[screen_line_index-1]
      print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
      if Screen_top_line == Cursor_line and Top_screen_line_starting_pos == screen_line_starting_pos then
        Top_screen_line_starting_pos = new_screen_line_starting_pos
        print('also setting pos of top of screen to '..tostring(Top_screen_line_starting_pos))
      end
      local s = string.sub(Lines[Cursor_line].data, new_screen_line_starting_pos)
      Cursor_pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
      print('cursor pos is now '..tostring(Cursor_pos))
    end
  elseif chord == 'down' then
    assert(Lines[Cursor_line].mode == 'text')
    if Text.cursor_at_final_screen_line() then
      -- line is done, skip to next text line
      print('down: cursor at final screen line of its line')
      local new_cursor_line = Cursor_line
      while new_cursor_line < #Lines do
        new_cursor_line = new_cursor_line+1
        if Lines[new_cursor_line].mode == 'text' then
          Cursor_line = new_cursor_line
          Cursor_pos = Text.nearest_cursor_pos(Lines[Cursor_line].data, Cursor_x)
          print(Cursor_pos)
          break
        end
      end
      if Cursor_line > Screen_bottom_line then
        Screen_top_line = Cursor_line
        Text.scroll_up_while_cursor_on_screen()
      end
    else
      -- move down one screen line in current line
      print('cursor is NOT at final screen line of its line')
      local screen_line_index, screen_line_starting_pos = Text.pos_at_start_of_cursor_screen_line()
      new_screen_line_starting_pos = Lines[Cursor_line].screen_line_starting_pos[screen_line_index+1]
      print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
      local s = string.sub(Lines[Cursor_line].data, new_screen_line_starting_pos)
      Cursor_pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
      print('cursor pos is now '..tostring(Cursor_pos))
      Text.scroll_up_while_cursor_on_screen()
    end
  end
end

function Text.pos_at_start_of_cursor_screen_line()
  if Lines[Cursor_line].screen_line_starting_pos == nil then
    return 1,1
  end
  for i=#Lines[Cursor_line].screen_line_starting_pos,1,-1 do
    local spos = Lines[Cursor_line].screen_line_starting_pos[i]
    if spos <= Cursor_pos then
      return i,spos
    end
  end
  assert(false)
end

function Text.cursor_at_final_screen_line()
  if Lines[Cursor_line].screen_line_starting_pos == nil then
    return true
  end
  i=#Lines[Cursor_line].screen_line_starting_pos
  local spos = Lines[Cursor_line].screen_line_starting_pos[i]
  return spos <= Cursor_pos
end

function Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
  while Cursor_line <= #Lines do
    if Lines[Cursor_line].mode == 'text' then
      break
    end
    Cursor_line = Cursor_line + 1
  end
  -- hack: insert a text line at bottom of file if necessary
  if Cursor_line > #Lines then
    assert(Cursor_line == #Lines+1)
    table.insert(Lines, {mode='text', data=''})
  end
  if Cursor_line > Screen_bottom_line then
    Screen_top_line = Cursor_line
    Text.scroll_up_while_cursor_on_screen()
  end
end

function Text.scroll_up_while_cursor_on_screen()
  local y = Screen_height - math.floor(15*Zoom) -- for Cursor_line
  while true do
    if Screen_top_line == 1 then break end
    y = y - math.floor(15*Zoom)
    if Lines[Screen_top_line].mode == 'drawing' then
      y = y - Drawing.pixels(Lines[Screen_top_line].h)
    end
    if y < math.floor(15*Zoom) then
      break
    end
    Screen_top_line = Screen_top_line - 1
  end
end

function Text.in_line(line, x,y)
  if line.y == nil then return false end  -- outside current page
  if x < 16 then return false end
  if y < line.y then return false end
  if line.screen_line_starting_pos == nil then return y < line.y + math.floor(15*Zoom) end
  return y < line.y + #line.screen_line_starting_pos * math.floor(15*Zoom)
end

function Text.move_cursor(line_index, line, mx, my)
  Cursor_line = line_index
  if line.screen_line_starting_pos == nil then
    Cursor_pos = Text.nearest_cursor_pos(line.data, mx)
    return
  end
  assert(line.fragments)
  assert(my >= line.y)
  -- duplicate some logic from Text.draw
  local y = line.y
  for screen_line_index,screen_line_starting_pos in ipairs(line.screen_line_starting_pos) do
    local nexty = y + math.floor(15*Zoom)
    if my < nexty then
      -- On all wrapped screen lines but the final one, clicks past end of
      -- line position cursor on final character of screen line.
      -- (The final screen line positions past end of screen line as always.)
      if mx > Line_width and screen_line_index < #line.screen_line_starting_pos then
        Cursor_pos = line.screen_line_starting_pos[screen_line_index+1]
        return
      end
      local s = string.sub(line.data, screen_line_starting_pos)
      Cursor_pos = screen_line_starting_pos + Text.nearest_cursor_pos(s, mx) - 1
      return
    end
    y = nexty
  end
  assert(false)
end
-- manual test:
--  line: abc
--        def
--        gh
--  fragments: abc, def, gh
--  click inside e
--  line_starting_pos = 1 + 3 = 4
--  nearest_cursor_pos('defgh', mx) = 2
--  Cursor_pos = 4 + 2 - 1 = 5
-- manual test:
--  click inside h
--  line_starting_pos = 1 + 3 + 3 = 7
--  nearest_cursor_pos('gh', mx) = 2
--  Cursor_pos = 7 + 2 - 1 = 8

function Text.nearest_cursor_pos(line, x)
  if x == 0 then
    return 1
  end
  local len = utf8.len(line)
  local max_x = Text.cursor_x(line, len+1)
  if x > max_x then
    return len+1
  end
  local left, right = 1, len+1
--?   print('--')
  while true do
    local curr = math.floor((left+right)/2)
    local currxmin = Text.cursor_x(line, curr)
    local currxmax = Text.cursor_x(line, curr+1)
--?     print(x, left, right, curr, currxmin, currxmax)
    if currxmin <= x and x < currxmax then
      return curr
    end
    if left >= right-1 then
      return right
    end
    if currxmin > x then
      right = curr
    else
      left = curr
    end
  end
  assert(false)
end

function Text.cursor_x(line_data, cursor_pos)
  local line_before_cursor = line_data:sub(1, cursor_pos-1)
  local text_before_cursor = love.graphics.newText(love.graphics.getFont(), line_before_cursor)
  return 25 + math.floor(text_before_cursor:getWidth()*Zoom)
end

function Text.cursor_x2(s, cursor_pos)
  local s_before_cursor = s:sub(1, cursor_pos-1)
  local text_before_cursor = love.graphics.newText(love.graphics.getFont(), s_before_cursor)
  return math.floor(text_before_cursor:getWidth()*Zoom)
end

return Text
