local util = {}

util.unpack = rawget(table, "unpack") or unpack

function util.is_callable(value)
  if type(value) == "function" then
    return true
  end

  local mt = getmetatable(value)
  return mt ~= nil and type(mt.__call) == "function"
end

function util.url_decode(value, plus_as_space)
  if value == nil then
    return ""
  end

  value = tostring(value)

  if plus_as_space then
    value = value:gsub("+", " ")
  end

  return (value:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

function util.url_encode(value)
  value = tostring(value == nil and "" or value)

  return (
    value:gsub("([^A-Za-z0-9_%.%-%~])", function(char)
      return string.format("%%%02X", string.byte(char))
    end)
  )
end

function util.parse_query(query_string)
  local params = {}

  if query_string == nil or query_string == "" then
    return params
  end

  for pair in string.gmatch(query_string .. "&", "(.-)&") do
    if pair ~= "" then
      local key, value = pair:match("^([^=]*)=?(.*)$")
      key = util.url_decode(key, true)
      value = util.url_decode(value, true)

      if params[key] == nil then
        params[key] = value
      elseif type(params[key]) == "table" then
        table.insert(params[key], value)
      else
        params[key] = { params[key], value }
      end
    end
  end

  return params
end

function util.split_target(target)
  target = target or "/"

  local path, query_string = target:match("^([^?]*)%??(.*)$")
  if path == "" then
    path = "/"
  end

  return path, query_string or ""
end

function util.lower_keys(headers)
  local normalized = {}

  for name, value in pairs(headers or {}) do
    normalized[string.lower(name)] = value
  end

  return normalized
end

function util.dirname(path)
  local dir = tostring(path):match("^(.*)[/\\][^/\\]+$")
  return dir or "."
end

function util.join_path(...)
  local parts = { ... }
  local path = table.concat(parts, "/")
  path = path:gsub("/+", "/")
  return path
end

return util
