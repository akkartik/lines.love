-- major tests for drawings
-- We minimize assumptions about specific pixels, and try to test at the level
-- of specific shapes. In particular, no tests of freehand drawings.

function test_creating_drawing_saves()
  App.screen.init{width=120, height=60}
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  -- click on button to create drawing
  edit.run_after_mouse_click(Editor_state, 8,Editor_state.top+8, 1)
  -- file not immediately saved
  edit.update(Editor_state, 0.01)
  check_nil(App.filesystem['foo'], 'early')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- filesystem contains drawing and an empty line of text
  check_eq(App.filesystem['foo'], '```lines\n```\n\n', 'check')
end

function test_draw_line()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- draw a line
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, '#shapes')
  check_eq(#drawing.points, 2, '#points')
  check_eq(drawing.shapes[1].mode, 'line', 'shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'p1:x')
  check_eq(p1.y, 6, 'p1:y')
  check_eq(p2.x, 35, 'p2:x')
  check_eq(p2.y, 36, 'p2:y')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- The format on disk isn't perfectly stable. Table fields can be reordered.
  -- So just reload from disk to verify.
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'save/#shapes')
  check_eq(#drawing.points, 2, 'save/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'save/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'save/p1:x')
  check_eq(p1.y, 6, 'save/p1:y')
  check_eq(p2.x, 35, 'save/p2:x')
  check_eq(p2.y, 36, 'save/p2:y')
end

function test_draw_horizontal_line()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'manhattan'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- draw a line that is more horizontal than vertical
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, '#shapes')
  check_eq(#drawing.points, 2, '#points')
  check_eq(drawing.shapes[1].mode, 'manhattan', 'shape_mode')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'p1:x')
  check_eq(p1.y, 6, 'p1:y')
  check_eq(p2.x, 35, 'p2:x')
  check_eq(p2.y, p1.y, 'p2:y')
end

function test_draw_circle()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- draw a circle
  App.mouse_move(Editor_state.left+4, Editor_state.top+Drawing_padding_top+4)  -- hover on drawing
  edit.run_after_keychord(Editor_state, 'C-o')
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35+30, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, '#shapes')
  check_eq(#drawing.points, 1, '#points')
  check_eq(drawing.shapes[1].mode, 'circle', 'shape_mode')
  check_eq(drawing.shapes[1].radius, 30, 'radius')
  local center = drawing.points[drawing.shapes[1].center]
  check_eq(center.x, 35, 'center:x')
  check_eq(center.y, 36, 'center:y')
end

function test_cancel_stroke()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- start drawing a line
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  -- cancel
  edit.run_after_keychord(Editor_state, 'escape')
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 0, '#shapes')
end

function test_keys_do_not_affect_shape_when_mouse_up()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  -- hover over drawing and press 'o' without holding mouse
  App.mouse_move(Editor_state.left+4, Editor_state.top+Drawing_padding_top+4)  -- hover on drawing
  edit.run_after_keychord(Editor_state, 'o')
  -- no change to drawing mode
  check_eq(Editor_state.current_drawing_mode, 'line', 'drawing_mode')
  -- no change to text either because we didn't run the text_input event
end

