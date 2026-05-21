require("spec.spec_helper")

local json = require("orbit.json")

describe("orbit.json", function()
  it("encodes and decodes nested values", function()
    local raw = json.encode({
      name = "Orbit",
      items = { 1, 2, true },
      meta = {
        stable = false,
      },
    })

    local decoded = json.decode(raw)

    assert.equal("Orbit", decoded.name)
    assert.same({ 1, 2, true }, decoded.items)
    assert.is_false(decoded.meta.stable)
  end)

  it("escapes strings", function()
    local raw = json.encode({ text = 'line\nquote"' })

    assert.equal('{"text":"line\\nquote\\""}', raw)
    assert.equal('line\nquote"', json.decode(raw).text)
  end)

  it("rejects recursive tables", function()
    local value = {}
    value.self = value

    assert.has_error(function()
      json.encode(value)
    end)
  end)
end)
