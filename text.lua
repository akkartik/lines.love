-- primitives for editing text
Text = {}

local utf8 = require 'utf8'

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

function Text.draw(line, line_width, line_index, cursor_line, cursor_pos)
--?   love.graphics.setColor(0.75,0.75,0.75)
--?   love.graphics.line(line_width, 0, line_width, Screen_height)
  love.graphics.setColor(0,0,0)
  -- wrap long lines
  local x = 25
  local y = line.y
  local pos = 1
  if line.fragments == nil then
    Text.compute_fragments(line, line_width)
  end
  for _, f in ipairs(line.fragments) do
    local frag, frag_text = f.data, f.text
    -- render fragment
    local frag_width = math.floor(frag_text:getWidth()*Zoom)
    if x + frag_width > line_width then
      assert(x > 25)  -- no overfull lines
      y = y + math.floor(15*Zoom)
      x = 25
    end
    love.graphics.draw(frag_text, x,y, 0, Zoom)
    -- render cursor if necessary
    local frag_len = utf8.len(frag)
    if line_index == cursor_line then
      if pos <= cursor_pos and pos + frag_len > cursor_pos then
        -- cursor
        love.graphics.print('_', x+Text.cursor_x2(frag, cursor_pos-pos+1), y+6)  -- drop the cursor down a bit to account for the increased font size
      end
    end
    x = x + frag_width
    pos = pos + frag_len
  end
  return y
end
-- manual tests:
--  draw with small line_width of 100
--  short words break on spaces
--  long words break when they must

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
  return x >= 16 and y >= line.y and y < line.y + math.floor(15*Zoom)
end

function Text.move_cursor(line_index, line, x)
  Cursor_line = line_index
  Cursor_pos = Text.nearest_cursor_pos(line.data, x)
end

function Text.nearest_cursor_pos(line, x, hint)
  if x == 0 then
    return 1
  end
  local len = utf8.len(line)
  local max_x = Text.cursor_x(line, len+1)
  if x > max_x then
    return len+1
  end
  if hint then
    local currx = Text.cursor_x(line, hint)
    if currx > x-2 and currx < x+2 then
      return hint
    end
  end
  local left, right = 1, len+1
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
  return 25 + math.floor(text_before_cursor:getWidth()*Zoom)
end

function Text.cursor_x2(s, cursor_pos)
  local s_before_cursor = s:sub(1, cursor_pos-1)
  local text_before_cursor = love.graphics.newText(love.graphics.getFont(), s_before_cursor)
  return math.floor(text_before_cursor:getWidth()*Zoom)
end

return Text
