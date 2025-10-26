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
  if params.bg then
    love.graphics.setColor(params.bg.r, params.bg.g, params.bg.b, params.bg.a)
    love.graphics.rectangle('fill', params.x,params.y, params.w,params.h, 5,5)
  end
  if params.icon then params.icon(params) end
  table.insert(State.button_handlers, params)
end

function mouse_hover_on_any_button(State, x, y)
  for _,ev in ipairs(State.button_handlers) do
    if x>ev.x and x<ev.x+ev.w and y>ev.y and y<ev.y+ev.h then
      if ev.onpress1 then
        return true
      end
    end
  end
end

-- process button event handlers
function mouse_press_consumed_by_any_button(State, x, y, mouse_button)
  local button_pressed = false
  local consume_press = true
  for _,ev in ipairs(State.button_handlers) do
    if x>ev.x and x<ev.x+ev.w and y>ev.y and y<ev.y+ev.h then
      if ev.onpress1 and mouse_button == 1 then
        button_pressed = true
        if ev.onpress1() then
          consume_press = false
        end
      end
    end
  end
  return button_pressed and consume_press
end
