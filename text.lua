-- primitives for editing text
Text = {}

function Text.draw(line, line_index, cursor_line, y, cursor_pos)
  love.graphics.setColor(0,0,0)
  local love_text = love.graphics.newText(love.graphics.getFont(), line.data)
  love.graphics.draw(love_text, 25,y, 0, Zoom)
  if line_index == cursor_line then
    -- cursor
    love.graphics.print('_', Text.cursor_x(line.data, cursor_pos), y+6)  -- drop the cursor down a bit to account for the increased font size
  end
end

function Text.nearest_cursor_pos(line, x, hint)
  if x == 0 then
    return 1
  end
  local max_x = Text.cursor_x(line, #line+1)
  if x > max_x then
    return #line+1
  end
  local currx = Text.cursor_x(line, hint)
  if currx > x-2 and currx < x+2 then
    return hint
  end
  local left, right = 1, #line+1
  if currx > x then
    right = hint
  else
    left = hint
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
