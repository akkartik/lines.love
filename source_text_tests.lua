-- major tests for text editing flows
--
-- I'm checking the precise state of the screen in this file, an inherently
-- brittle approach that depends on details of the font and text shaping
-- algorithms used by a particular release of LÖVE.
--
-- (This brittleness is one reason lines2 and its forks have no tests.)
--
-- To manage the brittleness, there'll be one version of this file for each
-- distinct LÖVE version that introduces font changes.

Version, Major_version = App.love_version()
if Major_version == 11 then
  load_file_from_source_or_save_directory('source_text_tests_love11.lua')
elseif Major_version == 12 then
  -- not released/stable yet
  load_file_from_source_or_save_directory('source_text_tests_love12.lua')
end
