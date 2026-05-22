require("spec.spec_helper")

local orbit = require("orbit")

describe("orbit.static", function()
  it("serves files from a mounted directory", function()
    local app = orbit.new()

    app:static("/assets", "spec/fixtures/public", {
      cache_control = "public, max-age=60",
    })

    local res = app:handle({ method = "GET", target = "/assets/app.css" })

    assert.equal(200, res.status_code)
    assert.equal("text/css; charset=utf-8", res:get_header("content-type"))
    assert.equal("public, max-age=60", res:get_header("cache-control"))
    assert.truthy(res.body:find("body", 1, true))
  end)

  it("serves index files", function()
    local app = orbit.new()

    app:static("/", "spec/fixtures/public")

    local res = app:handle({ method = "GET", target = "/" })

    assert.equal(200, res.status_code)
    assert.equal("text/html; charset=utf-8", res:get_header("content-type"))
    assert.truthy(res.body:find("Orbit static fixture", 1, true))
  end)

  it("falls through when a file is missing", function()
    local app = orbit.new()

    app:static("/assets", "spec/fixtures/public")
    app:get("/assets/missing.css", function(ctx)
      return ctx:text("fallback")
    end)

    local res = app:handle({ method = "GET", target = "/assets/missing.css" })

    assert.equal(200, res.status_code)
    assert.equal("fallback", res.body)
  end)

  it("rejects path traversal", function()
    local app = orbit.new()

    app:static("/assets", "spec/fixtures/public")

    local res = app:handle({ method = "GET", target = "/assets/%2e%2e/secret.txt" })

    assert.equal(403, res.status_code)
    assert.equal("Forbidden", res.body)
  end)
end)
