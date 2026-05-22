require("spec.spec_helper")

local cli = require("orbit.cli")

describe("orbit.cli", function()
  it("prints the framework version", function()
    local output = {}

    local ok, err = pcall(cli.run, { "version" }, function(value)
      table.insert(output, value)
    end)
    assert.is_true(ok, err)
    assert.equal("0.2.1\n", table.concat(output))
  end)

  it("rejects unsafe project names", function()
    assert.has_error(function()
      cli.new_project("bad;name")
    end)
  end)
end)
