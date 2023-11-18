geom = {}

function geom.on_shape(x,y, drawing, shape)
  if shape.mode == 'freehand' then
    return geom.on_freehand(x,y, drawing, shape)
  elseif shape.mode == 'line' then
    return geom.on_line(x,y, drawing, shape)
  elseif shape.mode == 'manhattan' then
    local p1 = drawing.points[shape.p1]
    local p2 = drawing.points[shape.p2]
    if p1.x == p2.x then
      if x ~= p1.x then return false end
      local y1,y2 = p1.y, p2.y
      if y1 > y2 then
        y1,y2 = y2,y1
      end
      return y >= y1-2 and y <= y2+2
    elseif p1.y == p2.y then
      if y ~= p1.y then return false end
      local x1,x2 = p1.x, p2.x
      if x1 > x2 then
        x1,x2 = x2,x1
      end
      return x >= x1-2 and x <= x2+2
    end
  elseif shape.mode == 'polygon' or shape.mode == 'rectangle' or shape.mode == 'square' then
    return geom.on_polygon(x,y, drawing, shape)
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    local dist = geom.dist(center.x,center.y, x,y)
    return dist > shape.radius*0.95 and dist < shape.radius*1.05
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    local dist = geom.dist(center.x,center.y, x,y)
    if dist < shape.radius*0.95 or dist > shape.radius*1.05 then
      return false
    end
    return geom.angle_between(center.x,center.y, x,y, shape.start_angle,shape.end_angle)
  elseif shape.mode == 'deleted' then
  else
    assert(false, ('unknown drawing mode %s'):format(shape.mode))
  end
end

function geom.on_freehand(x,y, drawing, shape)
  local prev
  for _,p in ipairs(shape.points) do
    if prev then
      if geom.on_line(x,y, drawing, {p1=prev, p2=p}) then
        return true
      end
    end
    prev = p
  end
  return false
end

function geom.on_line(x,y, drawing, shape)
  local p1,p2
  if type(shape.p1) == 'number' then
    p1 = drawing.points[shape.p1]
    p2 = drawing.points[shape.p2]
  else
    p1 = shape.p1
    p2 = shape.p2
  end
  if p1.x == p2.x then
    if math.abs(p1.x-x) > 2 then
      return false
    end
    local y1,y2 = p1.y,p2.y
    if y1 > y2 then
      y1,y2 = y2,y1
    end
    return y >= y1-2 and y <= y2+2
  end
  -- has the right slope and intercept
  local m = (p2.y - p1.y) / (p2.x - p1.x)
  local yp = p1.y + m*(x-p1.x)
  if yp < y-2 or yp > y+2 then
    return false
  end
  -- between endpoints
  local k = (x-p1.x) / (p2.x-p1.x)
  return k > -0.005 and k < 1.005
end

function geom.on_polygon(x,y, drawing, shape)
  local prev
  for _,p in ipairs(shape.vertices) do
    if prev then
      if geom.on_line(x,y, drawing, {p1=prev, p2=p}) then
        return true
      end
    end
    prev = p
  end
  return geom.on_line(x,y, drawing, {p1=shape.vertices[1], p2=shape.vertices[#shape.vertices]})
end

-- are (x3,y3) and (x4,y4) on the same side of the line between (x1,y1) and (x2,y2)
function geom.same_side(x1,y1, x2,y2, x3,y3, x4,y4)
  if x1 == x2 then
    return math.sign(x3-x1) == math.sign(x4-x1)
  end
  if y1 == y2 then
    return math.sign(y3-y1) == math.sign(y4-y1)
  end
  local m = (y2-y1)/(x2-x1)
  return math.sign(m*(x3-x1) + y1-y3) == math.sign(m*(x4-x1) + y1-y4)
end

function math.sign(x)
  if x > 0 then
    return 1
  elseif x == 0 then
    return 0
  elseif x < 0 then
    return -1
  end
end

function geom.angle_with_hint(x1, y1, x2, y2, hint)
  local result = geom.angle(x1,y1, x2,y2)
  if hint then
    -- Smooth the discontinuity where angle goes from positive to negative.
    -- The hint is a memory of which way we drew it last time.
    while result > hint+math.pi/10 do
      result = result-math.pi*2
    end
    while result < hint-math.pi/10 do
      result = result+math.pi*2
    end
  end
  return result
end

-- result is from -π/2 to 3π/2, approximately adding math.atan2 from Lua 5.3
-- (LÖVE is Lua 5.1)
function geom.angle(x1,y1, x2,y2)
  local result = math.atan((y2-y1)/(x2-x1))
  if x2 < x1 then
    result = result+math.pi
  end
  return result
end

-- is the line between x,y and cx,cy at an angle between s and e?
function geom.angle_between(ox,oy, x,y, s,e)
  local angle = geom.angle(ox,oy, x,y)
  if s > e then
    s,e = e,s
  end
  -- I'm not sure this is right or ideal..
  angle = angle-math.pi*2
  if s <= angle and angle <= e then
    return true
  end
  angle = angle+math.pi*2
  if s <= angle and angle <= e then
    return true
  end
  angle = angle+math.pi*2
  return s <= angle and angle <= e
end

function geom.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end
