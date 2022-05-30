-- Keyboard driver

Modifiers = {'lctrl', 'rctrl', 'lalt', 'ralt', 'lshift', 'rshift', 'lgui', 'rgui'}

function App.keypressed(key, scancode, isrepeat)
  if array.find(Modifiers, key) then
    -- do nothing when the modifier is pressed
  end
  -- include the modifier(s) when the non-modifer is pressed
  App.keychord_pressed(App.combine_modifiers(key))
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

function App.modifier_down()
  return App.ctrl_down() or App.alt_down() or App.shift_down() or App.cmd_down()
end

function App.ctrl_down()
  return love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
end

function App.alt_down()
  return love.keyboard.isDown('lalt') or love.keyboard.isDown('ralt')
end

function App.shift_down()
  return love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')
end

function App.cmd_down()
  return love.keyboard.isDown('lgui') or love.keyboard.isDown('rgui')
end

array = {}

function array.find(arr, elem)
  for i,x in ipairs(arr) do
    if x == elem then
      return i
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
