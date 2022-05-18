-- primitives for editing drawings
Drawing = {}
geom = require 'geom'

function Drawing.draw(line, y)
  local pmx,pmy = love.mouse.getX(), love.mouse.getY()
  if pmx < 16+Drawing_width and pmy > line.y and pmy < line.y+Drawing.pixels(line.h) then
    love.graphics.setColor(0.75,0.75,0.75)
    love.graphics.rectangle('line', 16,line.y, Drawing_width,Drawing.pixels(line.h))
    if icon[Current_drawing_mode] then
      icon[Current_drawing_mode](16+Drawing_width-20, line.y+4)
    else
      icon[Previous_drawing_mode](16+Drawing_width-20, line.y+4)
    end

    if love.mouse.isDown('1') and love.keyboard.isDown('h') then
      draw_help_with_mouse_pressed(line)
      return
    end
  end

  if line.show_help then
    draw_help_without_mouse_pressed(line)
    return
  end

  local mx,my = Drawing.coord(pmx-16), Drawing.coord(pmy-line.y)

  for _,shape in ipairs(line.shapes) do
    assert(shape)
    if geom.on_shape(mx,my, line, shape) then
      love.graphics.setColor(1,0,0)
    else
      love.graphics.setColor(0,0,0)
    end
    Drawing.draw_shape(16,line.y, line, shape)
  end
  for _,p in ipairs(line.points) do
    if p.deleted == nil then
      if Drawing.near(p, mx,my) then
        love.graphics.setColor(1,0,0)
        love.graphics.circle('line', Drawing.pixels(p.x)+16,Drawing.pixels(p.y)+line.y, 4)
      else
        love.graphics.setColor(0,0,0)
        love.graphics.circle('fill', Drawing.pixels(p.x)+16,Drawing.pixels(p.y)+line.y, 2)
      end
    end
  end
  Drawing.draw_pending_shape(16,line.y, line)
end

function Drawing.draw_shape(left,top, drawing, shape)
  if shape.mode == 'freehand' then
    local prev = nil
    for _,point in ipairs(shape.points) do
      if prev then
        love.graphics.line(Drawing.pixels(prev.x)+left,Drawing.pixels(prev.y)+top, Drawing.pixels(point.x)+left,Drawing.pixels(point.y)+top)
      end
      prev = point
    end
  elseif shape.mode == 'line' or shape.mode == 'manhattan' then
    local p1 = drawing.points[shape.p1]
    local p2 = drawing.points[shape.p2]
    love.graphics.line(Drawing.pixels(p1.x)+left,Drawing.pixels(p1.y)+top, Drawing.pixels(p2.x)+left,Drawing.pixels(p2.y)+top)
  elseif shape.mode == 'polygon' then
    local prev = nil
    for _,point in ipairs(shape.vertices) do
      local curr = drawing.points[point]
      if prev then
        love.graphics.line(Drawing.pixels(prev.x)+left,Drawing.pixels(prev.y)+top, Drawing.pixels(curr.x)+left,Drawing.pixels(curr.y)+top)
      end
      prev = curr
    end
    -- close the loop
    local curr = drawing.points[shape.vertices[1]]
    love.graphics.line(Drawing.pixels(prev.x)+left,Drawing.pixels(prev.y)+top, Drawing.pixels(curr.x)+left,Drawing.pixels(curr.y)+top)
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    love.graphics.circle('line', Drawing.pixels(center.x)+left,Drawing.pixels(center.y)+top, Drawing.pixels(shape.radius))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    love.graphics.arc('line', 'open', Drawing.pixels(center.x)+left,Drawing.pixels(center.y)+top, Drawing.pixels(shape.radius), shape.start_angle, shape.end_angle, 360)
  elseif shape.mode == 'deleted' then
  else
    print(shape.mode)
    assert(false)
  end
end

