-- primitives for editing drawings
Drawing = {}
require 'drawing_tests'

-- All drawings span 100% of some conceptual 'page width' and divide it up
-- into 256 parts.
function Drawing.draw(State, line)
  local pmx,pmy = App.mouse_x(), App.mouse_y()
  if pmx < State.right and pmy > line.y and pmy < line.y+Drawing.pixels(line.h, State.width) then
    App.color(Icon_color)
    love.graphics.rectangle('line', State.left,line.y, State.width,Drawing.pixels(line.h, State.width))
    if icon[State.current_drawing_mode] then
      icon[State.current_drawing_mode](State.right-22, line.y+4)
    else
      icon[State.previous_drawing_mode](State.right-22, line.y+4)
    end

    if App.mouse_down(1) and love.keyboard.isDown('h') then
      draw_help_with_mouse_pressed(State, line)
      return
    end
  end

  if line.show_help then
    draw_help_without_mouse_pressed(State, line)
    return
  end

  local mx,my = Drawing.coord(pmx-State.left), Drawing.coord(pmy-line.y)

  for _,shape in ipairs(line.shapes) do
    assert(shape)
    if geom.on_shape(mx,my, line, shape) then
      App.color(Focus_stroke_color)
    else
      App.color(Stroke_color)
    end
    Drawing.draw_shape(line, shape, line.y, State.left,State.right)
  end
  for i,p in ipairs(line.points) do
    if p.deleted == nil then
      if Drawing.near(p, mx,my, State.width) then
        App.color(Focus_stroke_color)
        love.graphics.circle('line', Drawing.pixels(p.x, State.width)+State.left,Drawing.pixels(p.y, State.width)+line.y, Same_point_distance)
      else
        App.color(Stroke_color)
        love.graphics.circle('fill', Drawing.pixels(p.x, State.width)+State.left,Drawing.pixels(p.y, State.width)+line.y, 2)
      end
      if p.name then
        -- TODO: clip
        local x,y = Drawing.pixels(p.x, State.width)+State.left+5, Drawing.pixels(p.y, State.width)+line.y+5
        love.graphics.print(p.name, x,y)
        if State.current_drawing_mode == 'name' and i == line.pending.target_point then
          -- create a faint red box for the name
          App.color(Current_name_background_color)
          local name_text
          -- TODO: avoid computing name width on every repaint
          if p.name == '' then
            name_text = State.em
          else
            name_text = App.newText(love.graphics.getFont(), p.name)
          end
          love.graphics.rectangle('fill', x,y, App.width(name_text), State.line_height)
        end
      end
    end
  end
  App.color(Current_stroke_color)
  Drawing.draw_pending_shape(line, line.y, State.left,State.right)
end

function Drawing.draw_shape(drawing, shape, top, left,right)
  local width = right-left
  if shape.mode == 'freehand' then
    local prev = nil
    for _,point in ipairs(shape.points) do
      if prev then
        love.graphics.line(Drawing.pixels(prev.x, width)+left,Drawing.pixels(prev.y, width)+top, Drawing.pixels(point.x, width)+left,Drawing.pixels(point.y, width)+top)
      end
      prev = point
    end
  elseif shape.mode == 'line' or shape.mode == 'manhattan' then
    local p1 = drawing.points[shape.p1]
    local p2 = drawing.points[shape.p2]
    love.graphics.line(Drawing.pixels(p1.x, width)+left,Drawing.pixels(p1.y, width)+top, Drawing.pixels(p2.x, width)+left,Drawing.pixels(p2.y, width)+top)
  elseif shape.mode == 'polygon' or shape.mode == 'rectangle' or shape.mode == 'square' then
    local prev = nil
    for _,point in ipairs(shape.vertices) do
      local curr = drawing.points[point]
      if prev then
        love.graphics.line(Drawing.pixels(prev.x, width)+left,Drawing.pixels(prev.y, width)+top, Drawing.pixels(curr.x, width)+left,Drawing.pixels(curr.y, width)+top)
      end
      prev = curr
    end
    -- close the loop
    local curr = drawing.points[shape.vertices[1]]
    love.graphics.line(Drawing.pixels(prev.x, width)+left,Drawing.pixels(prev.y, width)+top, Drawing.pixels(curr.x, width)+left,Drawing.pixels(curr.y, width)+top)
  elseif shape.mode == 'circle' then
    -- TODO: clip
    local center = drawing.points[shape.center]
    love.graphics.circle('line', Drawing.pixels(center.x, width)+left,Drawing.pixels(center.y, width)+top, Drawing.pixels(shape.radius, width))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    love.graphics.arc('line', 'open', Drawing.pixels(center.x, width)+left,Drawing.pixels(center.y, width)+top, Drawing.pixels(shape.radius, width), shape.start_angle, shape.end_angle, 360)
  elseif shape.mode == 'deleted' then
    -- ignore
  else
    print(shape.mode)
    assert(false)
  end
