function draw_help_without_mouse_pressed(drawing)
  love.graphics.setColor(0,0.5,0)
  local y = drawing.y+10
  love.graphics.print("Things you can do:", 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.print("* Press the mouse button to start drawing a "..current_shape(), 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.print("* Hover on a point and press 'ctrl+v' to start moving it,", 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.print("* Hover on a point and press 'ctrl+n' to name it,", 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.print("then press the mouse button to finish", 16+30+bullet_indent(),y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.print("* Hover on a point or shape and press 'ctrl+d' to delete it", 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  y = y + math.floor(15*Zoom)
  if Current_drawing_mode ~= 'freehand' then
    love.graphics.print("* Press 'ctrl+f' to switch to drawing freehand strokes", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'line' then
    love.graphics.print("* Press 'ctrl+l' to switch to drawing lines", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'manhattan' then
    love.graphics.print("* Press 'ctrl+m' to switch to drawing horizontal/vertical lines", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'circle' then
    love.graphics.print("* Press 'ctrl+c' to switch to drawing circles/arcs", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'polygon' then
    love.graphics.print("* Press 'ctrl+g' to switch to drawing polygons", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'rectangle' then
    love.graphics.print("* Press 'ctrl+r' to switch to drawing rectangles", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'square' then
    love.graphics.print("* Press 'ctrl+s' to switch to drawing squares", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  love.graphics.print("* Press 'ctrl+=' or 'ctrl+-' to Zoom in or out", 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.print("* Press 'ctrl+0' to reset Zoom", 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.print("Hit 'esc' now to hide this message", 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.setColor(0,0.5,0, 0.1)
  love.graphics.rectangle('fill', 16,drawing.y, Line_width, math.max(Drawing.pixels(drawing.h),y-drawing.y))
end

function draw_help_with_mouse_pressed(drawing)
  love.graphics.setColor(0,0.5,0)
  local y = drawing.y+10
  love.graphics.print("You're currently drawing a "..current_shape(drawing.pending), 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  love.graphics.print('Things you can do now:', 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  if Current_drawing_mode == 'freehand' then
    love.graphics.print('* Release the mouse button to finish drawing the stroke', 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  elseif Current_drawing_mode == 'line' or Current_drawing_mode == 'manhattan' then
    love.graphics.print('* Release the mouse button to finish drawing the line', 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  elseif Current_drawing_mode == 'circle' then
    if drawing.pending.mode == 'circle' then
      love.graphics.print('* Release the mouse button to finish drawing the circle', 16+30,y, 0, Zoom)
      y = y + math.floor(15*Zoom)
      love.graphics.print("* Press 'a' to draw just an arc of a circle", 16+30,y, 0, Zoom)
    else
      love.graphics.print('* Release the mouse button to finish drawing the arc', 16+30,y, 0, Zoom)
    end
    y = y + math.floor(15*Zoom)
  elseif Current_drawing_mode == 'polygon' then
    love.graphics.print('* Release the mouse button to finish drawing the polygon', 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
    love.graphics.print("* Press 'p' to add a vertex to the polygon", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  love.graphics.print("* Press 'esc' then release the mouse button to cancel the current shape", 16+30,y, 0, Zoom)
  y = y + math.floor(15*Zoom)
  y = y + math.floor(15*Zoom)
  if Current_drawing_mode ~= 'line' then
    love.graphics.print("* Press 'l' to switch to drawing lines", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'manhattan' then
    love.graphics.print("* Press 'm' to switch to drawing horizontal/vertical lines", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'circle' then
    love.graphics.print("* Press 'c' to switch to drawing circles/arcs", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'polygon' then
    love.graphics.print("* Press 'g' to switch to drawing polygons", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'rectangle' then
    love.graphics.print("* Press 'g' to switch to drawing rectangles", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  if Current_drawing_mode ~= 'square' then
    love.graphics.print("* Press 'g' to switch to drawing squares", 16+30,y, 0, Zoom)
    y = y + math.floor(15*Zoom)
  end
  love.graphics.setColor(0,0.5,0, 0.1)
  love.graphics.rectangle('fill', 16,drawing.y, Line_width, math.max(Drawing.pixels(drawing.h),y-drawing.y))
end

function current_shape(shape)
  if Current_drawing_mode == 'freehand' then
    return 'freehand stroke'
  elseif Current_drawing_mode == 'line' then
    return 'straight line'
  elseif Current_drawing_mode == 'manhattan' then
    return 'horizontal/vertical line'
  elseif Current_drawing_mode == 'circle' and shape and shape.start_angle then
    return 'arc'
  else
    return Current_drawing_mode
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