function Drawing.draw_pending_shape(left,top, drawing)
  local shape = drawing.pending
  if shape.mode == 'freehand' then
    Drawing.draw_shape(left,top, drawing, shape)
  elseif shape.mode == 'line' then
    local mx,my = Drawing.coord(love.mouse.getX()-16), Drawing.coord(love.mouse.getY()-drawing.y)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local p1 = drawing.points[shape.p1]
    love.graphics.line(Drawing.pixels(p1.x)+left,Drawing.pixels(p1.y)+top, Drawing.pixels(mx)+left,Drawing.pixels(my)+top)
  elseif shape.mode == 'manhattan' then
    local mx,my = Drawing.coord(love.mouse.getX()-16), Drawing.coord(love.mouse.getY()-drawing.y)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local p1 = drawing.points[shape.p1]
    if math.abs(mx-p1.x) > math.abs(my-p1.y) then
      love.graphics.line(Drawing.pixels(p1.x)+left,Drawing.pixels(p1.y)+top, Drawing.pixels(mx)+left,Drawing.pixels(p1.y)+top)
    else
      love.graphics.line(Drawing.pixels(p1.x)+left,Drawing.pixels(p1.y)+top, Drawing.pixels(p1.x)+left,Drawing.pixels(my)+top)
    end
  elseif shape.mode == 'polygon' then
    -- don't close the loop on a pending polygon
    local prev = nil
    for _,point in ipairs(shape.vertices) do
      local curr = drawing.points[point]
      if prev then
        love.graphics.line(Drawing.pixels(prev.x)+left,Drawing.pixels(prev.y)+top, Drawing.pixels(curr.x)+left,Drawing.pixels(curr.y)+top)
      end
      prev = curr
    end
    love.graphics.line(Drawing.pixels(prev.x)+left,Drawing.pixels(prev.y)+top, love.mouse.getX(),love.mouse.getY())
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    local mx,my = Drawing.coord(love.mouse.getX()-16), Drawing.coord(love.mouse.getY()-drawing.y)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local cx,cy = Drawing.pixels(center.x)+left, Drawing.pixels(center.y)+top
    love.graphics.circle('line', cx,cy, geom.dist(cx,cy, love.mouse.getX(),love.mouse.getY()))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    local mx,my = Drawing.coord(love.mouse.getX()-16), Drawing.coord(love.mouse.getY()-drawing.y)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    shape.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, shape.end_angle)
    local cx,cy = Drawing.pixels(center.x)+left, Drawing.pixels(center.y)+top
    love.graphics.arc('line', 'open', cx,cy, Drawing.pixels(shape.radius), shape.start_angle, shape.end_angle, 360)
  end
end


function Drawing.in_drawing(drawing, x,y)
  return y >= drawing.y and y < drawing.y + Drawing.pixels(drawing.h) and x >= 16 and x < 16+Drawing_width
end

function Drawing.mouse_pressed(drawing, x,y, button)
  if Current_drawing_mode == 'freehand' then
    drawing.pending = {mode=Current_drawing_mode, points={{x=Drawing.coord(x-16), y=Drawing.coord(y-drawing.y)}}}
  elseif Current_drawing_mode == 'line' or Current_drawing_mode == 'manhattan' then
    local j = Drawing.insert_point(drawing.points, Drawing.coord(x-16), Drawing.coord(y-drawing.y))
    drawing.pending = {mode=Current_drawing_mode, p1=j}
  elseif Current_drawing_mode == 'polygon' then
    local j = Drawing.insert_point(drawing.points, Drawing.coord(x-16), Drawing.coord(y-drawing.y))
    drawing.pending = {mode=Current_drawing_mode, vertices={j}}
  elseif Current_drawing_mode == 'circle' then
    local j = Drawing.insert_point(drawing.points, Drawing.coord(x-16), Drawing.coord(y-drawing.y))
    drawing.pending = {mode=Current_drawing_mode, center=j}
  end
  Lines.current = drawing
end

