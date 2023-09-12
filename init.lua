-- mod-version:3

--[[

This is a modified version of this https://git.sr.ht/~wintershadows/dotfiles/tree/356fb9cd/item/.config/nvim/lua/fennel-init.lua

Thanks, wintershadows!

And the additional pathloader tutorial from Adam.

Thanks, Adam!

]]--

local status, fennel = pcall(require, "plugins.fennel_compiler.fennel")

local compile = fennel.dofile

local enable_debug = true

if not status then
  print("Fennel Compiler: FAILED TO LOAD FENNEL COMPILER!")
  return nil
end

package.fnlpath = package.path:gsub(".lua", ".fnl")

table.insert(package.searchers, function(modname)
  
  local path, err = package.searchpath(modname, package.fnlpath)

  if enable_debug then
    if path then
      print(string.format("Fennel Compiler: (require) got path (%s)", path))
    else
      print("Fennel Compiler: (require) Got no path!")
    end
  end
  
  if not path then return err end

  if enable_debug then
    print("Fennel Compiler: (require) Now walking into...")
  end
  
  return function()
    if enable_debug then
      print("Fennel Compiler: (require) Executing loader")
    end
    local chunk = compile(path)
    return chunk
  end, path
end)

local function _fennel_runtime_searcher(name)

  local basename = name:gsub('%.', '/')

  if enable_debug then
    print(string.format("Fennel Compiler: Seeking loader for '%s'", basename))
  end

  local paths = {
    basename,
  }

  for i,path in ipairs(paths) do
  
    local found = package.searchpath(path, package.fnlpath)

    if enable_debug and found then
      print(string.format("Fennel Compiler: Found fennel file in (%s)", found))
    end

    if found then
      if enable_debug then
        print(string.format("Fennel Compiler: Returning loader for %s (%s)", basename, found))
      end
      return function()
        if enable_debug then
          print(string.format("Fennel Compiler: Executing loader for %s (%s)", basename, found))
        end
        return fennel.dofile(found)
      end
    end
  end
end

table.insert(package.searchers, fennel.searcher)

table.insert(package.searchers, 2, _fennel_runtime_searcher)

if enable_debug then
  print("Loaders before Fennel init:")
  for _, searcher in ipairs(package.searchers) do
    print("  "..tostring(searcher))
  end
end

-- This is a self-bootstrapping test.
require("plugins.fennel_compiler.main")

return fennel
