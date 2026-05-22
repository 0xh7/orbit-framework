local util = require("orbit.util")

local response = {}

local reasons = {
  [100] = "Continue",
  [101] = "Switching Protocols",
  [200] = "OK",
  [201] = "Created",
  [202] = "Accepted",
  [204] = "No Content",
  [301] = "Moved Permanently",
  [302] = "Found",
  [304] = "Not Modified",
  [400] = "Bad Request",
  [401] = "Unauthorized",
  [403] = "Forbidden",
  [404] = "Not Found",
  [405] = "Method Not Allowed",
  [413] = "Payload Too Large",
  [415] = "Unsupported Media Type",
  [422] = "Unprocessable Entity",
  [500] = "Internal Server Error",
  [501] = "Not Implemented",
  [503] = "Service Unavailable",
}

local Response = {}
Response.__index = Response
Response.__orbit_response = true

local function canonical_header_name(name)
  return tostring(name):gsub("(^%l)", string.upper):gsub("%-(%l)", function(char)
    return "-" .. string.upper(char)
  end)
end

local function validate_header_name(name)
  if
    type(name) ~= "string"
    or name == ""
    or not name:match("^[A-Za-z0-9!#$%%&'%*%+%-%._`|~]+$")
  then
    error("header name must be a valid HTTP token", 3)
  end
end

local function normalize_header_value(value)
  value = tostring(value == nil and "" or value)

  if value:find("[\r\n]") then
    error("header value cannot contain CR or LF", 3)
  end

  return value
end

local function normalize_cookie_attribute(value)
  value = tostring(value)

  if value:find("[\r\n;]") then
    error("cookie attribute cannot contain CR, LF, or semicolon", 3)
  end

  return value
end

local function normalize_same_site(value)
  local lower = string.lower(tostring(value))

  if lower == "lax" then
    return "Lax"
  elseif lower == "strict" then
    return "Strict"
  elseif lower == "none" then
    return "None"
  end

  error("cookie SameSite must be Lax, Strict, or None", 3)
end

local function cookie_option(name)
  if name == "same_site" then
    return "SameSite"
  end

  return tostring(name)
    :gsub("_(%l)", function(char)
      return "-" .. string.upper(char)
    end)
    :gsub("^%l", string.upper)
end

local function format_cookie(name, value, options)
  options = options or {}

  if
    type(name) ~= "string"
    or name == ""
    or not name:match("^[A-Za-z0-9!#$%%&'%*%+%-%._`|~]+$")
  then
    error("cookie name must be a valid HTTP token", 3)
  end

  local parts = { name .. "=" .. util.url_encode(value or "") }
  local ordered = { "path", "domain", "expires", "max_age", "same_site" }

  for _, key in ipairs(ordered) do
    local item = options[key]
    if item ~= nil then
      if key == "same_site" then
        item = normalize_same_site(item)
      else
        item = normalize_cookie_attribute(item)
      end

      table.insert(parts, cookie_option(key) .. "=" .. item)
    end
  end

  if options.http_only then
    table.insert(parts, "HttpOnly")
  end

  if options.secure then
    table.insert(parts, "Secure")
  end

  return table.concat(parts, "; ")
end

function Response:status(code)
  code = tonumber(code)
  if not code or code < 100 or code > 999 then
    error("invalid HTTP status code", 2)
  end

  self.status_code = code
  return self
end

function Response:header(name, value)
  validate_header_name(name)

  local key = string.lower(name)
  local canonical = self.header_names[key] or canonical_header_name(name)
  self.header_names[key] = canonical

  if value == nil then
    self.headers[canonical] = nil
    self.header_names[key] = nil
  else
    self.headers[canonical] = normalize_header_value(value)
  end

  return self
end

function Response:append_header(name, value)
  validate_header_name(name)
  value = normalize_header_value(value)

  local key = string.lower(name)
  local canonical = self.header_names[key] or canonical_header_name(name)
  local current = self.headers[canonical]
  self.header_names[key] = canonical

  if current == nil then
    self.headers[canonical] = value
  elseif type(current) == "table" then
    table.insert(current, value)
  else
    self.headers[canonical] = { current, value }
  end

  return self
end

function Response:get_header(name)
  if type(name) ~= "string" then
    return nil
  end

  local canonical = self.header_names[string.lower(name)]
  if canonical then
    local value = self.headers[canonical]

    if type(value) == "table" then
      return table.concat(value, ", ")
    end

    return value
  end

  return nil
end

function Response:type(content_type)
  return self:header("Content-Type", content_type)
end

function Response:send(body)
  if body == nil then
    body = ""
  elseif type(body) ~= "string" then
    body = tostring(body)
  end

  self.body = body
  if not self:get_header("Content-Type") then
    self:type("text/plain; charset=utf-8")
  end

  return self
end

function Response:empty()
  self.body = ""
  return self
end

function Response:cookie(name, value, options)
  return self:append_header("Set-Cookie", format_cookie(name, value, options))
end

function Response:clear_cookie(name, options)
  local clear_options = {}
  for key, value in pairs(options or {}) do
    clear_options[key] = value
  end

  clear_options.max_age = 0
  clear_options.expires = clear_options.expires or "Thu, 01 Jan 1970 00:00:00 GMT"

  return self:cookie(name, "", clear_options)
end

function Response:headers_list()
  local list = {}
  local order = 0

  for name, value in pairs(self.headers) do
    if type(value) == "table" then
      for _, item in ipairs(value) do
        order = order + 1
        table.insert(list, { name, item, order })
      end
    else
      order = order + 1
      table.insert(list, { name, value, order })
    end
  end

  table.sort(list, function(left, right)
    local left_name = string.lower(left[1])
    local right_name = string.lower(right[1])

    if left_name == right_name then
      return left[3] < right[3]
    end

    return left_name < right_name
  end)

  return list
end

function response.reason(status_code)
  return reasons[tonumber(status_code)] or "HTTP Status"
end

function response.new(status_code, body, headers)
  local instance = setmetatable({
    status_code = tonumber(status_code) or 200,
    headers = {},
    header_names = {},
    body = "",
  }, Response)

  for name, value in pairs(headers or {}) do
    instance:header(name, value)
  end

  if body ~= nil then
    instance:send(body)
  end

  return instance
end

response.Response = Response

return response
