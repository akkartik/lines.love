function draw_help_without_mouse_pressed(drawing)
  love.graphics.setColor(0,0.5,0)
  local y = drawing.y+10
  love.graphics.print("Things you can do:", Margin_left+30,y)
  y = y + Line_height
  love.graphics.print("* Press the mouse button to start drawing a "..current_shape(), Margin_left+30,y)
  y = y + Line_height
  love.graphics.print("* Hover on a point and press 'ctrl+u' to pick it up and start moving it,", Margin_left+30,y)
  y = y + Line_height
  love.graphics.print("then press the mouse button to drop it", Margin_left+30+bullet_indent(),y)
  y = y + Line_height
  love.graphics.print("* Hover on a point and press 'ctrl+n', type a name, then press 'enter'", Margin_left+30,y)
  y = y + Line_height
  love.graphics.print("* Hover on a point or shape and press 'ctrl+d' to delete it", Margin_left+30,y)
  y = y + Line_height
  if Current_drawing_mode ~= 'freehand' then
    love.graphics.print("* Press 'ctrl+p' to switch to drawing freehand strokes", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'line' then
    love.graphics.print("* Press 'ctrl+l' to switch to drawing lines", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'manhattan' then
    love.graphics.print("* Press 'ctrl+m' to switch to drawing horizontal/vertical lines", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'circle' then
    love.graphics.print("* Press 'ctrl+o' to switch to drawing circles/arcs", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'polygon' then
    love.graphics.print("* Press 'ctrl+g' to switch to drawing polygons", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'rectangle' then
    love.graphics.print("* Press 'ctrl+r' to switch to drawing rectangles", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'square' then
    love.graphics.print("* Press 'ctrl+s' to switch to drawing squares", Margin_left+30,y)
    y = y + Line_height
  end
  love.graphics.print("* Press 'ctrl+=' or 'ctrl+-' to zoom in or out, ctrl+0 to reset zoom", Margin_left+30,y)
  y = y + Line_height
  love.graphics.print("Press 'esc' now to hide this message", Margin_left+30,y)
  y = y + Line_height
  love.graphics.setColor(0,0.5,0, 0.1)
  love.graphics.rectangle('fill', Margin_left,drawing.y, App.screen.width, math.max(Drawing.pixels(drawing.h),y-drawing.y))
end

function draw_help_with_mouse_pressed(drawing)
  love.graphics.setColor(0,0.5,0)
  local y = drawing.y+10
  love.graphics.print("You're currently drawing a "..current_shape(drawing.pending), Margin_left+30,y)
  y = y + Line_height
  love.graphics.print('Things you can do now:', Margin_left+30,y)
  y = y + Line_height
  if Current_drawing_mode == 'freehand' then
    love.graphics.print('* Release the mouse button to finish drawing the stroke', Margin_left+30,y)
    y = y + Line_height
  elseif Current_drawing_mode == 'line' or Current_drawing_mode == 'manhattan' then
    love.graphics.print('* Release the mouse button to finish drawing the line', Margin_left+30,y)
    y = y + Line_height
  elseif Current_drawing_mode == 'circle' then
    if drawing.pending.mode == 'circle' then
      love.graphics.print('* Release the mouse button to finish drawing the circle', Margin_left+30,y)
      y = y + Line_height
      love.graphics.print("* Press 'a' to draw just an arc of a circle", Margin_left+30,y)
    else
      love.graphics.print('* Release the mouse button to finish drawing the arc', Margin_left+30,y)
    end
    y = y + Line_height
  elseif Current_drawing_mode == 'polygon' then
    love.graphics.print('* Release the mouse button to finish drawing the polygon', Margin_left+30,y)
    y = y + Line_height
    love.graphics.print("* Press 'p' to add a vertex to the polygon", Margin_left+30,y)
    y = y + Line_height
  elseif Current_drawing_mode == 'rectangle' then
    if #drawing.pending.vertices < 2 then
      love.graphics.print("* Press 'p' to add a vertex to the rectangle", Margin_left+30,y)
      y = y + Line_height
    else
      love.graphics.print('* Release the mouse button to finish drawing the rectangle', Margin_left+30,y)
      y = y + Line_height
      love.graphics.print("* Press 'p' to replace the second vertex of the rectangle", Margin_left+30,y)
      y = y + Line_height
    end
  elseif Current_drawing_mode == 'square' then
    if #drawing.pending.vertices < 2 then
      love.graphics.print("* Press 'p' to add a vertex to the square", Margin_left+30,y)
      y = y + Line_height
    else
      love.graphics.print('* Release the mouse button to finish drawing the square', Margin_left+30,y)
      y = y + Line_height
      love.graphics.print("* Press 'p' to replace the second vertex of the square", Margin_left+30,y)
      y = y + Line_height
    end
  end
  love.graphics.print("* Press 'esc' then release the mouse button to cancel the current shape", Margin_left+30,y)
  y = y + Line_height
  y = y + Line_height
  if Current_drawing_mode ~= 'line' then
    love.graphics.print("* Press 'l' to switch to drawing lines", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'manhattan' then
    love.graphics.print("* Press 'm' to switch to drawing horizontal/vertical lines", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'circle' then
    love.graphics.print("* Press 'o' to switch to drawing circles/arcs", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'polygon' then
    love.graphics.print("* Press 'g' to switch to drawing polygons", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'rectangle' then
    love.graphics.print("* Press 'r' to switch to drawing rectangles", Margin_left+30,y)
    y = y + Line_height
  end
  if Current_drawing_mode ~= 'square' then
    love.graphics.print("* Press 's' to switch to drawing squares", Margin_left+30,y)
    y = y + Line_height
  end
  love.graphics.setColor(0,0.5,0, 0.1)
  love.graphics.rectangle('fill', Margin_left,drawing.y, App.screen.width, math.max(Drawing.pixels(drawing.h),y-drawing.y))
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
