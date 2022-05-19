-- primitives for editing text
Text = {}

local utf8 = require 'utf8'

function Text.draw(line, line_index, cursor_line, cursor_pos)
  love.graphics.setColor(0,0,0)
  local love_text = love.graphics.newText(love.graphics.getFont(), line.data)
  love.graphics.draw(love_text, 25,line.y, 0, Zoom)
  if line_index == cursor_line then
    -- cursor
    love.graphics.print('_', Text.cursor_x(line.data, cursor_pos), line.y+6)  -- drop the cursor down a bit to account for the increased font size
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
  Cursor_pos = Cursor_pos+1
end

-- Don't handle any keys here that would trigger love.textinput above.
function Text.keychord_pressed(chord)
  if chord == 'return' then
    local byte_offset = utf8.offset(Lines[Cursor_line].data, Cursor_pos)
    table.insert(Lines, Cursor_line+1, {mode='text', data=string.sub(Lines[Cursor_line].data, byte_offset)})
    Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_offset-1)
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
          Cursor_pos = #Lines[Cursor_line].data+1
          break
        end
      end
      if Cursor_line < Screen_top_line then
        Screen_top_line = Cursor_line
      end
    end
  elseif chord == 'right' then
    assert(Lines[Cursor_line].mode == 'text')
    if Cursor_pos <= #Lines[Cursor_line].data then
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
    Cursor_pos = #Lines[Cursor_line].data+1
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
        Cursor_pos = Cursor_pos-1
      end
    elseif Cursor_line > 1 then
      if Lines[Cursor_line-1].mode == 'drawing' then
        table.remove(Lines, Cursor_line-1)
      else
        -- join lines
        Cursor_pos = utf8.len(Lines[Cursor_line-1].data)+1
        Lines[Cursor_line-1].data = Lines[Cursor_line-1].data..Lines[Cursor_line].data
        table.remove(Lines, Cursor_line)
      end
      Cursor_line = Cursor_line-1
    end
    save_to_disk(Lines, Filename)
  elseif chord == 'delete' then
    if Cursor_pos <= #Lines[Cursor_line].data then
      local byte_start = utf8.offset(Lines[Cursor_line].data, Cursor_pos)
      local byte_end = utf8.offset(Lines[Cursor_line].data, Cursor_pos+1)
      if byte_start then
        if byte_end then
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)..string.sub(Lines[Cursor_line].data, byte_end)
        else
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)
        end
        -- no change to Cursor_pos
      end
    elseif Cursor_line < #Lines then
      if Lines[Cursor_line+1].mode == 'drawing' then
        table.remove(Lines, Cursor_line+1)
      else
        -- join lines
        Lines[Cursor_line].data = Lines[Cursor_line].data..Lines[Cursor_line+1].data
        table.remove(Lines, Cursor_line+1)
      end
    end
    save_to_disk(Lines, Filename)
  elseif chord == 'up' then
    assert(Lines[Cursor_line].mode == 'text')
    local new_cursor_line = Cursor_line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if Lines[new_cursor_line].mode == 'text' then
        local old_x = Text.cursor_x(Lines[new_cursor_line].data, Cursor_pos)
        Cursor_line = new_cursor_line
        Cursor_pos = Text.nearest_cursor_pos(Lines[Cursor_line].data, old_x, Cursor_pos)
        break
      end
    end
    if Cursor_line < Screen_top_line then
      Screen_top_line = Cursor_line
    end
  elseif chord == 'down' then
    assert(Lines[Cursor_line].mode == 'text')
    local new_cursor_line = Cursor_line
    while new_cursor_line < #Lines do
      new_cursor_line = new_cursor_line+1
      if Lines[new_cursor_line].mode == 'text' then
        local old_x = Text.cursor_x(Lines[new_cursor_line].data, Cursor_pos)
        Cursor_line = new_cursor_line
        Cursor_pos = Text.nearest_cursor_pos(Lines[Cursor_line].data, old_x, Cursor_pos)
        break
      end
    end
    if Cursor_line > Screen_bottom_line then
      Screen_top_line = Cursor_line
    end
  end
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
  local y = Screen_height - 15*Zoom -- for Cursor_line
  while true do
    if Screen_top_line == 1 then break end
    y = y - 15*Zoom
    if Lines[Screen_top_line].mode == 'drawing' then
      y = y - Drawing.pixels(Lines[Screen_top_line].h)
    end
    if y < 15*Zoom then
      break
    end
    Screen_top_line = Screen_top_line - 1
  end
end

function Text.in_line(line, x,y)
  if line.y == nil then return false end  -- outside current page
  return x >= 16 and y >= line.y and y < line.y+15*Zoom
end

function Text.move_cursor(line_index, line, x)
  Cursor_line = line_index
  Cursor_pos = Text.nearest_cursor_pos(line.data, x)
end

function Text.nearest_cursor_pos(line, x, hint)
  if x == 0 then
    return 1
  end
  local max_x = Text.cursor_x(line, #line+1)
  if x > max_x then
    return #line+1
  end
  if hint then
    local currx = Text.cursor_x(line, hint)
    if currx > x-2 and currx < x+2 then
      return hint
    end
  end
  local left, right = 1, #line+1
  if hint then
    if currx > x then
      right = hint
    else
      left = hint
    end
  end
  while left < right-1 do
    local curr = math.floor((left+right)/2)
    local currxmin = Text.cursor_x(line, curr)
    local currxmax = Text.cursor_x(line, curr+1)
    if currxmin <= x and x < currxmax then
      return curr
    end
    if currxmin > x then
      right = curr
    else
      left = curr
    end
  end
  return right
end

function Text.cursor_x(line_data, cursor_pos)
  local line_before_cursor = line_data:sub(1, cursor_pos-1)
  local text_before_cursor = love.graphics.newText(love.graphics.getFont(), line_before_cursor)
  return 25+text_before_cursor:getWidth()*Zoom
end

return Text