-- a couple of operations on drawings need to constantly check the state of the mouse
function Drawing.update()
  if Lines.current == nil then return end
  local drawing = Lines.current
  assert(drawing.mode == 'drawing')
  local x, y = love.mouse.getX(), love.mouse.getY()
  if love.mouse.isDown('1') then
    if Drawing.in_drawing(drawing, x,y) then
      if drawing.pending.mode == 'freehand' then
        table.insert(drawing.pending.points, {x=Drawing.coord(love.mouse.getX()-16), y=Drawing.coord(love.mouse.getY()-drawing.y)})
      elseif drawing.pending.mode == 'move' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-drawing.y)
        drawing.pending.target_point.x = mx
        drawing.pending.target_point.y = my
      end
    end
  elseif Current_drawing_mode == 'move' then
    if Drawing.in_drawing(drawing, x, y) then
      local mx,my = Drawing.coord(x-16), Drawing.coord(y-drawing.y)
      drawing.pending.target_point.x = mx
      drawing.pending.target_point.y = my
    end
  end
end

function Drawing.mouse_released(x,y, button)
  if Current_drawing_mode == 'move' then
    Current_drawing_mode = Previous_drawing_mode
    Previous_drawing_mode = nil
  elseif Lines.current then
    if Lines.current.pending then
      if Lines.current.pending.mode == 'freehand' then
        -- the last point added during update is good enough
        table.insert(Lines.current.shapes, Lines.current.pending)
      elseif Lines.current.pending.mode == 'line' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local j = Drawing.insert_point(Lines.current.points, mx,my)
          Lines.current.pending.p2 = j
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'manhattan' then
        local p1 = Lines.current.points[Lines.current.pending.p1]
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          if math.abs(mx-p1.x) > math.abs(my-p1.y) then
            local j = Drawing.insert_point(Lines.current.points, mx, p1.y)
            Lines.current.pending.p2 = j
          else
            local j = Drawing.insert_point(Lines.current.points, p1.x, my)
            Lines.current.pending.p2 = j
          end
          local p2 = Lines.current.points[Lines.current.pending.p2]
          love.mouse.setPosition(16+Drawing.pixels(p2.x), Lines.current.y+Drawing.pixels(p2.y))
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'polygon' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local j = Drawing.insert_point(Lines.current.points, mx,my)
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
        table.insert(Lines.current.shapes, Lines.current.pending)
      elseif Lines.current.pending.mode == 'circle' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local center = Lines.current.points[Lines.current.pending.center]
          Lines.current.pending.radius = geom.dist(center.x,center.y, mx,my)
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'arc' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local center = Lines.current.points[Lines.current.pending.center]
          Lines.current.pending.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, Lines.current.pending.end_angle)
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      end
      Lines.current.pending = {}
      Lines.current = nil
    end
  end
  save_to_disk(Lines, Filename)
end

