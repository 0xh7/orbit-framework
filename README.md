# Orbit

[![CI](https://github.com/0xh7/orbit-framework/actions/workflows/ci.yml/badge.svg)](https://github.com/0xh7/orbit-framework/actions/workflows/ci.yml)

Orbit is a from-scratch backend framework for Lua. It provides an Express-like API,
middleware, routing, request/response helpers, cookies, redirects, static files,
JSON, and a small HTTP/1.1 server implemented over raw TCP with LuaSocket.

The package name is `orbit-framework`; applications load it with `require("orbit")`.

## Status

This is an early v1 implementation. It intentionally supports HTTP/1.1 only and does
not include TLS, HTTP/2, WebSockets, chunked transfer decoding, sessions, auth, or a
database layer.

## LuaRocks

Orbit is prepared for LuaRocks publication. After the LuaRocks upload is complete,
the package will be installable with `luarocks install orbit-framework`.

For local development:

```sh
luarocks make orbit-framework-dev-1.rockspec
```

The development rockspec identifies this repository as its source. `luarocks make`
still builds from the current checkout, which is the right command while working
locally.

On Homebrew systems where `lua` points at Lua 5.5, use the Lua 5.4 keg explicitly:

```sh
luarocks --lua-version=5.4 --lua-dir=/opt/homebrew/opt/lua@5.4 make orbit-framework-dev-1.rockspec
```

For development tools, the Makefile installs rocks into `./.luarocks`:

```sh
make install-deps
make rock
make lint
make test
```

## Example

```lua
local orbit = require("orbit")

local app = orbit.new()

app:use(function(ctx, next)
  ctx:set("X-Powered-By", "Orbit")
  return next()
end)

app:get("/users/:id", function(ctx)
  return ctx:json({
    id = ctx.params.id,
    role = "member",
  })
end)

app:listen({ host = "127.0.0.1", port = 8080 })
```

Run the example app:

```sh
orbit serve examples/hello.lua --host 127.0.0.1 --port 8080
```

## API

- `orbit.new(options)` creates an app.
- `app:use([path], middleware)` registers middleware.
- `app:static(path, root, options)` serves files from a local directory.
- `app:get/post/put/patch/delete/options/head/all(path, handler)` registers routes.
- `app:on_error(handler)` overrides the default `500` response.
- `app:handle(request)` handles an in-memory request table.
- `app:listen(options)` starts the LuaSocket standalone server.

Handlers receive `ctx`, which exposes:

- `ctx.req`, `ctx.request`
- `ctx.res`, `ctx.response`
- `ctx.params`
- `ctx.query`
- `ctx.state`
- `ctx:status(code)`
- `ctx:set(name, value)`
- `ctx:cookie(name, value, options)`
- `ctx:clear_cookie(name, options)`
- `ctx:redirect(location, status_code)`
- `ctx:text(body)`
- `ctx:html(body)`
- `ctx:json(value)`
- `ctx:send(body)`

Requests expose `ctx.req:header(name)`, `ctx.req:cookie(name)`, `ctx.req:cookies()`,
`ctx.req:json()`, and `ctx.req:form()`.

Static file serving is intentionally small. It supports `GET` and `HEAD`, simple
content-type detection, optional `Cache-Control`, index files, and path traversal
rejection.

`orbit.json.decode` represents JSON `null` as `orbit.json.null` so arrays and object
fields can preserve explicit null values.

## HTTP Server

The standalone server is plain HTTP/1.1 over LuaSocket. It validates request methods,
header names, request targets, HTTP versions, `Host` on HTTP/1.1, content length, and
body limits before the request reaches the app.

`app:listen` accepts:

- `host`, default `127.0.0.1`
- `port`, default `8080`
- `backlog`, default `128`
- `client_timeout`, default `10`
- `max_body_size`, default `1048576`
- `max_requests`, useful for tests and short-lived servers
- `silent`, disables the startup line

## Compatibility

Orbit targets Lua `5.1`, `5.2`, `5.3`, `5.4`, and LuaJIT. Lua `5.5` is not part of the
v1 support matrix yet.

Runtime dependencies:

- `luasocket >= 3.0`

Development dependencies:

- `busted`
- `luacheck`
- `stylua`

## Tests

```sh
make install-deps
make rock
make lint
make test
make format-check
```

## Release

Release rockspecs use the matching Git tag as their source. For `0.2.0`, the
release rockspec is `orbit-framework-0.2.0-1.rockspec`.

## License

Apache-2.0
