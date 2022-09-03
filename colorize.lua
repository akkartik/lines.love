-- State transitions while colorizing a single line.
-- Just for comments and strings.
-- Limitation: each fragment gets a uniform color so we can only change color
-- at word boundaries.
Next_state = {
  normal={
    {prefix='--', target='comment'},
    {prefix='"', target='dstring'},
    {prefix="'", target='sstring'},
  },
  dstring={
    {suffix='"', target='normal'},
  },
  sstring={
    {suffix="'", target='normal'},
  },
  -- comments are a sink
}

Comments_color = {r=0, g=0, b=1}
String_color = {r=0, g=0.5, b=0.5}
Divider_color = {r=0.7, g=0.7, b=0.7}

Colors = {
  normal=Text_color,
  comment=Comments_color,
  sstring=String_color,
  dstring=String_color
}

Current_state = 'normal'

function initialize_color()
--?   print('new line')
  Current_state = 'normal'
end

function select_color(frag)
--?   print('before', '^'..frag..'$', Current_state)
  switch_color_based_on_prefix(frag)
--?   print('using color', Current_state, Colors[Current_state])
  App.color(Colors[Current_state])
  switch_color_based_on_suffix(frag)
--?   print('state after suffix', Current_state)
end

function switch_color_based_on_prefix(frag)
  if Next_state[Current_state] == nil then
    return
  end
  frag = rtrim(frag)
  for _,edge in pairs(Next_state[Current_state]) do
    if edge.prefix and find(frag, edge.prefix, nil, --[[plain]] true) == 1 then
      Current_state = edge.target
      break
    end
  end
end

function switch_color_based_on_suffix(frag)
  if Next_state[Current_state] == nil then
    return
  end
  frag = rtrim(frag)
  for _,edge in pairs(Next_state[Current_state]) do
    if edge.suffix and rfind(frag, edge.suffix, nil, --[[plain]] true) == #frag then
      Current_state = edge.target
      break
    end
  end
end

function trim(s)
  return s:gsub('^%s+', ''):gsub('%s+$', '')
end

function ltrim(s)
  return s:gsub('^%s+', '')
end

function rtrim(s)
  return s:gsub('%s+$', '')
end
