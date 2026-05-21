require("spec.spec_helper")

local orbit = require("orbit")
local json = require("orbit.json")

describe("orbit.app", function()
  it("handles routes with params and query", function()
    local app = orbit.new()

    app:get("/users/:id", function(ctx)
      return ctx:json({
        id = ctx.params.id,
        search = ctx.query.q,
      })
    end)

    local res = app:handle({
      method = "GET",
      target = "/users/42?q=lua",
    })

    local body = json.decode(res.body)

    assert.equal(200, res.status_code)
    assert.equal("42", body.id)
    assert.equal("lua", body.search)
    assert.equal("application/json; charset=utf-8", res:get_header("content-type"))
  end)

  it("runs middleware in order and allows after-next work", function()
    local app = orbit.new()
    local seen = {}

    app:use(function(ctx, next)
      table.insert(seen, "before")
      local res = next()
      table.insert(seen, "after")
      ctx:set("X-Test", "done")
      return res
    end)

    app:get("/", function(ctx)
      table.insert(seen, "handler")
      return ctx:text("ok")
    end)

    local res = app:handle({ method = "GET", target = "/" })

    assert.same({ "before", "handler", "after" }, seen)
    assert.equal("done", res:get_header("x-test"))
    assert.equal("ok", res.body)
  end)

  it("allows middleware to short-circuit", function()
    local app = orbit.new()

    app:use(function(ctx)
      return ctx:status(401):json({ error = "unauthorized" })
    end)

    app:get("/", function(ctx)
      return ctx:text("should not run")
    end)

    local res = app:handle({ method = "GET", target = "/" })

    assert.equal(401, res.status_code)
    assert.equal("unauthorized", json.decode(res.body).error)
  end)

  it("returns 404 by default", function()
    local app = orbit.new()

    local res = app:handle({ method = "GET", target = "/missing" })

    assert.equal(404, res.status_code)
    assert.equal("Not Found", res.body)
  end)

  it("returns 405 when the path exists for another method", function()
    local app = orbit.new()

    app:get("/users/:id", function(ctx)
      return ctx:text(ctx.params.id)
    end)

    local res = app:handle({ method = "POST", target = "/users/42" })

    assert.equal(405, res.status_code)
    assert.equal("GET, HEAD", res:get_header("allow"))
    assert.equal("Method Not Allowed", res.body)
  end)

  it("returns 500 for unhandled errors", function()
    local app = orbit.new()

    app:get("/", function()
      error("boom")
    end)

    local res = app:handle({ method = "GET", target = "/" })

    assert.equal(500, res.status_code)
    assert.equal("Internal Server Error", res.body)
  end)
end)
