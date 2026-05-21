require("spec.spec_helper")

local router = require("orbit.router")

describe("orbit.router", function()
  it("matches method and path params", function()
    local r = router.new()
    local handler = function() end

    r:add("GET", "/users/:id", handler)

    local route, params = r:match("GET", "/users/42")

    assert.equal(handler, route.handler)
    assert.equal("42", params.id)
  end)

  it("decodes params and supports HEAD fallback to GET", function()
    local r = router.new()
    local handler = function() end

    r:add("GET", "/files/:name", handler)

    local route, params = r:match("HEAD", "/files/hello%20world")

    assert.equal(handler, route.handler)
    assert.equal("hello world", params.name)
  end)

  it("supports wildcard params", function()
    local r = router.new()

    r:add("GET", "/assets/*path", function() end)

    local route, params = r:match("GET", "/assets/css/app.css")

    assert.is_not_nil(route)
    assert.equal("css/app.css", params.path)
  end)
end)
