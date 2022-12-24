-- major tests for drawings
-- We minimize assumptions about specific pixels, and try to test at the level
-- of specific shapes. In particular, no tests of freehand drawings.

function test_creating_drawing_saves()
  io.write('\ntest_creating_drawing_saves')
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
  check_nil(App.filesystem['foo'], 'F - test_creating_drawing_saves/early')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- filesystem contains drawing and an empty line of text
  check_eq(App.filesystem['foo'], '```lines\n```\n\n', 'F - test_creating_drawing_saves')
end

function test_draw_line()
  io.write('\ntest_draw_line')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'F - test_draw_line/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_line/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_line/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_line/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_line/baseline/#shapes')
  -- draw a line
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_line/#shapes')
  check_eq(#drawing.points, 2, 'F - test_draw_line/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_draw_line/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_draw_line/p1:x')
  check_eq(p1.y, 6, 'F - test_draw_line/p1:y')
  check_eq(p2.x, 35, 'F - test_draw_line/p2:x')
  check_eq(p2.y, 36, 'F - test_draw_line/p2:y')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- The format on disk isn't perfectly stable. Table fields can be reordered.
  -- So just reload from disk to verify.
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_line/save/#shapes')
  check_eq(#drawing.points, 2, 'F - test_draw_line/save/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_draw_line/save/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_draw_line/save/p1:x')
  check_eq(p1.y, 6, 'F - test_draw_line/save/p1:y')
  check_eq(p2.x, 35, 'F - test_draw_line/save/p2:x')
  check_eq(p2.y, 36, 'F - test_draw_line/save/p2:y')
end

function test_draw_horizontal_line()
  io.write('\ntest_draw_horizontal_line')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'manhattan'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'F - test_draw_horizontal_line/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_horizontal_line/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_horizontal_line/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_horizontal_line/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_horizontal_line/baseline/#shapes')
  -- draw a line that is more horizontal than vertical
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_horizontal_line/#shapes')
  check_eq(#drawing.points, 2, 'F - test_draw_horizontal_line/#points')
  check_eq(drawing.shapes[1].mode, 'manhattan', 'F - test_draw_horizontal_line/shape_mode')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_draw_horizontal_line/p1:x')
  check_eq(p1.y, 6, 'F - test_draw_horizontal_line/p1:y')
  check_eq(p2.x, 35, 'F - test_draw_horizontal_line/p2:x')
  check_eq(p2.y, p1.y, 'F - test_draw_horizontal_line/p2:y')
end

function test_draw_circle()
  io.write('\ntest_draw_circle')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'F - test_draw_circle/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_circle/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_circle/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_circle/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_circle/baseline/#shapes')
  -- draw a circle
  App.mouse_move(Editor_state.left+4, Editor_state.top+Drawing_padding_top+4)  -- hover on drawing
  edit.run_after_keychord(Editor_state, 'C-o')
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35+30, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_circle/#shapes')
  check_eq(#drawing.points, 1, 'F - test_draw_circle/#points')
  check_eq(drawing.shapes[1].mode, 'circle', 'F - test_draw_horizontal_line/shape_mode')
  check_eq(drawing.shapes[1].radius, 30, 'F - test_draw_circle/radius')
  local center = drawing.points[drawing.shapes[1].center]
  check_eq(center.x, 35, 'F - test_draw_circle/center:x')
  check_eq(center.y, 36, 'F - test_draw_circle/center:y')
end

function test_cancel_stroke()
  io.write('\ntest_cancel_stroke')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'F - test_cancel_stroke/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_cancel_stroke/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_cancel_stroke/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_cancel_stroke/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_cancel_stroke/baseline/#shapes')
  -- start drawing a line
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  -- cancel
  edit.run_after_keychord(Editor_state, 'escape')
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 0, 'F - test_cancel_stroke/#shapes')
end

function test_keys_do_not_affect_shape_when_mouse_up()
  io.write('\ntest_keys_do_not_affect_shape_when_mouse_up')
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
  check_eq(Editor_state.current_drawing_mode, 'line', 'F - test_keys_do_not_affect_shape_when_mouse_up/drawing_mode')
  -- no change to text either because we didn't run the text_input event
end

