local orbit = require("orbit")
local util = require("orbit.util")

local cli = {}

local function print_help(write)
  write([[
Orbit - a Lua backend framework

Usage:
  orbit serve <app.lua> [--host 127.0.0.1] [--port 8080]
  orbit new <name>
  orbit version
]])
end

local function read_option(args, name, default)
  for index = 1, #args do
    if args[index] == name then
      return args[index + 1] or default
    end
  end

  return default
end

local function validate_project_name(name)
  if not name or name == "" then
    error("project name is required", 0)
  end

  if not name:match("^[A-Za-z0-9][A-Za-z0-9_.%-]*$") then
    error("project name must use only letters, numbers, dots, underscores, and dashes", 0)
  end
end

local function load_app(path)
  local previous_path = package.path
  package.path = util.join_path(util.dirname(path), "?.lua") .. ";" .. previous_path

  local chunk, err = loadfile(path)
  if not chunk then
    package.path = previous_path
    error(err, 0)
  end

  local ok, result = pcall(chunk)
  package.path = previous_path

  if not ok then
    error(result, 0)
  end

  if type(result) == "function" then
    result = result()
  end

  if type(result) ~= "table" or type(result.listen) ~= "function" then
    error("app file must return an Orbit app", 0)
  end

  return result
end

local function write_file(path, body)
  local file = io.open(path, "r")
  if file then
    file:close()
    error("refusing to overwrite existing file: " .. path, 0)
  end

  local err
  file, err = io.open(path, "w")
  if not file then
    error(err, 0)
  end

  file:write(body)
  file:close()
end

function cli.new_project(name)
  validate_project_name(name)

  assert(os.execute("mkdir -p " .. name))

  write_file(
    util.join_path(name, "app.lua"),
    [[
local orbit = require("orbit")

local app = orbit.new()

app:get("/", function(ctx)
  return ctx:json({ message = "Hello from Orbit" })
end)

return app
]]
  )

  write_file(
    util.join_path(name, "README.md"),
    "# " .. name .. "\n\nRun the app with:\n\n```sh\norbit serve app.lua\n```\n"
  )
  io.write("Created " .. name .. "\n")
end

function cli.run(args, write)
  args = args or {}
  write = write or io.write

  local command = args[1]

  if command == "serve" then
    local path = args[2]
    if not path then
      error("app file is required", 0)
    end

    local app = load_app(path)
    return app:listen({
      host = read_option(args, "--host", "127.0.0.1"),
      port = tonumber(read_option(args, "--port", "8080")),
    })
  elseif command == "new" then
    return cli.new_project(args[2])
  elseif command == "version" then
    write(orbit._VERSION .. "\n")
    return true
  elseif command == nil or command == "help" or command == "--help" or command == "-h" then
    print_help(write)
    return true
  end

  error("unknown command: " .. tostring(command), 0)
end

return cli
