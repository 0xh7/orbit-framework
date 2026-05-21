local json = require("orbit.json")
local util = require("orbit.util")

local request = {}

local Request = {}
Request.__index = Request

function Request:header(name)
  return self.headers[string.lower(name)]
end

function Request:is(content_type)
  local actual = self:header("content-type")
  if not actual then
    return false
  end

  return string.lower(actual):find(string.lower(content_type), 1, true) ~= nil
end

function Request:json()
  return json.decode(self.body or "")
end

function Request:form()
  return util.parse_query(self.body or "")
end

function request.new(data)
  data = data or {}

  local target = data.target or data.path or "/"
  local path, query_string = util.split_target(target)

  if data.path then
    path = data.path
  end

  if data.query_string ~= nil then
    query_string = data.query_string
  end

  return setmetatable({
    method = string.upper(data.method or "GET"),
    target = target,
    path = path,
    query_string = query_string,
    query = data.query or util.parse_query(query_string),
    version = data.version or "1.1",
    headers = util.lower_keys(data.headers or {}),
    body = data.body or "",
    params = data.params or {},
    remote_addr = data.remote_addr,
    keep_alive = data.keep_alive,
  }, Request)
end

request.Request = Request

return request
