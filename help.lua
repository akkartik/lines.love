function draw_help_without_mouse_pressed(drawing)
  App.color(Help_color)
  local y = drawing.y+10
  love.graphics.print("Things you can do:", Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  love.graphics.print("* Press the mouse button to start drawing a "..current_shape(), Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  love.graphics.print("* Hover on a point and press 'ctrl+u' to pick it up and start moving it,", Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  love.graphics.print("then press the mouse button to drop it", Editor_state.margin_left+30+bullet_indent(),y)
  y = y + Editor_state.line_height
  love.graphics.print("* Hover on a point and press 'ctrl+n', type a name, then press 'enter'", Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  love.graphics.print("* Hover on a point or shape and press 'ctrl+d' to delete it", Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  if Editor_state.current_drawing_mode ~= 'freehand' then
    love.graphics.print("* Press 'ctrl+p' to switch to drawing freehand strokes", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'line' then
    love.graphics.print("* Press 'ctrl+l' to switch to drawing lines", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'manhattan' then
    love.graphics.print("* Press 'ctrl+m' to switch to drawing horizontal/vertical lines", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'circle' then
    love.graphics.print("* Press 'ctrl+o' to switch to drawing circles/arcs", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'polygon' then
    love.graphics.print("* Press 'ctrl+g' to switch to drawing polygons", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'rectangle' then
    love.graphics.print("* Press 'ctrl+r' to switch to drawing rectangles", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'square' then
    love.graphics.print("* Press 'ctrl+s' to switch to drawing squares", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  love.graphics.print("* Press 'ctrl+=' or 'ctrl+-' to zoom in or out, ctrl+0 to reset zoom", Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  love.graphics.print("Press 'esc' now to hide this message", Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  App.color(Help_background_color)
  love.graphics.rectangle('fill', Editor_state.margin_left,drawing.y, App.screen.width-Editor_state.margin_width, math.max(Drawing.pixels(drawing.h),y-drawing.y))
end

function draw_help_with_mouse_pressed(drawing)
  App.color(Help_color)
  local y = drawing.y+10
  love.graphics.print("You're currently drawing a "..current_shape(drawing.pending), Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  love.graphics.print('Things you can do now:', Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  if Editor_state.current_drawing_mode == 'freehand' then
    love.graphics.print('* Release the mouse button to finish drawing the stroke', Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  elseif Editor_state.current_drawing_mode == 'line' or Editor_state.current_drawing_mode == 'manhattan' then
    love.graphics.print('* Release the mouse button to finish drawing the line', Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  elseif Editor_state.current_drawing_mode == 'circle' then
    if drawing.pending.mode == 'circle' then
      love.graphics.print('* Release the mouse button to finish drawing the circle', Editor_state.margin_left+30,y)
      y = y + Editor_state.line_height
      love.graphics.print("* Press 'a' to draw just an arc of a circle", Editor_state.margin_left+30,y)
    else
      love.graphics.print('* Release the mouse button to finish drawing the arc', Editor_state.margin_left+30,y)
    end
    y = y + Editor_state.line_height
  elseif Editor_state.current_drawing_mode == 'polygon' then
    love.graphics.print('* Release the mouse button to finish drawing the polygon', Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
    love.graphics.print("* Press 'p' to add a vertex to the polygon", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  elseif Editor_state.current_drawing_mode == 'rectangle' then
    if #drawing.pending.vertices < 2 then
      love.graphics.print("* Press 'p' to add a vertex to the rectangle", Editor_state.margin_left+30,y)
      y = y + Editor_state.line_height
    else
      love.graphics.print('* Release the mouse button to finish drawing the rectangle', Editor_state.margin_left+30,y)
      y = y + Editor_state.line_height
      love.graphics.print("* Press 'p' to replace the second vertex of the rectangle", Editor_state.margin_left+30,y)
      y = y + Editor_state.line_height
    end
  elseif Editor_state.current_drawing_mode == 'square' then
    if #drawing.pending.vertices < 2 then
      love.graphics.print("* Press 'p' to add a vertex to the square", Editor_state.margin_left+30,y)
      y = y + Editor_state.line_height
    else
      love.graphics.print('* Release the mouse button to finish drawing the square', Editor_state.margin_left+30,y)
      y = y + Editor_state.line_height
      love.graphics.print("* Press 'p' to replace the second vertex of the square", Editor_state.margin_left+30,y)
      y = y + Editor_state.line_height
    end
  end
  love.graphics.print("* Press 'esc' then release the mouse button to cancel the current shape", Editor_state.margin_left+30,y)
  y = y + Editor_state.line_height
  y = y + Editor_state.line_height
  if Editor_state.current_drawing_mode ~= 'line' then
    love.graphics.print("* Press 'l' to switch to drawing lines", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'manhattan' then
    love.graphics.print("* Press 'm' to switch to drawing horizontal/vertical lines", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'circle' then
    love.graphics.print("* Press 'o' to switch to drawing circles/arcs", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'polygon' then
    love.graphics.print("* Press 'g' to switch to drawing polygons", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'rectangle' then
    love.graphics.print("* Press 'r' to switch to drawing rectangles", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  if Editor_state.current_drawing_mode ~= 'square' then
    love.graphics.print("* Press 's' to switch to drawing squares", Editor_state.margin_left+30,y)
    y = y + Editor_state.line_height
  end
  App.color(Help_background_color)
  love.graphics.rectangle('fill', Editor_state.margin_left,drawing.y, App.screen.width-Editor_state.margin_width, math.max(Drawing.pixels(drawing.h),y-drawing.y))
end

function current_shape(shape)
  if Editor_state.current_drawing_mode == 'freehand' then
    return 'freehand stroke'
  elseif Editor_state.current_drawing_mode == 'line' then
    return 'straight line'
  elseif Editor_state.current_drawing_mode == 'manhattan' then
    return 'horizontal/vertical line'
  elseif Editor_state.current_drawing_mode == 'circle' and shape and shape.start_angle then
    return 'arc'
  else
    return Editor_state.current_drawing_mode
  end
end

_bullet_indent = nil
function bullet_indent()
  if _bullet_indent == nil then
    local text = love.graphics.newText(love.graphics.getFont(), '* ')
    _bullet_indent = text:getWidth()
  end
  return _bullet_indent
end