function test_draw_circle_mid_stroke()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- draw a circle
  App.mouse_move(Editor_state.left+4, Editor_state.top+Drawing_padding_top+4)  -- hover on drawing
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_text_input(Editor_state, 'o')
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35+30, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, '#shapes')
  check_eq(#drawing.points, 1, '#points')
  check_eq(drawing.shapes[1].mode, 'circle', 'shape_mode')
  check_eq(drawing.shapes[1].radius, 30, 'radius')
  local center = drawing.points[drawing.shapes[1].center]
  check_eq(center.x, 35, 'center:x')
  check_eq(center.y, 36, 'center:y')
end

function test_draw_arc()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'circle'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- draw an arc
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  App.mouse_move(Editor_state.left+35+30, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_text_input(Editor_state, 'a')  -- arc mode
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35+50, Editor_state.top+Drawing_padding_top+36+50, 1)  -- 45°
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, '#shapes')
  check_eq(#drawing.points, 1, '#points')
  check_eq(drawing.shapes[1].mode, 'arc', 'shape_mode')
  local arc = drawing.shapes[1]
  check_eq(arc.radius, 30, 'radius')
  local center = drawing.points[arc.center]
  check_eq(center.x, 35, 'center:x')
  check_eq(center.y, 36, 'center:y')
  check_eq(arc.start_angle, 0, 'start:angle')
  check_eq(arc.end_angle, math.pi/4, 'end:angle')
end

function test_draw_polygon()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  check_eq(Editor_state.current_drawing_mode, 'line', 'baseline/drawing_mode')
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- first point
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_text_input(Editor_state, 'g')  -- polygon mode
  -- second point
  App.mouse_move(Editor_state.left+65, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_text_input(Editor_state, 'p')  -- add point
  -- final point
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, '#shapes')
  check_eq(#drawing.points, 3, 'vertices')
  local shape = drawing.shapes[1]
  check_eq(shape.mode, 'polygon', 'shape_mode')
  check_eq(#shape.vertices, 3, 'vertices')
  local p = drawing.points[shape.vertices[1]]
  check_eq(p.x, 5, 'p1:x')
  check_eq(p.y, 6, 'p1:y')
  local p = drawing.points[shape.vertices[2]]
  check_eq(p.x, 65, 'p2:x')
  check_eq(p.y, 36, 'p2:y')
  local p = drawing.points[shape.vertices[3]]
  check_eq(p.x, 35, 'p3:x')
  check_eq(p.y, 26, 'p3:y')
end

function test_draw_rectangle()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  check_eq(Editor_state.current_drawing_mode, 'line', 'baseline/drawing_mode')
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- first point
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_text_input(Editor_state, 'r')  -- rectangle mode
  -- second point/first edge
  App.mouse_move(Editor_state.left+42, Editor_state.top+Drawing_padding_top+45)
  edit.run_after_text_input(Editor_state, 'p')
  -- override second point/first edge
  App.mouse_move(Editor_state.left+75, Editor_state.top+Drawing_padding_top+76)
  edit.run_after_text_input(Editor_state, 'p')
  -- release (decides 'thickness' of rectangle perpendicular to first edge)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+15, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, '#shapes')
  check_eq(#drawing.points, 5, '#points')  -- currently includes every point added
  local shape = drawing.shapes[1]
  check_eq(shape.mode, 'rectangle', 'shape_mode')
  check_eq(#shape.vertices, 4, 'vertices')
  local p = drawing.points[shape.vertices[1]]
  check_eq(p.x, 35, 'p1:x')
  check_eq(p.y, 36, 'p1:y')
  local p = drawing.points[shape.vertices[2]]
  check_eq(p.x, 75, 'p2:x')
  check_eq(p.y, 76, 'p2:y')
  local p = drawing.points[shape.vertices[3]]
  check_eq(p.x, 70, 'p3:x')
  check_eq(p.y, 81, 'p3:y')
  local p = drawing.points[shape.vertices[4]]
  check_eq(p.x, 30, 'p4:x')
  check_eq(p.y, 41, 'p4:y')
end

function test_draw_rectangle_intermediate()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  check_eq(Editor_state.current_drawing_mode, 'line', 'baseline/drawing_mode')
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- first point
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_text_input(Editor_state, 'r')  -- rectangle mode
  -- second point/first edge
  App.mouse_move(Editor_state.left+42, Editor_state.top+Drawing_padding_top+45)
  edit.run_after_text_input(Editor_state, 'p')
  -- override second point/first edge
  App.mouse_move(Editor_state.left+75, Editor_state.top+Drawing_padding_top+76)
  edit.run_after_text_input(Editor_state, 'p')
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.points, 3, '#points')  -- currently includes every point added
  local pending = drawing.pending
  check_eq(pending.mode, 'rectangle', 'shape_mode')
  check_eq(#pending.vertices, 2, 'vertices')
  local p = drawing.points[pending.vertices[1]]
  check_eq(p.x, 35, 'p1:x')
  check_eq(p.y, 36, 'p1:y')
  local p = drawing.points[pending.vertices[2]]
  check_eq(p.x, 75, 'p2:x')
  check_eq(p.y, 76, 'p2:y')
  -- outline of rectangle is drawn based on where the mouse is, but we can't check that so far
end

function test_draw_square()
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  check_eq(Editor_state.current_drawing_mode, 'line', 'baseline/drawing_mode')
  check_eq(#Editor_state.lines, 2, 'baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'baseline/#shapes')
  -- first point
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_text_input(Editor_state, 's')  -- square mode
  -- second point/first edge
  App.mouse_move(Editor_state.left+42, Editor_state.top+Drawing_padding_top+45)
  edit.run_after_text_input(Editor_state, 'p')
  -- override second point/first edge
  App.mouse_move(Editor_state.left+65, Editor_state.top+Drawing_padding_top+66)
  edit.run_after_text_input(Editor_state, 'p')
  -- release (decides which side of first edge to draw square on)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+15, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, '#shapes')
  check_eq(#drawing.points, 5, '#points')  -- currently includes every point added
  check_eq(drawing.shapes[1].mode, 'square', 'shape_mode')
  check_eq(#drawing.shapes[1].vertices, 4, 'vertices')
  local p = drawing.points[drawing.shapes[1].vertices[1]]
  check_eq(p.x, 35, 'p1:x')
  check_eq(p.y, 36, 'p1:y')
  local p = drawing.points[drawing.shapes[1].vertices[2]]
  check_eq(p.x, 65, 'p2:x')
  check_eq(p.y, 66, 'p2:y')
  local p = drawing.points[drawing.shapes[1].vertices[3]]
  check_eq(p.x, 35, 'p3:x')
  check_eq(p.y, 96, 'p3:y')
  local p = drawing.points[drawing.shapes[1].vertices[4]]
  check_eq(p.x, 5, 'p4:x')
  check_eq(p.y, 66, 'p4:y')
end

function test_name_point()
  -- create a drawing with a line
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  -- draw a line
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'baseline/#shapes')
  check_eq(#drawing.points, 2, 'baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'baseline/p1:x')
  check_eq(p1.y, 6, 'baseline/p1:y')
  check_eq(p2.x, 35, 'baseline/p2:x')
  check_eq(p2.y, 36, 'baseline/p2:y')
  check_nil(p2.name, 'baseline/p2:name')
  -- enter 'name' mode without moving the mouse
  edit.run_after_keychord(Editor_state, 'C-n')
  check_eq(Editor_state.current_drawing_mode, 'name', 'mode:1')
  edit.run_after_text_input(Editor_state, 'A')
  check_eq(p2.name, 'A', 'check1')
  -- still in 'name' mode
  check_eq(Editor_state.current_drawing_mode, 'name', 'mode:2')
  -- exit 'name' mode
  edit.run_after_keychord(Editor_state, 'return')
  check_eq(Editor_state.current_drawing_mode, 'line', 'mode:3')
  check_eq(p2.name, 'A', 'check2')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- change is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.name, 'A', 'save')
end

function test_move_point()
  -- create a drawing with a line
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'baseline/#shapes')
  check_eq(#drawing.points, 2, 'baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'baseline/p1:x')
  check_eq(p1.y, 6, 'baseline/p1:y')
  check_eq(p2.x, 35, 'baseline/p2:x')
  check_eq(p2.y, 36, 'baseline/p2:y')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- line is saved to disk
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local drawing = Editor_state.lines[1]
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.x, 35, 'save/x')
  check_eq(p2.y, 36, 'save/y')
  edit.draw(Editor_state)
  -- enter 'move' mode without moving the mouse
  edit.run_after_keychord(Editor_state, 'C-u')
  check_eq(Editor_state.current_drawing_mode, 'move', 'mode:1')
  -- point is lifted
  check_eq(drawing.pending.mode, 'move', 'mode:2')
  check_eq(drawing.pending.target_point, p2, 'target')
  -- move point
  App.mouse_move(Editor_state.left+26, Editor_state.top+Drawing_padding_top+44)
  edit.update(Editor_state, 0.05)
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p2.x, 26, 'x')
  check_eq(p2.y, 44, 'y')
  -- exit 'move' mode
  edit.run_after_mouse_click(Editor_state, Editor_state.left+26, Editor_state.top+Drawing_padding_top+44, 1)
  check_eq(Editor_state.current_drawing_mode, 'line', 'mode:3')
  check_eq(drawing.pending, {}, 'pending')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- change is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.x, 26, 'save/x')
  check_eq(p2.y, 44, 'save/y')
end

function test_move_point_on_manhattan_line()
  -- create a drawing with a manhattan line
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'manhattan'
  edit.draw(Editor_state)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+46, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'baseline/#shapes')
  check_eq(#drawing.points, 2, 'baseline/#points')
  check_eq(drawing.shapes[1].mode, 'manhattan', 'baseline/shape:1')
  edit.draw(Editor_state)
  -- enter 'move' mode
  edit.run_after_keychord(Editor_state, 'C-u')
  check_eq(Editor_state.current_drawing_mode, 'move', 'mode:1')
  -- move point
  App.mouse_move(Editor_state.left+26, Editor_state.top+Drawing_padding_top+44)
  edit.update(Editor_state, 0.05)
  -- line is no longer manhattan
  check_eq(drawing.shapes[1].mode, 'line', 'baseline/shape:1')
end

function test_delete_lines_at_point()
  -- create a drawing with two lines connected at a point
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+55, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 2, 'baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'line', 'baseline/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'baseline/shape:2')
  -- hover on the common point and delete
  App.mouse_move(Editor_state.left+35, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_keychord(Editor_state, 'C-d')
  check_eq(drawing.shapes[1].mode, 'deleted', 'shape:1')
  check_eq(drawing.shapes[2].mode, 'deleted', 'shape:2')
  -- wait for some time
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- deleted points disappear after file is reloaded
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  check_eq(#Editor_state.lines[1].shapes, 0, 'save')
end

function test_delete_line_under_mouse_pointer()
  -- create a drawing with two lines connected at a point
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+55, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 2, 'baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'line', 'baseline/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'baseline/shape:2')
  -- hover on one of the lines and delete
  App.mouse_move(Editor_state.left+25, Editor_state.top+Drawing_padding_top+26)
  edit.run_after_keychord(Editor_state, 'C-d')
  -- only that line is deleted
  check_eq(drawing.shapes[1].mode, 'deleted', 'shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'shape:2')
end

function test_delete_point_from_polygon()
  -- create a drawing with two lines connected at a point
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  -- first point
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_text_input(Editor_state, 'g')  -- polygon mode
  -- second point
  App.mouse_move(Editor_state.left+65, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_text_input(Editor_state, 'p')  -- add point
  -- third point
  App.mouse_move(Editor_state.left+35, Editor_state.top+Drawing_padding_top+26)
  edit.run_after_text_input(Editor_state, 'p')  -- add point
  -- fourth point
  edit.run_after_mouse_release(Editor_state, Editor_state.left+14, Editor_state.top+Drawing_padding_top+16, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'polygon', 'baseline/mode')
  check_eq(#drawing.shapes[1].vertices, 4, 'baseline/vertices')
  -- hover on a point and delete
  App.mouse_move(Editor_state.left+35, Editor_state.top+Drawing_padding_top+26)
  edit.run_after_keychord(Editor_state, 'C-d')
  -- just the one point is deleted
  check_eq(drawing.shapes[1].mode, 'polygon', 'shape')
  check_eq(#drawing.shapes[1].vertices, 3, 'vertices')
end

function test_delete_point_from_polygon()
  -- create a drawing with two lines connected at a point
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  -- first point
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_text_input(Editor_state, 'g')  -- polygon mode
  -- second point
  App.mouse_move(Editor_state.left+65, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_text_input(Editor_state, 'p')  -- add point
  -- third point
  edit.run_after_mouse_release(Editor_state, Editor_state.left+14, Editor_state.top+Drawing_padding_top+16, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'polygon', 'baseline/mode')
  check_eq(#drawing.shapes[1].vertices, 3, 'baseline/vertices')
  -- hover on a point and delete
  App.mouse_move(Editor_state.left+65, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_keychord(Editor_state, 'C-d')
  -- there's < 3 points left, so the whole polygon is deleted
  check_eq(drawing.shapes[1].mode, 'deleted', 'check')
end

function test_undo_name_point()
  -- create a drawing with a line
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  -- draw a line
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'baseline/#shapes')
  check_eq(#drawing.points, 2, 'baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'baseline/p1:x')
  check_eq(p1.y, 6, 'baseline/p1:y')
  check_eq(p2.x, 35, 'baseline/p2:x')
  check_eq(p2.y, 36, 'baseline/p2:y')
  check_nil(p2.name, 'baseline/p2:name')
  check_eq(#Editor_state.history, 1, 'baseline/history:1')
--?   print('a', Editor_state.lines.current_drawing)
  -- enter 'name' mode without moving the mouse
  edit.run_after_keychord(Editor_state, 'C-n')
  edit.run_after_text_input(Editor_state, 'A')
  edit.run_after_keychord(Editor_state, 'return')
  check_eq(p2.name, 'A', 'baseline')
  check_eq(#Editor_state.history, 3, 'baseline/history:2')
  check_eq(Editor_state.next_history, 4, 'baseline/next_history')
--?   print('b', Editor_state.lines.current_drawing)
  -- undo
  edit.run_after_keychord(Editor_state, 'C-z')
  local drawing = Editor_state.lines[1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(Editor_state.next_history, 3, 'next_history')
  check_eq(p2.name, '', 'undo')  -- not quite what it was before, but close enough
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- undo is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.name, '', 'save')
end

function test_undo_move_point()
  -- create a drawing with a line
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'baseline/#shapes')
  check_eq(#drawing.points, 2, 'baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'baseline/p1:x')
  check_eq(p1.y, 6, 'baseline/p1:y')
  check_eq(p2.x, 35, 'baseline/p2:x')
  check_eq(p2.y, 36, 'baseline/p2:y')
  check_nil(p2.name, 'baseline/p2:name')
  -- move p2
  edit.run_after_keychord(Editor_state, 'C-u')
  App.mouse_move(Editor_state.left+26, Editor_state.top+Drawing_padding_top+44)
  edit.update(Editor_state, 0.05)
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p2.x, 26, 'x')
  check_eq(p2.y, 44, 'y')
  -- exit 'move' mode
  edit.run_after_mouse_click(Editor_state, Editor_state.left+26, Editor_state.top+Drawing_padding_top+44, 1)
  check_eq(Editor_state.next_history, 4, 'next_history')
  -- undo
  edit.run_after_keychord(Editor_state, 'C-z')
  edit.run_after_keychord(Editor_state, 'C-z')  -- bug: need to undo twice
  local drawing = Editor_state.lines[1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(Editor_state.next_history, 2, 'next_history')
  check_eq(p2.x, 35, 'x')
  check_eq(p2.y, 36, 'y')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- undo is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.x, 35, 'save/x')
  check_eq(p2.y, 36, 'save/y')
end

function test_undo_delete_point()
  -- create a drawing with two lines connected at a point
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+55, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 2, 'baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'line', 'baseline/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'baseline/shape:2')
  -- hover on the common point and delete
  App.mouse_move(Editor_state.left+35, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_keychord(Editor_state, 'C-d')
  check_eq(drawing.shapes[1].mode, 'deleted', 'shape:1')
  check_eq(drawing.shapes[2].mode, 'deleted', 'shape:2')
  -- undo
  edit.run_after_keychord(Editor_state, 'C-z')
  local drawing = Editor_state.lines[1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(Editor_state.next_history, 3, 'next_history')
  check_eq(drawing.shapes[1].mode, 'line', 'shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'shape:2')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- undo is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  check_eq(#Editor_state.lines[1].shapes, 2, 'save')
end
