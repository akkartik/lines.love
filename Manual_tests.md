I care a lot about being able to automatically check _any_ property about my
program before it ever runs. However, some things don't have tests yet, either
because I don't know how to test them or because I've been lazy. I'll at least
record those here.

### Compromises

Lua is dynamically typed. Tests can't patch over lack of type-checking.

* All strings are UTF-8. Bytes within them are not characters. I try to label
  byte offsets with the suffix `_offset`, and character positions as `_pos`.
  For example, `string.sub` should never use a `_pos` to substring, only an
  `_offset`.

* Some ADT/interface support would be helpful in keeping per-line state in
  sync. Any change to line data should clear line `fragments` and
  `screen_line_starting_pos`.
