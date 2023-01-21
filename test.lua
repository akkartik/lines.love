-- Some primitives for tests.

function check(x, msg)
  if not x then
    error(msg)
  end
end

function check_nil(x, msg)
  if x ~= nil then
    error(msg..'; should be nil but got "'..x..'"')
  end
end

function check_eq(x, expected, msg)
  if not eq(x, expected) then
    error(msg..'; should be "'..expected..'" but got "'..x..'"')
  end
end

function eq(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) == 'table' then
    if #a ~= #b then return false end
    for k, v in pairs(a) do
      if not eq(b[k], v) then
        return false
      end
    end
    for k, v in pairs(b) do
      if not eq(a[k], v) then
        return false
      end
    end
    return true
  end
  return a == b
end
