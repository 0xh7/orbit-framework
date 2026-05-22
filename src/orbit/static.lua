local util = require("orbit.util")

local static = {}

local types = {
  css = "text/css; charset=utf-8",
  gif = "image/gif",
  html = "text/html; charset=utf-8",
  jpeg = "image/jpeg",
  jpg = "image/jpeg",
  js = "application/javascript; charset=utf-8",
  json = "application/json; charset=utf-8",
  map = "application/json; charset=utf-8",
  png = "image/png",
  svg = "image/svg+xml",
  txt = "text/plain; charset=utf-8",
  webp = "image/webp",
}

local function path_matches(prefix, path)
  if prefix == "/" then
    return true
  end

  return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end

local function strip_prefix(prefix, path)
  if prefix == "/" then
    return path:gsub("^/+", "")
  end

  local rest = path:sub(#prefix + 1)
  return rest:gsub("^/+", "")
end

local function safe_relative_path(path)
  path = util.url_decode(path or "", false)

  if path:find("%z") or path:find("\\", 1, true) or path:sub(1, 1) == "/" then
    return nil
  end

  for segment in path:gmatch("[^/]+") do
    if segment == ".." then
      return nil
    end
  end

  return path
end

function static.content_type(path)
  local extension = tostring(path):match("%.([A-Za-z0-9]+)$")
  if extension then
    return types[string.lower(extension)] or "application/octet-stream"
  end

  return "application/octet-stream"
end

function static.middleware(prefix, root, options)
  options = options or {}

  if type(prefix) ~= "string" or prefix == "" or prefix:sub(1, 1) ~= "/" then
    error("static prefix must be an absolute path", 2)
  end

  if type(root) ~= "string" or root == "" then
    error("static root must be a non-empty string", 2)
  end

  prefix = prefix:gsub("/+$", "")
  if prefix == "" then
    prefix = "/"
  end

  local index = options.index or "index.html"

  return function(ctx, next_layer)
    local method = ctx.req.method
    if method ~= "GET" and method ~= "HEAD" then
      return next_layer()
    end

    if not path_matches(prefix, ctx.req.path) then
      return next_layer()
    end

    local relative = safe_relative_path(strip_prefix(prefix, ctx.req.path))
    if not relative then
      return ctx:status(403):text("Forbidden")
    end

    if relative == "" or relative:sub(-1) == "/" then
      relative = relative .. index
    end

    local path = util.join_path(root, relative)
    local file = io.open(path, "rb")
    if not file then
      return next_layer()
    end

    local body = file:read("*a")
    file:close()

    if body == nil then
      return ctx:status(500):text("Internal Server Error")
    end

    if options.cache_control then
      ctx:set("Cache-Control", options.cache_control)
    end

    return ctx:type(options.content_type or static.content_type(path)):send(body)
  end
end

return static