function test_draw_circle_mid_stroke()
  io.write('\ntest_draw_circle_mid_stroke')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'line'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'F - test_draw_circle_mid_stroke/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_circle_mid_stroke/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_circle_mid_stroke/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_circle_mid_stroke/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_circle_mid_stroke/baseline/#shapes')
  -- draw a circle
  App.mouse_move(Editor_state.left+4, Editor_state.top+Drawing_padding_top+4)  -- hover on drawing
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  edit.run_after_text_input(Editor_state, 'o')
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35+30, Editor_state.top+Drawing_padding_top+36, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_circle_mid_stroke/#shapes')
  check_eq(#drawing.points, 1, 'F - test_draw_circle_mid_stroke/#points')
  check_eq(drawing.shapes[1].mode, 'circle', 'F - test_draw_horizontal_line/shape_mode')
  check_eq(drawing.shapes[1].radius, 30, 'F - test_draw_circle_mid_stroke/radius')
  local center = drawing.points[drawing.shapes[1].center]
  check_eq(center.x, 35, 'F - test_draw_circle_mid_stroke/center:x')
  check_eq(center.y, 36, 'F - test_draw_circle_mid_stroke/center:y')
end

function test_draw_arc()
  io.write('\ntest_draw_arc')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  Editor_state.current_drawing_mode = 'circle'
  edit.draw(Editor_state)
  check_eq(#Editor_state.lines, 2, 'F - test_draw_arc/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_arc/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_arc/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_arc/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_arc/baseline/#shapes')
  -- draw an arc
  edit.run_after_mouse_press(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+36, 1)
  App.mouse_move(Editor_state.left+35+30, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_text_input(Editor_state, 'a')  -- arc mode
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35+50, Editor_state.top+Drawing_padding_top+36+50, 1)  -- 45°
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_arc/#shapes')
  check_eq(#drawing.points, 1, 'F - test_draw_arc/#points')
  check_eq(drawing.shapes[1].mode, 'arc', 'F - test_draw_horizontal_line/shape_mode')
  local arc = drawing.shapes[1]
  check_eq(arc.radius, 30, 'F - test_draw_arc/radius')
  local center = drawing.points[arc.center]
  check_eq(center.x, 35, 'F - test_draw_arc/center:x')
  check_eq(center.y, 36, 'F - test_draw_arc/center:y')
  check_eq(arc.start_angle, 0, 'F - test_draw_arc/start:angle')
  check_eq(arc.end_angle, math.pi/4, 'F - test_draw_arc/end:angle')
end

function test_draw_polygon()
  io.write('\ntest_draw_polygon')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  check_eq(Editor_state.current_drawing_mode, 'line', 'F - test_draw_polygon/baseline/drawing_mode')
  check_eq(#Editor_state.lines, 2, 'F - test_draw_polygon/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_polygon/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_polygon/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_polygon/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_polygon/baseline/#shapes')
  -- first point
  edit.run_after_mouse_press(Editor_state, Editor_state.left+5, Editor_state.top+Drawing_padding_top+6, 1)
  edit.run_after_text_input(Editor_state, 'g')  -- polygon mode
  -- second point
  App.mouse_move(Editor_state.left+65, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_text_input(Editor_state, 'p')  -- add point
  -- final point
  edit.run_after_mouse_release(Editor_state, Editor_state.left+35, Editor_state.top+Drawing_padding_top+26, 1)
  local drawing = Editor_state.lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_polygon/#shapes')
  check_eq(#drawing.points, 3, 'F - test_draw_polygon/vertices')
  local shape = drawing.shapes[1]
  check_eq(shape.mode, 'polygon', 'F - test_draw_polygon/shape_mode')
  check_eq(#shape.vertices, 3, 'F - test_draw_polygon/vertices')
  local p = drawing.points[shape.vertices[1]]
  check_eq(p.x, 5, 'F - test_draw_polygon/p1:x')
  check_eq(p.y, 6, 'F - test_draw_polygon/p1:y')
  local p = drawing.points[shape.vertices[2]]
  check_eq(p.x, 65, 'F - test_draw_polygon/p2:x')
  check_eq(p.y, 36, 'F - test_draw_polygon/p2:y')
  local p = drawing.points[shape.vertices[3]]
  check_eq(p.x, 35, 'F - test_draw_polygon/p3:x')
  check_eq(p.y, 26, 'F - test_draw_polygon/p3:y')
end

function test_draw_rectangle()
  io.write('\ntest_draw_rectangle')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  check_eq(Editor_state.current_drawing_mode, 'line', 'F - test_draw_rectangle/baseline/drawing_mode')
  check_eq(#Editor_state.lines, 2, 'F - test_draw_rectangle/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_rectangle/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_rectangle/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_rectangle/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_rectangle/baseline/#shapes')
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
  check_eq(#drawing.shapes, 1, 'F - test_draw_rectangle/#shapes')
  check_eq(#drawing.points, 5, 'F - test_draw_rectangle/#points')  -- currently includes every point added
  local shape = drawing.shapes[1]
  check_eq(shape.mode, 'rectangle', 'F - test_draw_rectangle/shape_mode')
  check_eq(#shape.vertices, 4, 'F - test_draw_rectangle/vertices')
  local p = drawing.points[shape.vertices[1]]
  check_eq(p.x, 35, 'F - test_draw_rectangle/p1:x')
  check_eq(p.y, 36, 'F - test_draw_rectangle/p1:y')
  local p = drawing.points[shape.vertices[2]]
  check_eq(p.x, 75, 'F - test_draw_rectangle/p2:x')
  check_eq(p.y, 76, 'F - test_draw_rectangle/p2:y')
  local p = drawing.points[shape.vertices[3]]
  check_eq(p.x, 70, 'F - test_draw_rectangle/p3:x')
  check_eq(p.y, 81, 'F - test_draw_rectangle/p3:y')
  local p = drawing.points[shape.vertices[4]]
  check_eq(p.x, 30, 'F - test_draw_rectangle/p4:x')
  check_eq(p.y, 41, 'F - test_draw_rectangle/p4:y')
end

function test_draw_rectangle_intermediate()
  io.write('\ntest_draw_rectangle_intermediate')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  check_eq(Editor_state.current_drawing_mode, 'line', 'F - test_draw_rectangle_intermediate/baseline/drawing_mode')
  check_eq(#Editor_state.lines, 2, 'F - test_draw_rectangle_intermediate/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_rectangle_intermediate/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_rectangle_intermediate/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_rectangle_intermediate/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_rectangle_intermediate/baseline/#shapes')
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
  check_eq(#drawing.points, 3, 'F - test_draw_rectangle_intermediate/#points')  -- currently includes every point added
  local pending = drawing.pending
  check_eq(pending.mode, 'rectangle', 'F - test_draw_rectangle_intermediate/shape_mode')
  check_eq(#pending.vertices, 2, 'F - test_draw_rectangle_intermediate/vertices')
  local p = drawing.points[pending.vertices[1]]
  check_eq(p.x, 35, 'F - test_draw_rectangle_intermediate/p1:x')
  check_eq(p.y, 36, 'F - test_draw_rectangle_intermediate/p1:y')
  local p = drawing.points[pending.vertices[2]]
  check_eq(p.x, 75, 'F - test_draw_rectangle_intermediate/p2:x')
  check_eq(p.y, 76, 'F - test_draw_rectangle_intermediate/p2:y')
  -- outline of rectangle is drawn based on where the mouse is, but we can't check that so far
end

function test_draw_square()
  io.write('\ntest_draw_square')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Test_margin_left+256, height=300}  -- drawing coordinates 1:1 with pixels
  Editor_state = edit.initialize_test_state()
  Editor_state.lines = load_array{'```lines', '```', ''}
  Text.redraw_all(Editor_state)
  edit.draw(Editor_state)
  check_eq(Editor_state.current_drawing_mode, 'line', 'F - test_draw_square/baseline/drawing_mode')
  check_eq(#Editor_state.lines, 2, 'F - test_draw_square/baseline/#lines')
  check_eq(Editor_state.lines[1].mode, 'drawing', 'F - test_draw_square/baseline/mode')
  check_eq(Editor_state.line_cache[1].starty, Editor_state.top+Drawing_padding_top, 'F - test_draw_square/baseline/y')
  check_eq(Editor_state.lines[1].h, 128, 'F - test_draw_square/baseline/y')
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_draw_square/baseline/#shapes')
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
  check_eq(#drawing.shapes, 1, 'F - test_draw_square/#shapes')
  check_eq(#drawing.points, 5, 'F - test_draw_square/#points')  -- currently includes every point added
  check_eq(drawing.shapes[1].mode, 'square', 'F - test_draw_square/shape_mode')
  check_eq(#drawing.shapes[1].vertices, 4, 'F - test_draw_square/vertices')
  local p = drawing.points[drawing.shapes[1].vertices[1]]
  check_eq(p.x, 35, 'F - test_draw_square/p1:x')
  check_eq(p.y, 36, 'F - test_draw_square/p1:y')
  local p = drawing.points[drawing.shapes[1].vertices[2]]
  check_eq(p.x, 65, 'F - test_draw_square/p2:x')
  check_eq(p.y, 66, 'F - test_draw_square/p2:y')
  local p = drawing.points[drawing.shapes[1].vertices[3]]
  check_eq(p.x, 35, 'F - test_draw_square/p3:x')
  check_eq(p.y, 96, 'F - test_draw_square/p3:y')
  local p = drawing.points[drawing.shapes[1].vertices[4]]
  check_eq(p.x, 5, 'F - test_draw_square/p4:x')
  check_eq(p.y, 66, 'F - test_draw_square/p4:y')
end

function test_name_point()
  io.write('\ntest_name_point')
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
  check_eq(#drawing.shapes, 1, 'F - test_name_point/baseline/#shapes')
  check_eq(#drawing.points, 2, 'F - test_name_point/baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_name_point/baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_name_point/baseline/p1:x')
  check_eq(p1.y, 6, 'F - test_name_point/baseline/p1:y')
  check_eq(p2.x, 35, 'F - test_name_point/baseline/p2:x')
  check_eq(p2.y, 36, 'F - test_name_point/baseline/p2:y')
  check_nil(p2.name, 'F - test_name_point/baseline/p2:name')
  -- enter 'name' mode without moving the mouse
  edit.run_after_keychord(Editor_state, 'C-n')
  check_eq(Editor_state.current_drawing_mode, 'name', 'F - test_name_point/mode:1')
  edit.run_after_text_input(Editor_state, 'A')
  check_eq(p2.name, 'A', 'F - test_name_point')
  -- still in 'name' mode
  check_eq(Editor_state.current_drawing_mode, 'name', 'F - test_name_point/mode:2')
  -- exit 'name' mode
  edit.run_after_keychord(Editor_state, 'return')
  check_eq(Editor_state.current_drawing_mode, 'line', 'F - test_name_point/mode:3')
  check_eq(p2.name, 'A', 'F - test_name_point')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- change is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.name, 'A', 'F - test_name_point/save')
end

function test_move_point()
  io.write('\ntest_move_point')
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
  check_eq(#drawing.shapes, 1, 'F - test_move_point/baseline/#shapes')
  check_eq(#drawing.points, 2, 'F - test_move_point/baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_move_point/baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_move_point/baseline/p1:x')
  check_eq(p1.y, 6, 'F - test_move_point/baseline/p1:y')
  check_eq(p2.x, 35, 'F - test_move_point/baseline/p2:x')
  check_eq(p2.y, 36, 'F - test_move_point/baseline/p2:y')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- line is saved to disk
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local drawing = Editor_state.lines[1]
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.x, 35, 'F - test_move_point/save/x')
  check_eq(p2.y, 36, 'F - test_move_point/save/y')
  edit.draw(Editor_state)
  -- enter 'move' mode without moving the mouse
  edit.run_after_keychord(Editor_state, 'C-u')
  check_eq(Editor_state.current_drawing_mode, 'move', 'F - test_move_point/mode:1')
  -- point is lifted
  check_eq(drawing.pending.mode, 'move', 'F - test_move_point/mode:2')
  check_eq(drawing.pending.target_point, p2, 'F - test_move_point/target')
  -- move point
  App.mouse_move(Editor_state.left+26, Editor_state.top+Drawing_padding_top+44)
  edit.update(Editor_state, 0.05)
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p2.x, 26, 'F - test_move_point/x')
  check_eq(p2.y, 44, 'F - test_move_point/y')
  -- exit 'move' mode
  edit.run_after_mouse_click(Editor_state, Editor_state.left+26, Editor_state.top+Drawing_padding_top+44, 1)
  check_eq(Editor_state.current_drawing_mode, 'line', 'F - test_move_point/mode:3')
  check_eq(drawing.pending, {}, 'F - test_move_point/pending')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- change is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.x, 26, 'F - test_move_point/save/x')
  check_eq(p2.y, 44, 'F - test_move_point/save/y')
end

function test_move_point_on_manhattan_line()
  io.write('\ntest_move_point_on_manhattan_line')
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
  check_eq(#drawing.shapes, 1, 'F - test_move_point_on_manhattan_line/baseline/#shapes')
  check_eq(#drawing.points, 2, 'F - test_move_point_on_manhattan_line/baseline/#points')
  check_eq(drawing.shapes[1].mode, 'manhattan', 'F - test_move_point_on_manhattan_line/baseline/shape:1')
  edit.draw(Editor_state)
  -- enter 'move' mode
  edit.run_after_keychord(Editor_state, 'C-u')
  check_eq(Editor_state.current_drawing_mode, 'move', 'F - test_move_point_on_manhattan_line/mode:1')
  -- move point
  App.mouse_move(Editor_state.left+26, Editor_state.top+Drawing_padding_top+44)
  edit.update(Editor_state, 0.05)
  -- line is no longer manhattan
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_move_point_on_manhattan_line/baseline/shape:1')
end

function test_delete_lines_at_point()
  io.write('\ntest_delete_lines_at_point')
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
  check_eq(#drawing.shapes, 2, 'F - test_delete_lines_at_point/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_delete_lines_at_point/baseline/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'F - test_delete_lines_at_point/baseline/shape:2')
  -- hover on the common point and delete
  App.mouse_move(Editor_state.left+35, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_keychord(Editor_state, 'C-d')
  check_eq(drawing.shapes[1].mode, 'deleted', 'F - test_delete_lines_at_point/shape:1')
  check_eq(drawing.shapes[2].mode, 'deleted', 'F - test_delete_lines_at_point/shape:2')
  -- wait for some time
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- deleted points disappear after file is reloaded
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  check_eq(#Editor_state.lines[1].shapes, 0, 'F - test_delete_lines_at_point/save')
end

function test_delete_line_under_mouse_pointer()
  io.write('\ntest_delete_line_under_mouse_pointer')
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
  check_eq(#drawing.shapes, 2, 'F - test_delete_line_under_mouse_pointer/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_delete_line_under_mouse_pointer/baseline/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'F - test_delete_line_under_mouse_pointer/baseline/shape:2')
  -- hover on one of the lines and delete
  App.mouse_move(Editor_state.left+25, Editor_state.top+Drawing_padding_top+26)
  edit.run_after_keychord(Editor_state, 'C-d')
  -- only that line is deleted
  check_eq(drawing.shapes[1].mode, 'deleted', 'F - test_delete_line_under_mouse_pointer/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'F - test_delete_line_under_mouse_pointer/shape:2')
end

function test_delete_point_from_polygon()
  io.write('\ntest_delete_point_from_polygon')
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
  check_eq(#drawing.shapes, 1, 'F - test_delete_point_from_polygon/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'polygon', 'F - test_delete_point_from_polygon/baseline/mode')
  check_eq(#drawing.shapes[1].vertices, 4, 'F - test_delete_point_from_polygon/baseline/vertices')
  -- hover on a point and delete
  App.mouse_move(Editor_state.left+35, Editor_state.top+Drawing_padding_top+26)
  edit.run_after_keychord(Editor_state, 'C-d')
  -- just the one point is deleted
  check_eq(drawing.shapes[1].mode, 'polygon', 'F - test_delete_point_from_polygon/shape')
  check_eq(#drawing.shapes[1].vertices, 3, 'F - test_delete_point_from_polygon/vertices')
end

function test_delete_point_from_polygon()
  io.write('\ntest_delete_point_from_polygon')
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
  check_eq(#drawing.shapes, 1, 'F - test_delete_point_from_polygon/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'polygon', 'F - test_delete_point_from_polygon/baseline/mode')
  check_eq(#drawing.shapes[1].vertices, 3, 'F - test_delete_point_from_polygon/baseline/vertices')
  -- hover on a point and delete
  App.mouse_move(Editor_state.left+65, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_keychord(Editor_state, 'C-d')
  -- there's < 3 points left, so the whole polygon is deleted
  check_eq(drawing.shapes[1].mode, 'deleted', 'F - test_delete_point_from_polygon')
end

function test_undo_name_point()
  io.write('\ntest_undo_name_point')
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
  check_eq(#drawing.shapes, 1, 'F - test_undo_name_point/baseline/#shapes')
  check_eq(#drawing.points, 2, 'F - test_undo_name_point/baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_undo_name_point/baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_undo_name_point/baseline/p1:x')
  check_eq(p1.y, 6, 'F - test_undo_name_point/baseline/p1:y')
  check_eq(p2.x, 35, 'F - test_undo_name_point/baseline/p2:x')
  check_eq(p2.y, 36, 'F - test_undo_name_point/baseline/p2:y')
  check_nil(p2.name, 'F - test_undo_name_point/baseline/p2:name')
  check_eq(#Editor_state.history, 1, 'F - test_undo_name_point/baseline/history:1')
--?   print('a', Editor_state.lines.current_drawing)
  -- enter 'name' mode without moving the mouse
  edit.run_after_keychord(Editor_state, 'C-n')
  edit.run_after_text_input(Editor_state, 'A')
  edit.run_after_keychord(Editor_state, 'return')
  check_eq(p2.name, 'A', 'F - test_undo_name_point/baseline')
  check_eq(#Editor_state.history, 3, 'F - test_undo_name_point/baseline/history:2')
  check_eq(Editor_state.next_history, 4, 'F - test_undo_name_point/baseline/next_history')
--?   print('b', Editor_state.lines.current_drawing)
  -- undo
  edit.run_after_keychord(Editor_state, 'C-z')
  local drawing = Editor_state.lines[1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(Editor_state.next_history, 3, 'F - test_undo_name_point/next_history')
  check_eq(p2.name, '', 'F - test_undo_name_point')  -- not quite what it was before, but close enough
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- undo is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.name, '', 'F - test_undo_name_point/save')
end

function test_undo_move_point()
  io.write('\ntest_undo_move_point')
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
  check_eq(#drawing.shapes, 1, 'F - test_undo_move_point/baseline/#shapes')
  check_eq(#drawing.points, 2, 'F - test_undo_move_point/baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_undo_move_point/baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_undo_move_point/baseline/p1:x')
  check_eq(p1.y, 6, 'F - test_undo_move_point/baseline/p1:y')
  check_eq(p2.x, 35, 'F - test_undo_move_point/baseline/p2:x')
  check_eq(p2.y, 36, 'F - test_undo_move_point/baseline/p2:y')
  check_nil(p2.name, 'F - test_undo_move_point/baseline/p2:name')
  -- move p2
  edit.run_after_keychord(Editor_state, 'C-u')
  App.mouse_move(Editor_state.left+26, Editor_state.top+Drawing_padding_top+44)
  edit.update(Editor_state, 0.05)
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p2.x, 26, 'F - test_undo_move_point/x')
  check_eq(p2.y, 44, 'F - test_undo_move_point/y')
  -- exit 'move' mode
  edit.run_after_mouse_click(Editor_state, Editor_state.left+26, Editor_state.top+Drawing_padding_top+44, 1)
  check_eq(Editor_state.next_history, 4, 'F - test_undo_move_point/next_history')
  -- undo
  edit.run_after_keychord(Editor_state, 'C-z')
  edit.run_after_keychord(Editor_state, 'C-z')  -- bug: need to undo twice
  local drawing = Editor_state.lines[1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(Editor_state.next_history, 2, 'F - test_undo_move_point/next_history')
  check_eq(p2.x, 35, 'F - test_undo_move_point/x')
  check_eq(p2.y, 36, 'F - test_undo_move_point/y')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- undo is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  local p2 = Editor_state.lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.x, 35, 'F - test_undo_move_point/save/x')
  check_eq(p2.y, 36, 'F - test_undo_move_point/save/y')
end

function test_undo_delete_point()
  io.write('\ntest_undo_delete_point')
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
  check_eq(#drawing.shapes, 2, 'F - test_undo_delete_point/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_undo_delete_point/baseline/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'F - test_undo_delete_point/baseline/shape:2')
  -- hover on the common point and delete
  App.mouse_move(Editor_state.left+35, Editor_state.top+Drawing_padding_top+36)
  edit.run_after_keychord(Editor_state, 'C-d')
  check_eq(drawing.shapes[1].mode, 'deleted', 'F - test_undo_delete_point/shape:1')
  check_eq(drawing.shapes[2].mode, 'deleted', 'F - test_undo_delete_point/shape:2')
  -- undo
  edit.run_after_keychord(Editor_state, 'C-z')
  local drawing = Editor_state.lines[1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(Editor_state.next_history, 3, 'F - test_undo_move_point/next_history')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_undo_delete_point/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'F - test_undo_delete_point/shape:2')
  -- wait until save
  Current_time = Current_time + 3.1
  edit.update(Editor_state, 0)
  -- undo is saved
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  check_eq(#Editor_state.lines[1].shapes, 2, 'F - test_undo_delete_point/save')
end
