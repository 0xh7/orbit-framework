# Getting Started

## Create an App

```lua
local orbit = require("orbit")

local app = orbit.new()

app:get("/", function(ctx)
  return ctx:json({ service = "users", status = "ok" })
end)

return app
```

Run it:

```sh
orbit serve app.lua
```

## Middleware

Middleware receives `ctx` and `next`.

```lua
app:use(function(ctx, next)
  ctx.state.started_at = os.clock()
  local res = next()
  ctx:set("X-Elapsed", tostring(os.clock() - ctx.state.started_at))
  return res
end)
```

Middleware can stop the chain by returning a response:

```lua
app:use("/admin", function(ctx)
  return ctx:status(401):json({ error = "missing credentials" })
end)
```

## Routes

Route params use `:name` segments.

```lua
app:get("/users/:id", function(ctx)
  return ctx:json({ id = ctx.params.id })
end)
```

Wildcard params use `*name`.

```lua
app:get("/assets/*path", function(ctx)
  return ctx:text(ctx.params.path)
end)
```

## Request Data

```lua
app:post("/echo", function(ctx)
  local body = ctx.req:json()
  return ctx:json(body)
end)
```

Query parameters are available on `ctx.query`.

Cookies are parsed lazily from the `Cookie` header.

```lua
app:get("/me", function(ctx)
  return ctx:json({ session = ctx.req:cookie("session") })
end)
```

## Responses

```lua
app:post("/login", function(ctx)
  ctx:cookie("session", "abc123", {
    path = "/",
    http_only = true,
    same_site = "Lax",
  })

  return ctx:redirect("/dashboard")
end)

app:post("/logout", function(ctx)
  ctx:clear_cookie("session", { path = "/" })
  return ctx:text("signed out")
end)
```

## Static Files

```lua
app:static("/assets", "public", {
  cache_control = "public, max-age=3600",
})
```

Orbit serves static files for `GET` and `HEAD`, rejects path traversal, and uses a
small built-in content-type table for common web assets.

## HTTP Server Limits

The standalone server supports plain HTTP/1.1 over LuaSocket. Defaults:

- max request body: `1 MiB`
- max header bytes: `32 KiB`
- max line size: `8 KiB`
- client timeout: `10s`

Override them through `app:listen`.

```lua
app:listen({
  host = "127.0.0.1",
  port = 8080,
  max_body_size = 2 * 1024 * 1024,
})
```
