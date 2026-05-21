local orbit = require("orbit")

local app = orbit.new()

app:use(function(ctx, next)
  ctx:set("X-Powered-By", "Orbit")
  return next()
end)

app:get("/", function(ctx)
  return ctx:json({ service = "orbit-example", status = "ok" })
end)

app:get("/users/:id", function(ctx)
  return ctx:json({
    id = ctx.params.id,
    query = ctx.query,
  })
end)

app:post("/echo", function(ctx)
  return ctx:json(ctx.req:json())
end)

return app