end

function Drawing.draw_pending_shape(drawing, top, left,right)
  local width = right-left
  local shape = drawing.pending
  if shape.mode == nil then
    -- nothing pending
  elseif shape.mode == 'freehand' then
    local shape_copy = deepcopy(shape)
    Drawing.smoothen(shape_copy)
    Drawing.draw_shape(drawing, shape_copy, top, left,right)
  elseif shape.mode == 'line' then
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local p1 = drawing.points[shape.p1]
    love.graphics.line(Drawing.pixels(p1.x, width)+left,Drawing.pixels(p1.y, width)+top, Drawing.pixels(mx, width)+left,Drawing.pixels(my, width)+top)
  elseif shape.mode == 'manhattan' then
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local p1 = drawing.points[shape.p1]
    if math.abs(mx-p1.x) > math.abs(my-p1.y) then
      love.graphics.line(Drawing.pixels(p1.x, width)+left,Drawing.pixels(p1.y, width)+top, Drawing.pixels(mx, width)+left,Drawing.pixels(p1.y, width)+top)
    else
      love.graphics.line(Drawing.pixels(p1.x, width)+left,Drawing.pixels(p1.y, width)+top, Drawing.pixels(p1.x, width)+left,Drawing.pixels(my, width)+top)
    end
  elseif shape.mode == 'polygon' then
    -- don't close the loop on a pending polygon
    local prev = nil
    for _,point in ipairs(shape.vertices) do
      local curr = drawing.points[point]
      if prev then
        love.graphics.line(Drawing.pixels(prev.x, width)+left,Drawing.pixels(prev.y, width)+top, Drawing.pixels(curr.x, width)+left,Drawing.pixels(curr.y, width)+top)
      end
      prev = curr
    end
    love.graphics.line(Drawing.pixels(prev.x, width)+left,Drawing.pixels(prev.y, width)+top, App.mouse_x(),App.mouse_y())
  elseif shape.mode == 'rectangle' then
    local pmx,pmy = App.mouse_x(), App.mouse_y()
    local first = drawing.points[shape.vertices[1]]
    if #shape.vertices == 1 then
      love.graphics.line(Drawing.pixels(first.x, width)+left,Drawing.pixels(first.y, width)+top, pmx,pmy)
      return
    end
    local second = drawing.points[shape.vertices[2]]
    local mx,my = Drawing.coord(pmx-left), Drawing.coord(pmy-top)
    local thirdx,thirdy, fourthx,fourthy = Drawing.complete_rectangle(first.x,first.y, second.x,second.y, mx,my)
    love.graphics.line(Drawing.pixels(first.x, width)+left,Drawing.pixels(first.y, width)+top, Drawing.pixels(second.x, width)+left,Drawing.pixels(second.y, width)+top)
    love.graphics.line(Drawing.pixels(second.x, width)+left,Drawing.pixels(second.y, width)+top, Drawing.pixels(thirdx, width)+left,Drawing.pixels(thirdy, width)+top)
    love.graphics.line(Drawing.pixels(thirdx, width)+left,Drawing.pixels(thirdy, width)+top, Drawing.pixels(fourthx, width)+left,Drawing.pixels(fourthy, width)+top)
    love.graphics.line(Drawing.pixels(fourthx, width)+left,Drawing.pixels(fourthy, width)+top, Drawing.pixels(first.x, width)+left,Drawing.pixels(first.y, width)+top)
  elseif shape.mode == 'square' then
    local pmx,pmy = App.mouse_x(), App.mouse_y()
    local first = drawing.points[shape.vertices[1]]
    if #shape.vertices == 1 then
      love.graphics.line(Drawing.pixels(first.x, width)+left,Drawing.pixels(first.y, width)+top, pmx,pmy)
      return
    end
    local second = drawing.points[shape.vertices[2]]
    local mx,my = Drawing.coord(pmx-left), Drawing.coord(pmy-top)
    local thirdx,thirdy, fourthx,fourthy = Drawing.complete_square(first.x,first.y, second.x,second.y, mx,my)
    love.graphics.line(Drawing.pixels(first.x, width)+left,Drawing.pixels(first.y, width)+top, Drawing.pixels(second.x, width)+left,Drawing.pixels(second.y, width)+top)
    love.graphics.line(Drawing.pixels(second.x, width)+left,Drawing.pixels(second.y, width)+top, Drawing.pixels(thirdx, width)+left,Drawing.pixels(thirdy, width)+top)
    love.graphics.line(Drawing.pixels(thirdx, width)+left,Drawing.pixels(thirdy, width)+top, Drawing.pixels(fourthx, width)+left,Drawing.pixels(fourthy, width)+top)
    love.graphics.line(Drawing.pixels(fourthx, width)+left,Drawing.pixels(fourthy, width)+top, Drawing.pixels(first.x, width)+left,Drawing.pixels(first.y, width)+top)
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local cx,cy = Drawing.pixels(center.x, width)+left, Drawing.pixels(center.y, width)+top
    love.graphics.circle('line', cx,cy, geom.dist(cx,cy, App.mouse_x(),App.mouse_y()))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    local mx,my = Drawing.coord(App.mouse_x()-left), Drawing.coord(App.mouse_y()-top)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    shape.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, shape.end_angle)
    local cx,cy = Drawing.pixels(center.x, width)+left, Drawing.pixels(center.y, width)+top
    love.graphics.arc('line', 'open', cx,cy, Drawing.pixels(shape.radius, width), shape.start_angle, shape.end_angle, 360)
  elseif shape.mode == 'move' then
    -- nothing pending; changes are immediately committed
  elseif shape.mode == 'name' then
    -- nothing pending; changes are immediately committed
  else
    print(shape.mode)
    assert(false)
  end
