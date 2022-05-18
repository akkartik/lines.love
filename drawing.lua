-- primitives for editing drawings
Drawing = {}

function Drawing.draw(line, y)
  local pmx,pmy = love.mouse.getX(), love.mouse.getY()
  if pmx < 16+Drawing_width and pmy > line.y and pmy < line.y+pixels(line.h) then
    love.graphics.setColor(0.75,0.75,0.75)
    love.graphics.rectangle('line', 16,line.y, Drawing_width,pixels(line.h))
    if icon[Current_mode] then
      icon[Current_mode](16+Drawing_width-20, line.y+4)
    else
      icon[Previous_mode](16+Drawing_width-20, line.y+4)
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

  local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-line.y)

  for _,shape in ipairs(line.shapes) do
    assert(shape)
    if on_shape(mx,my, line, shape) then
      love.graphics.setColor(1,0,0)
    else
      love.graphics.setColor(0,0,0)
    end
    draw_shape(16,line.y, line, shape)
  end
  for _,p in ipairs(line.points) do
    if p.deleted == nil then
      if near(p, mx,my) then
        love.graphics.setColor(1,0,0)
        love.graphics.circle('line', pixels(p.x)+16,pixels(p.y)+line.y, 4)
      else
        love.graphics.setColor(0,0,0)
        love.graphics.circle('fill', pixels(p.x)+16,pixels(p.y)+line.y, 2)
      end
    end
  end
  draw_pending_shape(16,line.y, line)
end

return Drawing
