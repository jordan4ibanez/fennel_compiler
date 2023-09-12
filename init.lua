-- mod-version:3

--[[

This is a modified version of this https://git.sr.ht/~wintershadows/dotfiles/tree/356fb9cd/item/.config/nvim/lua/fennel-init.lua

Thanks, wintershadows!

And the additional pathloader tutorial from Adam.

Thanks, Adam!

]]--

local status, fennel = pcall(require, "plugins.fennel_compiler.fennel")

local compile = fennel.dofile

local enable_debug = false

if not status then
  print("Fennel Compiler: FAILED TO LOAD FENNEL COMPILER!")
  return nil
end

-- We enable Lite XL to require Fennel files.
package.path = DATADIR .. '/?.fnl;' .. package.path
package.path = DATADIR .. '/?/init.fnl;' .. package.path
package.path = USERDIR .. '/?.fnl;' .. package.path
package.path = USERDIR .. '/?/init.fnl;' .. package.path

package.path = DATADIR .. '/libraries/?.fnl;' .. package.path
package.path = DATADIR .. '/libraries/?/init.fnl;' .. package.path
package.path = USERDIR .. '/libraries/?.fnl;' .. package.path
package.path = USERDIR .. '/libraries/?/init.fnl;' .. package.path

package.path = USERDIR .. '/plugins/?.fnl;' .. package.path
package.path = USERDIR .. '/plugins/?/init.fnl;' .. package.path
package.path = DATADIR .. '/plugins/?.fnl;' .. package.path
package.path = DATADIR .. '/plugins/?/init.fnl;' .. package.path

-- print(package.path)

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

-- And this is a monstrous hack to load all fennel files automatically.

local function get_plugin_details(filename)
  local info = system.get_file_info(filename)
  if info ~= nil and info.type == "dir" then
    filename = filename .. "/init.fnl"
    info = system.get_file_info(filename)
  end
  if not info or not filename:match("%.fnl$") then return false end
  local f = io.open(filename, "r")
  if not f then return false end
  local priority = false
  local version_match = false
  local gotten_version = 0
  for line in f:lines() do
    if not version_match then
      local mod_version = line:match('%;%;.*%f[%a]mod%-version%s*:%s*(%d+)')
      if mod_version then
        version_match = (mod_version == MOD_VERSION)
        gotten_version = mod_version
      end
    end
    if not priority then
      priority = line:match('%;%;.*%f[%a]priority%s*:%s*(%d+)')
      if priority then priority = tonumber(priority) end
    end
    if version_match then
      break
    end
  end
  f:close()
  return true, {
    version_match = version_match,
    priority = priority or 100,
    version = {gotten_version}
  }
end


local function load_plugins()
  local no_errors = true
  local refused_list = {
    userdir = {dir = USERDIR, plugins = {}},
    datadir = {dir = DATADIR, plugins = {}},
  }
  local files, ordered = {}, {}
  for _, root_dir in ipairs {DATADIR, USERDIR} do
    local plugin_dir = root_dir .. PATHSEP .. "plugins"
    for _, filename in ipairs(system.list_dir(plugin_dir) or {}) do
      if not files[filename] then
        table.insert(
          ordered, {file = filename}
        )
      end
      -- user plugins will always replace system plugins
      files[filename] = plugin_dir
    end
  end

  for _, plugin in ipairs(ordered) do
    local dir = files[plugin.file]
    local name = plugin.file:match("(.-)%.fnl$") or plugin.file
    
    local is_lua_file, details = get_plugin_details(dir .. PATHSEP .. plugin.file)

    plugin.valid = is_lua_file

    if enable_debug and plugin.valid then
      print("Fennel Compiler: Found valid module:", plugin.file)
    end
    
    plugin.name = name
    plugin.dir = dir
    plugin.priority = details and details.priority or 100
    plugin.version_match = details and details.version_match or false
    plugin.version = details and details.version or {}
    plugin.version_string = #plugin.version > 0 and table.concat(plugin.version, ".") or "unknown"
  end

  -- sort by priority or name for plugins that have same priority
  table.sort(ordered, function(a, b)
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    return a.name < b.name
  end)

  local config = require "core.config"
  local core = require "core"


  local load_start = system.get_time()
  for _, plugin in ipairs(ordered) do
    if plugin.valid then
      if not config.skip_plugins_version and not plugin.version_match then
        error(string.format(
          "Version mismatch for plugin %q[%s] from %s",
          plugin.name,
          plugin.version_string,
          plugin.dir))
        local rlist = plugin.dir:find(USERDIR, 1, true) == 1
          and 'userdir' or 'datadir'
        local list = refused_list[rlist].plugins
        table.insert(list, plugin)
      elseif config.plugins[plugin.name] ~= false then
        local start = system.get_time()
        
        -- print("plugins." .. plugin.name)
        
        local ok, loaded_plugin = core.try(require, "plugins." .. plugin.name)

        -- print(ok, loaded_plugin)
        
        if ok then
          local plugin_version = ""
          if plugin.version_string ~= MOD_VERSION then
            plugin_version = "["..plugin.version_string.."]"
          end
          core.log_quiet(
            "Loaded plugin %q%s from %s in %.1fms",
            plugin.name,
            plugin_version,
            plugin.dir,
            (system.get_time() - start) * 1000
          )
        end
        if not ok then
          -- Hook the fennel compiler straight into the error log.
          error(loaded_plugin)
          no_errors = false
        elseif config.plugins[plugin.name].onload then
          -- print(config.plugins[plugin.name])
          local success, err = core.try(config.plugins[plugin.name].onload, loaded_plugin)
          print(err)
          if not success then error(err) end
        end
      end
    end
  end
  core.log_quiet(
    "Loaded all plugins in %.1fms",
    (system.get_time() - load_start) * 1000
  )
  return no_errors, refused_list
end

load_plugins()

return fennel
