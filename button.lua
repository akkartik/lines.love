-- simple immediate-mode buttons

Button_handlers = {}

-- draw button and queue up event handlers
function button(name, params)
  love.graphics.setColor(params.color[1], params.color[2], params.color[3])
  love.graphics.rectangle('fill', params.x,params.y, params.w,params.h, 5,5)
  if params.icon then params.icon(params.x, params.y) end
  table.insert(Button_handlers, params)
end

-- process button event handlers
function propagate_to_button_handlers(x, y, mouse_button)
  for _,ev in ipairs(Button_handlers) do
    if x>ev.x and x<ev.x+ev.w and y>ev.y and y<ev.y+ev.h then
      if ev.onpress1 and mouse_button == 1 then
        return ev.onpress1()
      end
    end
  end
end