function Drawing.keychord_pressed(chord)
  if chord == 'C-=' then
    Drawing_width = Drawing_width/Zoom
    Zoom = Zoom+0.5
    Drawing_width = Drawing_width*Zoom
  elseif chord == 'C--' then
    Drawing_width = Drawing_width/Zoom
    Zoom = Zoom-0.5
    Drawing_width = Drawing_width*Zoom
  elseif chord == 'C-0' then
    Drawing_width = Drawing_width/Zoom
    Zoom = 1.5
    Drawing_width = Drawing_width*Zoom
  elseif chord == 'C-f' and not love.mouse.isDown('1') then
    Current_drawing_mode = 'freehand'
  elseif chord == 'C-g' and not love.mouse.isDown('1') then
    Current_drawing_mode = 'polygon'
  elseif love.mouse.isDown('1') and chord == 'g' then
    Current_drawing_mode = 'polygon'
    local drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.vertices = {Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)}
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      if drawing.pending.vertices == nil then
        drawing.pending.vertices = {drawing.pending.p1}
      end
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.vertices = {drawing.pending.center}
    end
    drawing.pending.mode = 'polygon'
  elseif love.mouse.isDown('1') and chord == 'p' and Current_drawing_mode == 'polygon' then
    local drawing = Drawing.current_drawing()
    local mx,my = Drawing.coord(love.mouse.getX()-16), Drawing.coord(love.mouse.getY()-drawing.y)
    local j = Drawing.insert_point(drawing.points, mx,my)
    table.insert(drawing.pending.vertices, j)
  elseif chord == 'C-c' and not love.mouse.isDown('1') then
    Current_drawing_mode = 'circle'
  elseif love.mouse.isDown('1') and chord == 'a' and Current_drawing_mode == 'circle' then
    local drawing = Drawing.current_drawing()
    drawing.pending.mode = 'arc'
    local mx,my = Drawing.coord(love.mouse.getX()-16), Drawing.coord(love.mouse.getY()-drawing.y)
    local j = Drawing.insert_point(drawing.points, mx,my)
    local center = drawing.points[drawing.pending.center]
    drawing.pending.radius = geom.dist(center.x,center.y, mx,my)
    drawing.pending.start_angle = geom.angle(center.x,center.y, mx,my)
  elseif love.mouse.isDown('1') and chord == 'c' then
    Current_drawing_mode = 'circle'
    local drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.center = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      drawing.pending.center = drawing.pending.p1
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.center = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'circle'
  elseif love.mouse.isDown('1') and chord == 'l' then
    Current_drawing_mode = 'line'
    local drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'line'
  elseif chord == 'C-l' then
    Current_drawing_mode = 'line'
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      convert_line(drawing, shape)
    end
  elseif love.mouse.isDown('1') and chord == 'm' then
    Current_drawing_mode = 'manhattan'
    local drawing = Drawing.select_drawing_at_mouse()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'line' then
      -- do nothing
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'manhattan'
  elseif chord == 'C-m' and not love.mouse.isDown('1') then
    Current_drawing_mode = 'manhattan'
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      convert_horvert(drawing, shape)
    end
  elseif chord == 'C-s' and not love.mouse.isDown('1') then
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      smoothen(shape)
    end
  elseif chord == 'C-v' and not love.mouse.isDown('1') then
    local drawing,_,p = Drawing.select_point_at_mouse()
    if drawing then
      Previous_drawing_mode = Current_drawing_mode
      Current_drawing_mode = 'move'
      drawing.pending = {mode=Current_drawing_mode, target_point=p}
      Lines.current = drawing
    end
  elseif love.mouse.isDown('1') and chord == 'v' then
    local drawing,_,p = Drawing.select_point_at_mouse()
    if drawing then
      Previous_drawing_mode = Current_drawing_mode
      Current_drawing_mode = 'move'
      drawing.pending = {mode=Current_drawing_mode, target_point=p}
      Lines.current = drawing
    end
  elseif chord == 'C-d' and not love.mouse.isDown('1') then
    local drawing,i,p = Drawing.select_point_at_mouse()
    if drawing then
      for _,shape in ipairs(drawing.shapes) do
        if Drawing.contains_point(shape, i) then
          if shape.mode == 'polygon' then
            local idx = table.find(shape.vertices, i)
            assert(idx)
            table.remove(shape.vertices, idx)
            if #shape.vertices < 3 then
              shape.mode = 'deleted'
            end
          else
            shape.mode = 'deleted'
          end
        end
      end
      drawing.points[i].deleted = true
    end
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      shape.mode = 'deleted'
    end
  elseif chord == 'C-h' and not love.mouse.isDown('1') then
    local drawing = Drawing.select_drawing_at_mouse()
    if drawing then
      drawing.show_help = true
    end
  elseif chord == 'escape' and not love.mouse.isDown('1') then
    for _,line in ipairs(Lines) do
      if line.mode == 'drawing' then
        line.show_help = false
      end
    end
  end
