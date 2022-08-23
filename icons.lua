icon = {}

function icon.insert_drawing(button_params)
  local x,y = button_params.x, button_params.y
  App.color(Icon_color)
  love.graphics.rectangle('line', x,y, 12,12)
  love.graphics.line(4,y+6, 16,y+6)
  love.graphics.line(10,y, 10,y+12)
end

function icon.freehand(x, y)
  love.graphics.line(x+4,y+7,x+5,y+5)
  love.graphics.line(x+5,y+5,x+7,y+4)
  love.graphics.line(x+7,y+4,x+9,y+3)
  love.graphics.line(x+9,y+3,x+10,y+5)
  love.graphics.line(x+10,y+5,x+12,y+6)
  love.graphics.line(x+12,y+6,x+13,y+8)
  love.graphics.line(x+13,y+8,x+13,y+10)
  love.graphics.line(x+13,y+10,x+14,y+12)
  love.graphics.line(x+14,y+12,x+15,y+14)
  love.graphics.line(x+15,y+14,x+15,y+16)
end

function icon.line(x, y)
  love.graphics.line(x+4,y+2, x+16,y+18)
end

function icon.manhattan(x, y)
  love.graphics.line(x+4,y+20, x+4,y+2)
  love.graphics.line(x+4,y+2, x+10,y+2)
  love.graphics.line(x+10,y+2, x+10,y+10)
  love.graphics.line(x+10,y+10, x+18,y+10)
end

function icon.polygon(x, y)
  love.graphics.line(x+8,y+2, x+14,y+2)
  love.graphics.line(x+14,y+2, x+18,y+10)
  love.graphics.line(x+18,y+10, x+10,y+18)
  love.graphics.line(x+10,y+18, x+4,y+12)
  love.graphics.line(x+4,y+12, x+8,y+2)
end

function icon.rectangle(x, y)
  love.graphics.line(x+4,y+8, x+4,y+16)
  love.graphics.line(x+4,y+16, x+16,y+16)
  love.graphics.line(x+16,y+16, x+16,y+8)
  love.graphics.line(x+16,y+8, x+4,y+8)
end

function icon.square(x, y)
  love.graphics.line(x+6,y+6, x+6,y+16)
  love.graphics.line(x+6,y+16, x+16,y+16)
  love.graphics.line(x+16,y+16, x+16,y+6)
  love.graphics.line(x+16,y+6, x+6,y+6)
end

function icon.circle(x, y)
  love.graphics.circle('line', x+10,y+10, 8)
end
