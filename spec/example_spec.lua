require("spec.spec_helper")

local json = require("orbit.json")

describe("examples", function()
  it("boots the hello app", function()
    local app = assert(loadfile("examples/hello.lua"))()
    local res = app:handle({ method = "GET", target = "/" })

    assert.equal(200, res.status_code)
    local body = json.decode(res.body)

    assert.equal("orbit-example", body.service)
    assert.equal("ok", body.status)
  end)
end)
