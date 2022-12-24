-- Keyboard driver

Modifiers = {'lctrl', 'rctrl', 'lalt', 'ralt', 'lshift', 'rshift', 'lgui', 'rgui'}

function App.keypressed(key, scancode, isrepeat)
  if array.find(Modifiers, key) then
    -- do nothing when the modifier is pressed
    return
  end
  -- include the modifier(s) when the non-modifer is pressed
  App.keychord_press(App.combine_modifiers(key), key)
end

function App.combine_modifiers(key)
  local result = ''
  if App.ctrl_down() then
    result = result..'C-'
  end
  if App.alt_down() then
    result = result..'M-'
  end
  if App.shift_down() then
    result = result..'S-'  -- don't try to use this with letters/digits
  end
  if App.cmd_down() then
    result = result..'s-'
  end
  result = result..key
  return result
end

function App.any_modifier_down()
  return App.ctrl_down() or App.alt_down() or App.shift_down() or App.cmd_down()
end

function App.ctrl_down()
  return App.modifier_down('lctrl') or App.modifier_down('rctrl')
end

function App.alt_down()
  return App.modifier_down('lalt') or App.modifier_down('ralt')
end

function App.shift_down()
  return App.modifier_down('lshift') or App.modifier_down('rshift')
end

function App.cmd_down()
  return App.modifier_down('lgui') or App.modifier_down('rgui')
end

function App.is_cursor_movement(key)
  return array.find({'left', 'right', 'up', 'down', 'home', 'end', 'pageup', 'pagedown'}, key)
end

array = {}

function array.find(arr, elem)
  if type(elem) == 'function' then
    for i,x in ipairs(arr) do
      if elem(x) then
        return i
      end
    end
  else
    for i,x in ipairs(arr) do
      if x == elem then
        return i
      end
    end
  end
  return nil
end

function array.any(arr, f)
  for i,x in ipairs(arr) do
    local result = f(x)
    if result then
      return result
    end
  end
  return false
end