end

function Drawing.current_drawing()
  local x, y = love.mouse.getX(), love.mouse.getY()
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      if Drawing.in_drawing(drawing, x,y) then
        return drawing
      end
    end
  end
  return nil
end

function Drawing.select_shape_at_mouse()
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if Drawing.in_drawing(drawing, x,y) then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-drawing.y)
        for i,shape in ipairs(drawing.shapes) do
          assert(shape)
          if geom.on_shape(mx,my, drawing, shape) then
            return drawing,i,shape
          end
        end
      end
    end
  end
end

function Drawing.select_point_at_mouse()
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if Drawing.in_drawing(drawing, x,y) then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-drawing.y)
        for i,point in ipairs(drawing.points) do
          assert(point)
          if Drawing.near(point, mx,my) then
            return drawing,i,point
          end
        end
      end
    end
  end
end

function Drawing.select_drawing_at_mouse()
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if Drawing.in_drawing(drawing, x,y) then
        return drawing
      end
    end
  end
end

function Drawing.contains_point(shape, p)
  if shape.mode == 'freehand' then
    -- not supported
  elseif shape.mode == 'line' or shape.mode == 'manhattan' then
    return shape.p1 == p or shape.p2 == p
  elseif shape.mode == 'polygon' then
    return table.find(shape.vertices, p)
  elseif shape.mode == 'circle' then
    return shape.center == p
  elseif shape.mode == 'arc' then
    return shape.center == p
    -- ugh, how to support angles
  elseif shape.mode == 'deleted' then
    -- already done
  else
    print(shape.mode)
    assert(false)
  end
end

function Drawing.convert_line(drawing, shape)
  -- Perhaps we should do a more sophisticated "simple linear regression"
  -- here:
  --   https://en.wikipedia.org/wiki/Linear_regression#Simple_and_multiple_linear_regression
  -- But this works well enough for close-to-linear strokes.
  assert(shape.mode == 'freehand')
  shape.mode = 'line'
  shape.p1 = insert_point(drawing.points, shape.points[1].x, shape.points[1].y)
  local n = #shape.points
  shape.p2 = insert_point(drawing.points, shape.points[n].x, shape.points[n].y)
end

-- turn a line either horizontal or vertical
function Drawing.convert_horvert(drawing, shape)
  if shape.mode == 'freehand' then
    convert_line(shape)
  end
  assert(shape.mode == 'line')
  local p1 = drawing.points[shape.p1]
  local p2 = drawing.points[shape.p2]
  if math.abs(p1.x-p2.x) > math.abs(p1.y-p2.y) then
    p2.y = p1.y
  else
    p2.x = p1.x
  end
end

function Drawing.smoothen(shape)
  assert(shape.mode == 'freehand')
  for _=1,7 do
    for i=2,#shape.points-1 do
      local a = shape.points[i-1]
      local b = shape.points[i]
      local c = shape.points[i+1]
      b.x = (a.x + b.x + c.x)/3
      b.y = (a.y + b.y + c.y)/3
    end
  end
end

function Drawing.insert_point(points, x,y)
  for i,point in ipairs(points) do
    if Drawing.near(point, x,y) then
      return i
    end
  end
  table.insert(points, {x=x, y=y})
  return #points
end

function Drawing.near(point, x,y)
  local px,py = Drawing.pixels(x),Drawing.pixels(y)
  local cx,cy = Drawing.pixels(point.x), Drawing.pixels(point.y)
  return (cx-px)*(cx-px) + (cy-py)*(cy-py) < 16
end

function Drawing.pixels(n)  -- parts to pixels
  return n*Drawing_width/256
end
function Drawing.coord(n)  -- pixels to parts
  return math.floor(n*256/Drawing_width)
end

function table.find(h, x)
  for k,v in pairs(h) do
    if v == x then
      return k
    end
  end
end

return Drawing
