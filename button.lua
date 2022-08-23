-- Simple immediate-mode buttons with (currently) just an onpress1 handler for
-- the left button.
-- If the handler returns true, it'll prevent any further processing of the
-- event.

-- draw button and queue up event handlers
function button(State, name, params)
  if State.button_handlers == nil then
    State.button_handlers = {}
  end
  love.graphics.setColor(params.color[1], params.color[2], params.color[3])
  love.graphics.rectangle('fill', params.x,params.y, params.w,params.h, 5,5)
  if params.icon then params.icon(params.x, params.y) end
  table.insert(State.button_handlers, params)
end

-- process button event handlers
function propagate_to_button_handlers(State, x, y, mouse_button)
  if State.button_handlers == nil then
    return
  end
  for _,ev in ipairs(State.button_handlers) do
    if x>ev.x and x<ev.x+ev.w and y>ev.y and y<ev.y+ev.h then
      if ev.onpress1 and mouse_button == 1 then
        return ev.onpress1()
      end
    end
  end
end
