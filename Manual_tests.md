I care a lot about being able to automatically check _any_ property about my
program before it ever runs. However, some things don't have tests yet, either
because I don't know how to test them or because I've been lazy. I'll at least
record those here.

Initializing settings:
  - delete app settings, start; window opens running the text editor
  - quit while running the text editor, restart; window opens running the text editor in same position+dimensions
  - quit while editing source (color; no drawings; no selection), restart; window opens editing source in same position+dimensions
  - start out running the text editor, move window, press ctrl+e twice; window is running text editor in same position+dimensions
  - start out editing source, move window, press ctrl+e twice; window is editing source in same position+dimensions
  - no log file; switching to source works

Code loading:
* run love with directory; text editor runs
* run love with zip file; text editor runs

* How the screen looks. Our tests use a level of indirection to check text and
  graphics printed to screen, but not the precise pixels they translate to.
    - where exactly the cursor is drawn to highlight a given character
    - analogously, how a shape precisely looks as you draw it

* start out running the text editor, press ctrl+e to edit source, make a change to the source, press ctrl+e twice to return to the source editor; the change should be preserved.

### Other compromises

Lua is dynamically typed. Tests can't patch over lack of type-checking.

* All strings are UTF-8. Bytes within them are not characters. I try to label
  byte offsets with the suffix `_offset`, and character positions as `_pos`.
  For example, `string.sub` should never use a `_pos` to substring, only an
  `_offset`.

* Some ADT/interface support would be helpful in keeping per-line state in
  sync. Any change to line data should clear line `fragments` and
  `screen_line_starting_pos`.

* Some inputs get processed in love.textinput and some in love.keypressed.
  Several bugs have arisen due to destructive interference between the two for
  some key chord. I wish I could guarantee that the two sets are disjoint. But
  perhaps I'm not thinking about this right.

* Like any high-level language, it's easy to accidentally alias two non-scalar
  variables. I wish there was a way to require copy when assigning.

* I wish I could require pixel coordinates to be integers. The editor
  defensively converts input margins to integers.

* My test harness automatically runs `test_*` methods -- but only at the
  top-level. I wish there was a way to raise warnings if someone defines such
  a function inside a dict somewhere.
