-- Simple immediate-mode buttons with (currently) just an onpress1 handler for
-- the left button.
--
-- Buttons can nest in principle, though I haven't actually used that yet.
--
-- Don't rely on the order in which handlers are run. Within any widget, all
-- applicable button handlers will run. If _any_ of them returns true, the
-- event will continue to propagate elsewhere in the widget.

-- draw button and queue up event handlers
function button(State, name, params)
  if State.button_handlers == nil then
    State.button_handlers = {}
  end
  love.graphics.setColor(params.color[1], params.color[2], params.color[3])
  love.graphics.rectangle('fill', params.x,params.y, params.w,params.h, 5,5)
  if params.icon then params.icon(params) end
  table.insert(State.button_handlers, params)
end

-- process button event handlers
function mouse_press_consumed_by_any_button_handler(State, x, y, mouse_button)
  if State.button_handlers == nil then
    return
  end
  local result = false
  for _,ev in ipairs(State.button_handlers) do
    if x>ev.x and x<ev.x+ev.w and y>ev.y and y<ev.y+ev.h then
      if ev.onpress1 and mouse_button == 1 then
        if not ev.onpress1() then
          result = true
        end
      end
    end
  end
  return result
end
