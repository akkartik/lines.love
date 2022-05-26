-- Keyboard driver

function App.keypressed(key, scancode, isrepeat)
  if key == 'lctrl' or key == 'rctrl' or key == 'lalt' or key == 'ralt' or key == 'lshift' or key == 'rshift' or key == 'lgui' or key == 'rgui' then
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
  if down('lgui') or down('rgui') then
    result = result..'S-'
  end
  result = result..key
  return result
end
