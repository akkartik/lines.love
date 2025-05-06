-- Keyboard driver

Modifiers = {'lctrl', 'rctrl', 'lalt', 'ralt', 'lshift', 'rshift', 'lgui', 'rgui'}

function App.keypressed(key, scancode, is_repeat)
  if array.find(Modifiers, key) then
    -- do nothing when the modifier is pressed
    return
  end
  -- include the modifier(s) when the non-modifer is pressed
  App.keychord_press(App.combine_modifiers(key), key, scancode, is_repeat)
end

function App.combine_modifiers(key)
  if love.keyboard.isModifierActive then  -- waiting for LÖVE v12
    if key:match('^kp') then
      key = App.translate_numlock(key)
    end
  end
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
  return App.key_down('lctrl') or App.key_down('rctrl')
end

function App.alt_down()
  return App.key_down('lalt') or App.key_down('ralt')
end

function App.shift_down()
  return App.key_down('lshift') or App.key_down('rshift')
end

function App.cmd_down()
  return App.key_down('lgui') or App.key_down('rgui')
end

function App.is_cursor_movement(key)
  return array.find({'left', 'right', 'up', 'down', 'home', 'end', 'pageup', 'pagedown'}, key)
end

-- mappings only to non-printable keys; leave out mappings that textinput will handle
Numlock_off = {
  kp0='insert',
  kp1='end',
  kp2='down',
  kp3='pagedown',
  kp4='left',
  -- numpad 5 translates to nothing
  kp6='right',
  kp7='home',
  kp8='up',
  kp9='pageup',
  ['kp.']='delete',
  -- LÖVE handles keypad operators in textinput
  -- what's with the `kp=` and `kp,` keys? None of my keyboards have one.
  -- Hopefully LÖVE handles them as well in textinput.
  kpenter='enter',
  kpdel='delete',
}
Numlock_on = {
  kpenter='enter',
  kpdel='delete',
}
function App.translate_numlock(key)
  if love.keyboard.isModifierActive('numlock') then
    return Numlock_on[key] or key
  else
    return Numlock_off[key] or key
  end
  return key
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