end


function Drawing.in_drawing(drawing, x,y, left,right)
  if drawing.y == nil then return false end  -- outside current page
  local width = right-left
  return y >= drawing.y and y < drawing.y + Drawing.pixels(drawing.h, width) and x >= left and x < right
end

function Drawing.mouse_pressed(State, drawing, x,y, button)
  if State.current_drawing_mode == 'freehand' then
    drawing.pending = {mode=State.current_drawing_mode, points={{x=Drawing.coord(x-State.left), y=Drawing.coord(y-drawing.y)}}}
  elseif State.current_drawing_mode == 'line' or State.current_drawing_mode == 'manhattan' then
    local j = Drawing.find_or_insert_point(drawing.points, Drawing.coord(x-State.left), Drawing.coord(y-drawing.y), State.width)
    drawing.pending = {mode=State.current_drawing_mode, p1=j}
  elseif State.current_drawing_mode == 'polygon' or State.current_drawing_mode == 'rectangle' or State.current_drawing_mode == 'square' then
    local j = Drawing.find_or_insert_point(drawing.points, Drawing.coord(x-State.left), Drawing.coord(y-drawing.y), State.width)
    drawing.pending = {mode=State.current_drawing_mode, vertices={j}}
  elseif State.current_drawing_mode == 'circle' then
    local j = Drawing.find_or_insert_point(drawing.points, Drawing.coord(x-State.left), Drawing.coord(y-drawing.y), State.width)
    drawing.pending = {mode=State.current_drawing_mode, center=j}
  elseif State.current_drawing_mode == 'move' then
    -- all the action is in mouse_released
  elseif State.current_drawing_mode == 'name' then
    -- nothing
  else
    print(State.current_drawing_mode)
    assert(false)
  end
end

