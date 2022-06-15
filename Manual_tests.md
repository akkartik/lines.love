I care a lot about being able to automatically check _any_ property about my
program before it ever runs. However, some things don't have tests yet.

### Compromises

Lua is dynamically typed. Tests can't patch over lack of type-checking.

* All strings are UTF-8. Bytes within them are not characters. I try to label
  byte offsets as _offset, and character positions as _pos. For example,
  string.sub should never use a _pos to substring, only an _offset.


### Todo list

undo:
  naming points
  deleting points
  moving points

resize:
  create a file containing a long line of characters without spaces. try
  resizing the window vertically and horizontally, as far as possible.
