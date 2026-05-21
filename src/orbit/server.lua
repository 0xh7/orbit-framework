local http = require("orbit.http")

local server = {}

local function handle_client(app, client, options, state)
  client:settimeout(options.client_timeout or 10)

  while true do
    if state.max_requests and state.handled >= state.max_requests then
      break
    end

    local req, err, err_response = http.read_request(client, options)

    if not req then
      if err_response then
        http.write_response(client, err_response, false)
      end

      if err == "closed" or err == "timeout" or not err_response then
        break
      end

      break
    end

    state.handled = state.handled + 1

    local res = app:handle(req)
    local keep_alive = req.keep_alive

    local connection = res:get_header("connection")
    if connection and string.lower(connection):find("close", 1, true) then
      keep_alive = false
    end

    if state.max_requests and state.handled >= state.max_requests then
      keep_alive = false
    end

    http.write_response(client, res, keep_alive, req.method)

    if not keep_alive then
      break
    end
  end

  client:close()
end

function server.listen(app, options)
  options = options or {}

  local ok, socket = pcall(require, "socket")
  if not ok then
    error("Orbit standalone server requires LuaSocket: luarocks install luasocket", 2)
  end

  local host = options.host or "127.0.0.1"
  local port = tonumber(options.port or 8080)
  local backlog = tonumber(options.backlog or 128)
  local tcp = assert(socket.bind(host, port, backlog))

  if not options.silent then
    io.stderr:write(string.format("Orbit listening on http://%s:%d\n", host, port))
  end

  local state = {
    handled = 0,
    max_requests = options.max_requests and tonumber(options.max_requests) or nil,
  }

  while not state.max_requests or state.handled < state.max_requests do
    local client = tcp:accept()
    if client then
      handle_client(app, client, options, state)
    end
  end

  tcp:close()
  return true
end

return server
