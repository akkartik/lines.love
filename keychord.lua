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
  local down = love.keyboard.isDown
  if down('lctrl') or down('rctrl') then
    result = result..'C-'
  end
  if down('lalt') or down('ralt') then
    result = result..'M-'
  end
  if down('lshift') or down('rshift') then
    result = result..'S-'  -- don't try to use this with letters/digits
  end
  if down('lgui') or down('rgui') then
    result = result..'s-'
  end
  result = result..key
  return result
end

function App.modifier_down()
  return array.any(Modifiers, love.keyboard.isDown)
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
