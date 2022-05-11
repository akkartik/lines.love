-- beginnings of a repl

function eval(buf)
  local f = load('return '..buf, 'REPL')
  if f then
    return run(f)
  end
  local f, err = load(buf, 'REPL')
  if f then
    return run(f)
  else
    return {err}
  end
end

-- you could perform parse and run separately
-- usually because there's a side-effect like drawing that you want to control the timing of
function parse_into_exec_payload(buf)
  local f = load('return '..buf, 'REPL')
  if f then
    exec_payload = f
    return
  end
  local f, err = load(buf, 'REPL')
  if f then
    exec_payload = f
    return
  else
    return {err}
  end
end

-- based on https://github.com/hoelzro/lua-repl
function run(f)
  local success, results = gather_results(xpcall(f, function(...) return debug.traceback() end))
  return results
end

function gather_results(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end
