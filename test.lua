-- Some primitives for tests.
--
-- Success indicators go to the terminal; failures go to the window.
-- I don't know what I am doing.

function check(x, msg)
  if x then
    io.write('.')
  else
    error(msg)
  end
end

function check_eq(x, expected, msg)
  if eq(x, expected) then
    io.write('.')
  else
    error(msg..'; got "'..x..'"')
  end
end

function eq(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) == 'table' then
    if #a ~= #b then return false end
    for k, v in pairs(a) do
      if b[k] ~= v then
        return false
      end
    end
    for k, v in pairs(b) do
      if a[k] ~= v then
        return false
      end
    end
    return true
  end
  return a == b
end
