local request = require("orbit.request")
local response = require("orbit.response")
local util = require("orbit.util")

local http = {}

local DEFAULT_MAX_BODY_SIZE = 1024 * 1024
local DEFAULT_MAX_HEADER_BYTES = 32 * 1024
local DEFAULT_MAX_LINE_SIZE = 8 * 1024
local TOKEN_PATTERN = "^[A-Za-z0-9!#$%%&'%*%+%-%._`|~]+$"

local function trim_cr(line)
  return (line:gsub("\r$", ""))
end

local function error_response(status_code, message)
  return response
    .new(status_code)
    :type("text/plain; charset=utf-8")
    :send(message or response.reason(status_code))
end

local function parse_head_lines(lines)
  local method, target, version = lines[1]:match("^(%S+)%s+(%S+)%s+HTTP/(%d%.%d)$")
  if not method then
    return nil, error_response(400, "Malformed request line")
  end

  if not method:match(TOKEN_PATTERN) then
    return nil, error_response(400, "Invalid request method")
  end

  if target:sub(1, 1) ~= "/" then
    return nil, error_response(400, "Invalid request target")
  end

  if version ~= "1.0" and version ~= "1.1" then
    return nil, error_response(400, "Unsupported HTTP Version")
  end

  local headers = {}
  for index = 2, #lines do
    local line = lines[index]
    local name, value = line:match("^([^:]+):%s*(.*)$")

    if not name or name == "" or not name:match(TOKEN_PATTERN) then
      return nil, error_response(400, "Malformed header")
    end

    local key = string.lower(name)
    if headers[key] then
      headers[key] = headers[key] .. ", " .. value
    else
      headers[key] = value
    end
  end

  if version == "1.1" and (not headers.host or headers.host == "") then
    return nil, error_response(400, "Host header required")
  end

  return {
    method = string.upper(method),
    target = target,
    version = version,
    headers = headers,
  }
end

local function finish_request(head, body, options)
  options = options or {}
  body = body or ""

  local transfer_encoding = head.headers["transfer-encoding"]
  if transfer_encoding and string.lower(transfer_encoding) ~= "identity" then
    return nil, error_response(400, "Unsupported Transfer-Encoding")
  end

  local content_length = head.headers["content-length"]
  if content_length then
    if not content_length:match("^%d+$") then
      return nil, error_response(400, "Invalid Content-Length")
    end

    content_length = tonumber(content_length)
  else
    content_length = 0
  end

  local max_body_size = options.max_body_size or DEFAULT_MAX_BODY_SIZE
  if content_length > max_body_size then
    return nil, error_response(413, "Payload Too Large")
  end

  if #body < content_length then
    return nil, error_response(400, "Incomplete request body")
  end

  body = body:sub(1, content_length)

  local connection = string.lower(head.headers.connection or "")
  local keep_alive
  if head.version == "1.1" then
    keep_alive = connection ~= "close"
  else
    keep_alive = connection == "keep-alive"
  end

  local path, query_string = util.split_target(head.target)

  return request.new({
    method = head.method,
    target = head.target,
    path = path,
    query_string = query_string,
    version = head.version,
    headers = head.headers,
    body = body,
    keep_alive = keep_alive,
  })
end

function http.parse_request_string(source, options)
  options = options or {}

  local head_source, body = source:match("^(.-)\r\n\r\n(.*)$")
  if not head_source then
    head_source, body = source:match("^(.-)\n\n(.*)$")
  end

  if not head_source then
    return nil, error_response(400, "Malformed request")
  end

  if #head_source > (options.max_header_bytes or DEFAULT_MAX_HEADER_BYTES) then
    return nil, error_response(400, "Headers Too Large")
  end

  local lines = {}
  for line in (head_source .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, trim_cr(line))
  end

  local head, err = parse_head_lines(lines)
  if not head then
    return nil, err
  end

  return finish_request(head, body, options)
end

function http.read_request(client, options)
  options = options or {}

  local max_line_size = options.max_line_size or DEFAULT_MAX_LINE_SIZE
  local max_header_bytes = options.max_header_bytes or DEFAULT_MAX_HEADER_BYTES

  local first, err = client:receive("*l")
  if not first then
    return nil, err or "closed"
  end

  first = trim_cr(first)
  if #first > max_line_size then
    return nil, "bad_request", error_response(400, "Request Line Too Large")
  end

  local lines = { first }
  local header_bytes = #first

  while true do
    local line
    line, err = client:receive("*l")
    if not line then
      return nil, err or "closed"
    end

    line = trim_cr(line)
    if #line > max_line_size then
      return nil, "bad_request", error_response(400, "Header Line Too Large")
    end

    if line == "" then
      break
    end

    header_bytes = header_bytes + #line + 2
    if header_bytes > max_header_bytes then
      return nil, "bad_request", error_response(400, "Headers Too Large")
    end

    table.insert(lines, line)
  end

  local head, parse_error = parse_head_lines(lines)
  if not head then
    return nil, "bad_request", parse_error
  end

  local length = tonumber(head.headers["content-length"] or "0") or 0
  if length > (options.max_body_size or DEFAULT_MAX_BODY_SIZE) then
    return nil, "bad_request", error_response(413, "Payload Too Large")
  end

  local body = ""
  if length > 0 then
    body, err = client:receive(length)
    if not body then
      return nil, err or "closed", error_response(400, "Incomplete request body")
    end
  end

  local req, finish_error = finish_request(head, body, options)
  if not req then
    return nil, "bad_request", finish_error
  end

  return req
end

function http.serialize_response(res, keep_alive, method)
  if getmetatable(res) ~= response.Response then
    res = response.new(200, res)
  end

  local body = res.body or ""
  if res.status_code == 204 or res.status_code == 304 then
    body = ""
  end

  if not res:get_header("Content-Length") then
    res:header("Content-Length", tostring(#body))
  end

  if not keep_alive then
    res:header("Connection", "close")
  elseif not res:get_header("Connection") then
    res:header("Connection", keep_alive and "keep-alive" or "close")
  end

  if not res:get_header("Server") then
    res:header("Server", "Orbit")
  end

  local lines = {
    "HTTP/1.1 " .. tostring(res.status_code) .. " " .. response.reason(res.status_code),
  }

  for _, header in ipairs(res:headers_list()) do
    table.insert(lines, header[1] .. ": " .. header[2])
  end

  table.insert(lines, "")
  table.insert(lines, "")

  if method == "HEAD" then
    return table.concat(lines, "\r\n")
  end

  return table.concat(lines, "\r\n") .. body
end

function http.write_response(client, res, keep_alive, method)
  return client:send(http.serialize_response(res, keep_alive, method))
end

http.error_response = error_response
http.DEFAULT_MAX_BODY_SIZE = DEFAULT_MAX_BODY_SIZE

return http
