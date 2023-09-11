-- mod-version:3

-- Injecting straight into core.
local core = require "core"

-- This will only into memory once.

-- Load up fennel programming language. Into plugin table scope.
if not core.fennel_language_compiler then
  core.fennel_language_compiler = require("plugins.fennel.fennel").install()
  -- Now we check it's working.
  core.fennel_language_compiler.dofile("main.fnl")
else
  print("ERROR! FAILED TO LOAD FENNEL COMPILER!")
end

-- Globalized fennel compiler.
return core.fennel_language_compiler.dofile

--[[

Now you'd use it like this:

local fennel_compile = require("fennel")

fennel_compile("my_cool_file.fnl")

]]--

