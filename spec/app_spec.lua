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

  it("sets cookies and redirects", function()
    local app = orbit.new()

    app:get("/login", function(ctx)
      ctx:cookie("session", "abc 123", {
        path = "/",
        http_only = true,
        same_site = "Lax",
      })

      return ctx:redirect("/dashboard")
    end)

    local res = app:handle({ method = "GET", target = "/login" })
    local headers = res:headers_list()
    local cookie

    for _, header in ipairs(headers) do
      if header[1] == "Set-Cookie" then
        cookie = header[2]
      end
    end

    assert.equal(302, res.status_code)
    assert.equal("/dashboard", res:get_header("location"))
    assert.equal("", res.body)
    assert.equal("session=abc%20123; Path=/; SameSite=Lax; HttpOnly", cookie)
  end)

  it("clears cookies with an expired Set-Cookie header", function()
    local app = orbit.new()

    app:get("/logout", function(ctx)
      ctx:clear_cookie("session", { path = "/" })
      return ctx:text("bye")
    end)

    local res = app:handle({ method = "GET", target = "/logout" })
    local cookie

    for _, header in ipairs(res:headers_list()) do
      if header[1] == "Set-Cookie" then
        cookie = header[2]
      end
    end

    assert.equal(200, res.status_code)
    assert.equal("session=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=0", cookie)
  end)

  it("reads cookies from the request", function()
    local app = orbit.new()

    app:get("/me", function(ctx)
      return ctx:json({ session = ctx.req:cookie("session") })
    end)

    local res = app:handle({
      method = "GET",
      target = "/me",
      headers = {
        Cookie = "theme=dark; session=abc%20123",
      },
    })

    assert.equal("abc 123", json.decode(res.body).session)
  end)

  it("rejects unsafe response header values", function()
    local app = orbit.new()

    app:get("/", function(ctx)
      return ctx:set("X-Test", "ok\r\nX-Injected: true"):text("bad")
    end)

    local res = app:handle({ method = "GET", target = "/" })

    assert.equal(500, res.status_code)
    assert.equal("Internal Server Error", res.body)
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