-- a couple of operations on drawings need to constantly check the state of the mouse
function Drawing.update(State)
  if State.lines.current_drawing == nil then return end
  local drawing = State.lines.current_drawing
  assert(drawing.mode == 'drawing')
  local x, y = App.mouse_x(), App.mouse_y()
  if App.mouse_down(1) then
    if Drawing.in_drawing(drawing, x,y, State.left,State.right) then
      if drawing.pending.mode == 'freehand' then
        table.insert(drawing.pending.points, {x=Drawing.coord(App.mouse_x()-State.left), y=Drawing.coord(App.mouse_y()-drawing.y)})
      elseif drawing.pending.mode == 'move' then
        local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
        drawing.pending.target_point.x = mx
        drawing.pending.target_point.y = my
        Drawing.relax_constraints(drawing, drawing.pending.target_point_index)
      end
    end
  elseif State.current_drawing_mode == 'move' then
    if Drawing.in_drawing(drawing, x, y, State.left,State.right) then
      local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
      drawing.pending.target_point.x = mx
      drawing.pending.target_point.y = my
      Drawing.relax_constraints(drawing, drawing.pending.target_point_index)
    end
  else
    -- do nothing
  end
end

function Drawing.relax_constraints(drawing, p)
  for _,shape in ipairs(drawing.shapes) do
    if shape.mode == 'manhattan' then
      if shape.p1 == p then
        shape.mode = 'line'
      elseif shape.p2 == p then
        shape.mode = 'line'
      end
    elseif shape.mode == 'rectangle' or shape.mode == 'square' then
      for _,v in ipairs(shape.vertices) do
        if v == p then
          shape.mode = 'polygon'
        end
      end
    end
  end
end

