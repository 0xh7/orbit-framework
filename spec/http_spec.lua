require("spec.spec_helper")

local http = require("orbit.http")
local response = require("orbit.response")

describe("orbit.http", function()
  it("parses request line, headers, query, and keep-alive", function()
    local req = assert(
      http.parse_request_string(
        "GET /hello?name=Ada+Lovelace HTTP/1.1\r\nHost: example.test\r\n\r\n"
      )
    )

    assert.equal("GET", req.method)
    assert.equal("/hello", req.path)
    assert.equal("Ada Lovelace", req.query.name)
    assert.equal("example.test", req:header("host"))
    assert.is_true(req.keep_alive)
  end)

  it("parses request body", function()
    local req = assert(
      http.parse_request_string(
        "POST /echo HTTP/1.1\r\nHost: local\r\nContent-Length: 11\r\n\r\nhello world"
      )
    )

    assert.equal("POST", req.method)
    assert.equal("hello world", req.body)
  end)

  it("rejects malformed requests", function()
    local req, err = http.parse_request_string("wat\r\n\r\n")

    assert.is_nil(req)
    assert.equal(400, err.status_code)
  end)

  it("requires Host on HTTP/1.1", function()
    local req, err = http.parse_request_string("GET / HTTP/1.1\r\n\r\n")

    assert.is_nil(req)
    assert.equal(400, err.status_code)
    assert.equal("Host header required", err.body)
  end)

  it("rejects invalid header names", function()
    local req, err =
      http.parse_request_string("GET / HTTP/1.1\r\nHost: local\r\nBad Header: no\r\n\r\n")

    assert.is_nil(req)
    assert.equal(400, err.status_code)
    assert.equal("Malformed header", err.body)
  end)

  it("rejects unsupported HTTP versions", function()
    local req, err = http.parse_request_string("GET / HTTP/2.0\r\nHost: local\r\n\r\n")

    assert.is_nil(req)
    assert.equal(400, err.status_code)
    assert.equal("Unsupported HTTP Version", err.body)
  end)

  it("rejects bodies over the configured limit", function()
    local req, err = http.parse_request_string(
      "POST / HTTP/1.1\r\nHost: local\r\nContent-Length: 5\r\n\r\nhello",
      { max_body_size = 4 }
    )

    assert.is_nil(req)
    assert.equal(413, err.status_code)
  end)

  it("rejects unsupported transfer encoding", function()
    local req, err = http.parse_request_string(
      "POST / HTTP/1.1\r\nHost: local\r\nTransfer-Encoding: chunked\r\n\r\n"
    )

    assert.is_nil(req)
    assert.equal(400, err.status_code)
  end)

  it("serializes responses", function()
    local res = response.new(201):type("text/plain"):send("created")
    local raw = http.serialize_response(res, false)

    assert.truthy(raw:find("HTTP/1.1 201 Created", 1, true))
    assert.truthy(raw:find("Content-Length: 7", 1, true))
    assert.truthy(raw:find("\r\n\r\ncreated", 1, true))
  end)

  it("forces Connection close when keep-alive is disabled", function()
    local res = response.new(200):header("Connection", "keep-alive"):send("ok")
    local raw = http.serialize_response(res, false)

    assert.truthy(raw:find("Connection: close", 1, true))
  end)
end)
