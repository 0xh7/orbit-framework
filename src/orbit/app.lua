local json = require("orbit.json")
local request = require("orbit.request")
local response = require("orbit.response")
local router = require("orbit.router")
local util = require("orbit.util")

local app = {}

local Context = {}
Context.__index = Context

function Context:status(code)
  self.res:status(code)
  return self
end

function Context:set(name, value)
  self.res:header(name, value)
  return self
end

function Context:type(content_type)
  self.res:type(content_type)
  return self
end

function Context:send(body)
  return self.res:send(body)
end

function Context:text(body)
  self.res:type("text/plain; charset=utf-8")
  return self.res:send(body)
end

function Context:html(body)
  self.res:type("text/html; charset=utf-8")
  return self.res:send(body)
end

function Context:json(value)
  self.res:type("application/json; charset=utf-8")
  return self.res:send(json.encode(value))
end

local App = {}
App.__index = App

local function path_matches(prefix, path)
  if prefix == "/" then
    return true
  end

  return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end

local function apply_result(ctx, result)
  if result == nil then
    return ctx.res
  end

  if type(result) == "table" and result.__orbit_response then
    return result
  elseif type(result) == "table" then
    return ctx:json(result)
  end

  return ctx:send(result)
end

function App:new_context(req, res)
  return setmetatable({
    app = self,
    req = req,
    request = req,
    res = res,
    response = res,
    params = req.params or {},
    query = req.query or {},
    state = {},
  }, Context)
end

function App:use(path, handler)
  if util.is_callable(path) and handler == nil then
    handler = path
    path = "/"
  end

  if type(path) ~= "string" or path == "" or path:sub(1, 1) ~= "/" then
    error("middleware path must be an absolute path", 2)
  end

  if not util.is_callable(handler) then
    error("middleware handler must be callable", 2)
  end

  table.insert(self.middlewares, { path = path, handler = handler })
  return self
end

function App:route(method, path, handler)
  self.router:add(method, path, handler)
  return self
end

function App:all(path, handler)
  return self:route("ALL", path, handler)
end

function App:get(path, handler)
  return self:route("GET", path, handler)
end

function App:post(path, handler)
  return self:route("POST", path, handler)
end

function App:put(path, handler)
  return self:route("PUT", path, handler)
end

function App:patch(path, handler)
  return self:route("PATCH", path, handler)
end

function App:delete(path, handler)
  return self:route("DELETE", path, handler)
end

function App:options(path, handler)
  return self:route("OPTIONS", path, handler)
end

function App:head(path, handler)
  return self:route("HEAD", path, handler)
end

function App:on_error(handler)
  if not util.is_callable(handler) then
    error("error handler must be callable", 2)
  end

  self.error_handler = handler
  return self
end

function App.not_found(_self, ctx)
  return ctx:status(404):text("Not Found")
end

function App.method_not_allowed(_self, ctx, methods)
  ctx:set("Allow", table.concat(methods, ", "))
  return ctx:status(405):text("Method Not Allowed")
end

function App:handle_error(ctx, message)
  if self.error_handler then
    local ok, result = pcall(self.error_handler, ctx, message)
    if ok then
      return apply_result(ctx, result)
    end
  end

  return ctx:status(500):text("Internal Server Error")
end

function App:build_layers(req)
  local layers = {}

  for _, middleware in ipairs(self.middlewares) do
    if path_matches(middleware.path, req.path) then
      table.insert(layers, middleware)
    end
  end

  local route, params = self.router:match(req.method, req.path)
  req.params = params or {}

  if route then
    table.insert(layers, {
      path = route.path,
      handler = function(ctx)
        return route.handler(ctx)
      end,
    })
  else
    local methods = self.router:allowed_methods(req.path)

    table.insert(layers, {
      path = req.path,
      handler = function(ctx)
        if #methods > 0 then
          return self:method_not_allowed(ctx, methods)
        end

        return self:not_found(ctx)
      end,
    })
  end

  return layers
end

function App:handle(raw_request)
  local req = raw_request
  if getmetatable(req) ~= request.Request then
    req = request.new(raw_request)
  end

  local res = response.new()
  local layers = self:build_layers(req)
  local ctx = self:new_context(req, res)

  local function run(index)
    local layer = layers[index]
    if not layer then
      return ctx.res
    end

    local called_next = false
    local function next_layer()
      if called_next then
        error("next() called multiple times")
      end

      called_next = true
      return run(index + 1)
    end

    local result = layer.handler(ctx, next_layer)
    if result ~= nil then
      return apply_result(ctx, result)
    end

    return ctx.res
  end

  local ok, result = xpcall(function()
    return run(1)
  end, debug.traceback)

  if not ok then
    return self:handle_error(ctx, result)
  end

  return result or ctx.res
end

function App:listen(options)
  local server = require("orbit.server")
  return server.listen(self, options or {})
end

function app.new(options)
  options = options or {}

  return setmetatable({
    router = router.new(),
    middlewares = {},
    settings = options,
  }, App)
end

app.App = App
app.Context = Context

return app
