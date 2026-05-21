local util = require("orbit.util")

local router = {}

local Router = {}
Router.__index = Router

local function escape_pattern(value)
  return (value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function validate_path(path)
  if type(path) ~= "string" or path == "" or path:sub(1, 1) ~= "/" then
    error("route path must be an absolute path", 3)
  end
end

local function split_path(path)
  local segments = {}

  if path == "/" then
    return segments
  end

  path = path:gsub("/+$", "")

  for segment in path:gmatch("[^/]+") do
    table.insert(segments, segment)
  end

  return segments
end

local function compile_path(path)
  validate_path(path)

  local keys = {}
  local chunks = {}
  local segments = split_path(path)

  if #segments == 0 then
    return "^/$", keys
  end

  for _, segment in ipairs(segments) do
    local param = segment:match("^:([A-Za-z_][A-Za-z0-9_]*)$")
    local wildcard = segment:match("^%*([A-Za-z_][A-Za-z0-9_]*)$")

    if param then
      table.insert(keys, param)
      table.insert(chunks, "([^/]+)")
    elseif wildcard then
      table.insert(keys, wildcard)
      table.insert(chunks, "(.*)")
    else
      table.insert(chunks, escape_pattern(segment))
    end
  end

  return "^/" .. table.concat(chunks, "/") .. "$", keys
end

local function method_matches(route_method, request_method)
  return route_method == "ALL"
    or route_method == request_method
    or (request_method == "HEAD" and route_method == "GET")
end

function Router:add(method, path, handler)
  if not util.is_callable(handler) then
    error("route handler must be callable", 2)
  end

  local pattern, keys = compile_path(path)
  table.insert(self.routes, {
    method = string.upper(method),
    path = path,
    pattern = pattern,
    keys = keys,
    handler = handler,
  })

  return self
end

function Router:match(method, path)
  method = string.upper(method or "GET")
  path = path or "/"

  for _, route in ipairs(self.routes) do
    if method_matches(route.method, method) then
      local captures = { path:match(route.pattern) }

      if #captures > 0 or route.path == path then
        local params = {}

        for index, key in ipairs(route.keys) do
          params[key] = util.url_decode(captures[index], false)
        end

        return route, params
      end
    end
  end

  return nil, {}
end

function Router:allowed_methods(path)
  local methods = {}
  local seen = {}

  for _, route in ipairs(self.routes) do
    if path:match(route.pattern) then
      if not seen[route.method] then
        seen[route.method] = true
        table.insert(methods, route.method)
      end

      if route.method == "GET" and not seen.HEAD then
        seen.HEAD = true
        table.insert(methods, "HEAD")
      end
    end
  end

  table.sort(methods)
  return methods
end

function router.new()
  return setmetatable({ routes = {} }, Router)
end

router.Router = Router

return router