function Drawing.mouse_released(State, x,y, button)
  if State.current_drawing_mode == 'move' then
    State.current_drawing_mode = State.previous_drawing_mode
    State.previous_drawing_mode = nil
    if State.lines.current_drawing then
      State.lines.current_drawing.pending = {}
      State.lines.current_drawing = nil
    end
  elseif State.lines.current_drawing then
    local drawing = State.lines.current_drawing
    if drawing.pending then
      if drawing.pending.mode == nil then
        -- nothing pending
      elseif drawing.pending.mode == 'freehand' then
        -- the last point added during update is good enough
        Drawing.smoothen(drawing.pending)
        table.insert(drawing.shapes, drawing.pending)
      elseif drawing.pending.mode == 'line' then
        local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          drawing.pending.p2 = Drawing.find_or_insert_point(drawing.points, mx,my, State.width)
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'manhattan' then
        local p1 = drawing.points[drawing.pending.p1]
        local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          if math.abs(mx-p1.x) > math.abs(my-p1.y) then
            drawing.pending.p2 = Drawing.find_or_insert_point(drawing.points, mx, p1.y, State.width)
          else
            drawing.pending.p2 = Drawing.find_or_insert_point(drawing.points, p1.x, my, State.width)
          end
          local p2 = drawing.points[drawing.pending.p2]
          App.mouse_move(State.left+Drawing.pixels(p2.x, State.width), drawing.y+Drawing.pixels(p2.y, State.width))
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'polygon' then
        local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          table.insert(drawing.pending.vertices, Drawing.find_or_insert_point(drawing.points, mx,my, State.width))
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'rectangle' then
        assert(#drawing.pending.vertices <= 2)
        if #drawing.pending.vertices == 2 then
          local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
          if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
            local first = drawing.points[drawing.pending.vertices[1]]
            local second = drawing.points[drawing.pending.vertices[2]]
            local thirdx,thirdy, fourthx,fourthy = Drawing.complete_rectangle(first.x,first.y, second.x,second.y, mx,my)
            table.insert(drawing.pending.vertices, Drawing.find_or_insert_point(drawing.points, thirdx,thirdy, State.width))
            table.insert(drawing.pending.vertices, Drawing.find_or_insert_point(drawing.points, fourthx,fourthy, State.width))
            table.insert(drawing.shapes, drawing.pending)
          end
        else
          -- too few points; draw nothing
        end
      elseif drawing.pending.mode == 'square' then
        assert(#drawing.pending.vertices <= 2)
        if #drawing.pending.vertices == 2 then
          local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
          if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
            local first = drawing.points[drawing.pending.vertices[1]]
            local second = drawing.points[drawing.pending.vertices[2]]
            local thirdx,thirdy, fourthx,fourthy = Drawing.complete_square(first.x,first.y, second.x,second.y, mx,my)
            table.insert(drawing.pending.vertices, Drawing.find_or_insert_point(drawing.points, thirdx,thirdy, State.width))
            table.insert(drawing.pending.vertices, Drawing.find_or_insert_point(drawing.points, fourthx,fourthy, State.width))
            table.insert(drawing.shapes, drawing.pending)
          end
        end
      elseif drawing.pending.mode == 'circle' then
        local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          local center = drawing.points[drawing.pending.center]
          drawing.pending.radius = geom.dist(center.x,center.y, mx,my)
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'arc' then
        local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < drawing.h then
          local center = drawing.points[drawing.pending.center]
          drawing.pending.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, drawing.pending.end_angle)
          table.insert(drawing.shapes, drawing.pending)
        end
      elseif drawing.pending.mode == 'name' then
        -- drop it
      else
        print(drawing.pending.mode)
        assert(false)
      end
      State.lines.current_drawing.pending = {}
      State.lines.current_drawing = nil
    end
  end
end

function Drawing.keychord_pressed(State, chord)
  if chord == 'C-p' and not App.mouse_down(1) then
    State.current_drawing_mode = 'freehand'
  elseif App.mouse_down(1) and chord == 'l' then
    State.current_drawing_mode = 'line'
    local _,drawing = Drawing.current_drawing(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'rectangle' or drawing.pending.mode == 'square' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'line'
  elseif chord == 'C-l' and not App.mouse_down(1) then
    State.current_drawing_mode = 'line'
  elseif App.mouse_down(1) and chord == 'm' then
    State.current_drawing_mode = 'manhattan'
    local drawing = Drawing.select_drawing_at_mouse(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)
    elseif drawing.pending.mode == 'line' then
      -- do nothing
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'rectangle' or drawing.pending.mode == 'square' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'manhattan'
  elseif chord == 'C-m' and not App.mouse_down(1) then
    State.current_drawing_mode = 'manhattan'
  elseif chord == 'C-g' and not App.mouse_down(1) then
    State.current_drawing_mode = 'polygon'
  elseif App.mouse_down(1) and chord == 'g' then
    State.current_drawing_mode = 'polygon'
    local _,drawing = Drawing.current_drawing(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.vertices = {Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)}
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      if drawing.pending.vertices == nil then
        drawing.pending.vertices = {drawing.pending.p1}
      end
    elseif drawing.pending.mode == 'rectangle' or drawing.pending.mode == 'square' then
      -- reuse existing vertices
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.vertices = {drawing.pending.center}
    end
    drawing.pending.mode = 'polygon'
  elseif chord == 'C-r' and not App.mouse_down(1) then
    State.current_drawing_mode = 'rectangle'
  elseif App.mouse_down(1) and chord == 'r' then
    State.current_drawing_mode = 'rectangle'
    local _,drawing = Drawing.current_drawing(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.vertices = {Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)}
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      if drawing.pending.vertices == nil then
        drawing.pending.vertices = {drawing.pending.p1}
      end
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'square' then
      -- reuse existing (1-2) vertices
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.vertices = {drawing.pending.center}
    end
    drawing.pending.mode = 'rectangle'
  elseif chord == 'C-s' and not App.mouse_down(1) then
    State.current_drawing_mode = 'square'
  elseif App.mouse_down(1) and chord == 's' then
    State.current_drawing_mode = 'square'
    local _,drawing = Drawing.current_drawing(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.vertices = {Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)}
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      if drawing.pending.vertices == nil then
        drawing.pending.vertices = {drawing.pending.p1}
      end
    elseif drawing.pending.mode == 'polygon' then
      while #drawing.pending.vertices > 2 do
        table.remove(drawing.pending.vertices)
      end
    elseif drawing.pending.mode == 'rectangle' then
      -- reuse existing (1-2) vertices
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.vertices = {drawing.pending.center}
    end
    drawing.pending.mode = 'square'
  elseif App.mouse_down(1) and chord == 'p' and State.current_drawing_mode == 'polygon' then
    local _,drawing = Drawing.current_drawing(State)
    local mx,my = Drawing.coord(App.mouse_x()-State.left), Drawing.coord(App.mouse_y()-drawing.y)
    local j = Drawing.find_or_insert_point(drawing.points, mx,my, State.width)
    table.insert(drawing.pending.vertices, j)
  elseif App.mouse_down(1) and chord == 'p' and (State.current_drawing_mode == 'rectangle' or State.current_drawing_mode == 'square') then
    local _,drawing = Drawing.current_drawing(State)
    local mx,my = Drawing.coord(App.mouse_x()-State.left), Drawing.coord(App.mouse_y()-drawing.y)
    local j = Drawing.find_or_insert_point(drawing.points, mx,my, State.width)
    while #drawing.pending.vertices >= 2 do
      table.remove(drawing.pending.vertices)
    end
    table.insert(drawing.pending.vertices, j)
  elseif chord == 'C-o' and not App.mouse_down(1) then
    State.current_drawing_mode = 'circle'
  elseif App.mouse_down(1) and chord == 'a' and State.current_drawing_mode == 'circle' then
    local _,drawing = Drawing.current_drawing(State)
    drawing.pending.mode = 'arc'
    local mx,my = Drawing.coord(App.mouse_x()-State.left), Drawing.coord(App.mouse_y()-drawing.y)
    local center = drawing.points[drawing.pending.center]
    drawing.pending.radius = geom.dist(center.x,center.y, mx,my)
    drawing.pending.start_angle = geom.angle(center.x,center.y, mx,my)
  elseif App.mouse_down(1) and chord == 'o' then
    State.current_drawing_mode = 'circle'
    local _,drawing = Drawing.current_drawing(State)
    if drawing.pending.mode == 'freehand' then
      drawing.pending.center = Drawing.find_or_insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y, State.width)
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      drawing.pending.center = drawing.pending.p1
    elseif drawing.pending.mode == 'polygon' or drawing.pending.mode == 'rectangle' or drawing.pending.mode == 'square' then
      drawing.pending.center = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'circle'
  elseif chord == 'C-u' and not App.mouse_down(1) then
    local drawing_index,drawing,i,p = Drawing.select_point_at_mouse(State)
    if drawing then
      if State.previous_drawing_mode == nil then
        State.previous_drawing_mode = State.current_drawing_mode
      end
      State.current_drawing_mode = 'move'
      drawing.pending = {mode=State.current_drawing_mode, target_point=p, target_point_index=i}
      State.lines.current_drawing_index = drawing_index
      State.lines.current_drawing = drawing
    end
  elseif chord == 'C-n' and not App.mouse_down(1) then
    local drawing_index,drawing,point_index,p = Drawing.select_point_at_mouse(State)
    if drawing then
      if State.previous_drawing_mode == nil then
        -- don't clobber
        State.previous_drawing_mode = State.current_drawing_mode
      end
      State.current_drawing_mode = 'name'
      p.name = ''
      drawing.pending = {mode=State.current_drawing_mode, target_point=point_index}
      State.lines.current_drawing_index = drawing_index
      State.lines.current_drawing = drawing
    end
  elseif chord == 'C-d' and not App.mouse_down(1) then
    local _,drawing,i,p = Drawing.select_point_at_mouse(State)
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
    local drawing,_,shape = Drawing.select_shape_at_mouse(State)
    if drawing then
      shape.mode = 'deleted'
    end
  elseif chord == 'C-h' and not App.mouse_down(1) then
    local drawing = Drawing.select_drawing_at_mouse(State)
    if drawing then
      drawing.show_help = true
    end
  elseif chord == 'escape' and App.mouse_down(1) then
    local _,drawing = Drawing.current_drawing(State)
    drawing.pending = {}
  end
end

function Drawing.complete_rectangle(firstx,firsty, secondx,secondy, x,y)
  if firstx == secondx then
    return x,secondy, x,firsty
  end
  if firsty == secondy then
    return secondx,y, firstx,y
  end
  local first_slope = (secondy-firsty)/(secondx-firstx)
  -- slope of second edge:
  --    -1/first_slope
  -- equation of line containing the second edge:
  --    y-secondy = -1/first_slope*(x-secondx)
  -- => 1/first_slope*x + y + (- secondy - secondx/first_slope) = 0
  -- now we want to find the point on this line that's closest to the mouse pointer.
  -- https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Line_defined_by_an_equation
  local a = 1/first_slope
  local c = -secondy - secondx/first_slope
  local thirdx = ((x-a*y) - a*c) / (a*a + 1)
  local thirdy = (a*(-x + a*y) - c) / (a*a + 1)
  -- slope of third edge = first_slope
  -- equation of line containing third edge:
  --     y - thirdy = first_slope*(x-thirdx)
  --  => -first_slope*x + y + (-thirdy + thirdx*first_slope) = 0
  -- now we want to find the point on this line that's closest to the first point
  local a = -first_slope
  local c = -thirdy + thirdx*first_slope
  local fourthx = ((firstx-a*firsty) - a*c) / (a*a + 1)
  local fourthy = (a*(-firstx + a*firsty) - c) / (a*a + 1)
  return thirdx,thirdy, fourthx,fourthy
end

function Drawing.complete_square(firstx,firsty, secondx,secondy, x,y)
  -- use x,y only to decide which side of the first edge to complete the square on
  local deltax = secondx-firstx
  local deltay = secondy-firsty
  local thirdx = secondx+deltay
  local thirdy = secondy-deltax
  if not geom.same_side(firstx,firsty, secondx,secondy, thirdx,thirdy, x,y) then
    deltax = -deltax
    deltay = -deltay
    thirdx = secondx+deltay
    thirdy = secondy-deltax
  end
  local fourthx = firstx+deltay
  local fourthy = firsty-deltax
  return thirdx,thirdy, fourthx,fourthy
end

function Drawing.current_drawing(State)
  local x, y = App.mouse_x(), App.mouse_y()
  for drawing_index,drawing in ipairs(State.lines) do
    if drawing.mode == 'drawing' then
      if Drawing.in_drawing(drawing, x,y, State.left,State.right) then
        return drawing_index,drawing
      end
    end
  end
  return nil
end

function Drawing.select_shape_at_mouse(State)
  for _,drawing in ipairs(State.lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      if Drawing.in_drawing(drawing, x,y, State.left,State.right) then
        local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
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

function Drawing.select_point_at_mouse(State)
  for drawing_index,drawing in ipairs(State.lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      if Drawing.in_drawing(drawing, x,y, State.left,State.right) then
        local mx,my = Drawing.coord(x-State.left), Drawing.coord(y-drawing.y)
        for i,point in ipairs(drawing.points) do
          assert(point)
          if Drawing.near(point, mx,my, State.width) then
            return drawing_index,drawing,i,point
          end
        end
      end
    end
  end
end

function Drawing.select_drawing_at_mouse(State)
  for _,drawing in ipairs(State.lines) do
    if drawing.mode == 'drawing' then
      local x, y = App.mouse_x(), App.mouse_y()
      if Drawing.in_drawing(drawing, x,y, State.left,State.right) then
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
  elseif shape.mode == 'polygon' or shape.mode == 'rectangle' or shape.mode == 'square' then
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
  table.insert(points, {x=x, y=y})
  return #points
end

function Drawing.find_or_insert_point(points, x,y, width)
  -- check if UI would snap the two points together
  for i,point in ipairs(points) do
    if Drawing.near(point, x,y, width) then
      return i
    end
  end
  table.insert(points, {x=x, y=y})
  return #points
end

function Drawing.near(point, x,y, width)
  local px,py = Drawing.pixels(x, width),Drawing.pixels(y, width)
  local cx,cy = Drawing.pixels(point.x, width), Drawing.pixels(point.y, width)
  return (cx-px)*(cx-px) + (cy-py)*(cy-py) < Same_point_distance*Same_point_distance
end

function Drawing.pixels(n, width)  -- parts to pixels
  return math.floor(n*width/256)
end
function Drawing.coord(n)  -- pixels to parts
  return math.floor(n*256/Editor_state.width)
end

function table.find(h, x)
  for k,v in pairs(h) do
    if v == x then
      return k
    end
  end
end
