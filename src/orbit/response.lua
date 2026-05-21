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

function Response:status(code)
  code = tonumber(code)
  if not code or code < 100 or code > 999 then
    error("invalid HTTP status code", 2)
  end

  self.status_code = code
  return self
end

function Response:header(name, value)
  if type(name) ~= "string" or name == "" then
    error("header name must be a non-empty string", 2)
  end

  local key = string.lower(name)
  local canonical = self.header_names[key] or canonical_header_name(name)
  self.header_names[key] = canonical

  if value == nil then
    self.headers[canonical] = nil
    self.header_names[key] = nil
  else
    self.headers[canonical] = tostring(value)
  end

  return self
end

function Response:get_header(name)
  local canonical = self.header_names[string.lower(name)]
  if canonical then
    return self.headers[canonical]
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

function Response:headers_list()
  local list = {}

  for name, value in pairs(self.headers) do
    table.insert(list, { name, value })
  end

  table.sort(list, function(left, right)
    return string.lower(left[1]) < string.lower(right[1])
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
