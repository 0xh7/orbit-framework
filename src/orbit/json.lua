local json = {}

json.null = {}

local escape_map = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function encode_string(value)
  return '"'
    .. value:gsub('[%z\1-\31\\"]', function(char)
      return escape_map[char] or string.format("\\u%04x", string.byte(char))
    end)
    .. '"'
end

local function is_array(value)
  local count = 0
  local max = 0

  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false, 0
    end

    count = count + 1
    if key > max then
      max = key
    end
  end

  if count == 0 then
    return false, 0
  end

  return count == max, max
end

local encode_value

local function encode_table(value, seen)
  if seen[value] then
    error("cannot encode recursive table as JSON", 3)
  end

  seen[value] = true

  local array, max = is_array(value)
  local chunks = {}

  if array then
    for index = 1, max do
      chunks[index] = encode_value(value[index], seen)
    end

    seen[value] = nil
    return "[" .. table.concat(chunks, ",") .. "]"
  end

  for key, item in pairs(value) do
    if type(key) ~= "string" and type(key) ~= "number" then
      error("JSON object keys must be strings or numbers", 3)
    end

    table.insert(chunks, encode_string(tostring(key)) .. ":" .. encode_value(item, seen))
  end

  table.sort(chunks)
  seen[value] = nil
  return "{" .. table.concat(chunks, ",") .. "}"
end

encode_value = function(value, seen)
  local kind = type(value)

  if value == json.null or kind == "nil" then
    return "null"
  elseif kind == "boolean" then
    return value and "true" or "false"
  elseif kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("cannot encode non-finite number as JSON", 3)
    end

    return tostring(value)
  elseif kind == "string" then
    return encode_string(value)
  elseif kind == "table" then
    return encode_table(value, seen)
  end

  error("cannot encode " .. kind .. " as JSON", 3)
end

function json.encode(value)
  return encode_value(value, {})
end

local function utf8_char(codepoint)
  if codepoint <= 0x7f then
    return string.char(codepoint)
  elseif codepoint <= 0x7ff then
    local byte1 = 0xc0 + math.floor(codepoint / 0x40)
    local byte2 = 0x80 + (codepoint % 0x40)
    return string.char(byte1, byte2)
  elseif codepoint <= 0xffff then
    local byte1 = 0xe0 + math.floor(codepoint / 0x1000)
    local byte2 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
    local byte3 = 0x80 + (codepoint % 0x40)
    return string.char(byte1, byte2, byte3)
  elseif codepoint <= 0x10ffff then
    local byte1 = 0xf0 + math.floor(codepoint / 0x40000)
    local byte2 = 0x80 + (math.floor(codepoint / 0x1000) % 0x40)
    local byte3 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
    local byte4 = 0x80 + (codepoint % 0x40)
    return string.char(byte1, byte2, byte3, byte4)
  end

  error("invalid unicode codepoint")
end

local Parser = {}
Parser.__index = Parser

function Parser:error(message)
  error(message .. " at byte " .. self.pos, 0)
end

function Parser:peek()
  return self.source:sub(self.pos, self.pos)
end

function Parser:next()
  local char = self.source:sub(self.pos, self.pos)
  self.pos = self.pos + 1
  return char
end

function Parser:skip_space()
  local _, stop = self.source:find("^[ \n\r\t]*", self.pos)
  self.pos = (stop or self.pos - 1) + 1
end

function Parser:consume(text)
  if self.source:sub(self.pos, self.pos + #text - 1) ~= text then
    self:error("expected " .. text)
  end

  self.pos = self.pos + #text
end

function Parser:parse_unicode_escape()
  local hex = self.source:sub(self.pos, self.pos + 3)
  if not hex:match("^%x%x%x%x$") then
    self:error("invalid unicode escape")
  end

  self.pos = self.pos + 4
  local codepoint = tonumber(hex, 16)

  if codepoint >= 0xd800 and codepoint <= 0xdbff then
    if self.source:sub(self.pos, self.pos + 1) ~= "\\u" then
      self:error("expected low surrogate")
    end

    self.pos = self.pos + 2
    local low_hex = self.source:sub(self.pos, self.pos + 3)
    if not low_hex:match("^%x%x%x%x$") then
      self:error("invalid low surrogate")
    end

    self.pos = self.pos + 4
    local low = tonumber(low_hex, 16)
    if low < 0xdc00 or low > 0xdfff then
      self:error("invalid low surrogate")
    end

    codepoint = 0x10000 + ((codepoint - 0xd800) * 0x400) + (low - 0xdc00)
  elseif codepoint >= 0xdc00 and codepoint <= 0xdfff then
    self:error("unexpected low surrogate")
  end

  return utf8_char(codepoint)
end

function Parser:parse_string()
  self:consume('"')

  local chunks = {}

  while self.pos <= #self.source do
    local char = self:next()

    if char == '"' then
      return table.concat(chunks)
    elseif char == "\\" then
      local escaped = self:next()
      if escaped == '"' or escaped == "\\" or escaped == "/" then
        table.insert(chunks, escaped)
      elseif escaped == "b" then
        table.insert(chunks, "\b")
      elseif escaped == "f" then
        table.insert(chunks, "\f")
      elseif escaped == "n" then
        table.insert(chunks, "\n")
      elseif escaped == "r" then
        table.insert(chunks, "\r")
      elseif escaped == "t" then
        table.insert(chunks, "\t")
      elseif escaped == "u" then
        table.insert(chunks, self:parse_unicode_escape())
      else
        self:error("invalid escape")
      end
    else
      if string.byte(char) < 32 then
        self:error("control character in string")
      end

      table.insert(chunks, char)
    end
  end

  self:error("unterminated string")
end

function Parser:parse_number()
  local start = self.pos

  if self:peek() == "-" then
    self.pos = self.pos + 1
  end

  local first = self:peek()
  if first == "0" then
    self.pos = self.pos + 1
  elseif first:match("[1-9]") then
    repeat
      self.pos = self.pos + 1
    until not self:peek():match("%d")
  else
    self:error("invalid number")
  end

  if self:peek() == "." then
    self.pos = self.pos + 1
    if not self:peek():match("%d") then
      self:error("invalid number")
    end

    repeat
      self.pos = self.pos + 1
    until not self:peek():match("%d")
  end

  local exponent = self:peek()
  if exponent == "e" or exponent == "E" then
    self.pos = self.pos + 1

    local sign = self:peek()
    if sign == "+" or sign == "-" then
      self.pos = self.pos + 1
    end

    if not self:peek():match("%d") then
      self:error("invalid number")
    end

    repeat
      self.pos = self.pos + 1
    until not self:peek():match("%d")
  end

  local raw = self.source:sub(start, self.pos - 1)
  local value = tonumber(raw)
  if not value then
    self:error("invalid number")
  end

  return value
end

function Parser:parse_array()
  self:consume("[")
  self:skip_space()

  local result = {}
  if self:peek() == "]" then
    self.pos = self.pos + 1
    return result
  end

  while true do
    table.insert(result, self:parse_value())
    self:skip_space()

    local char = self:next()
    if char == "]" then
      return result
    elseif char ~= "," then
      self:error("expected comma or closing bracket")
    end

    self:skip_space()
  end
end

function Parser:parse_object()
  self:consume("{")
  self:skip_space()

  local result = {}
  if self:peek() == "}" then
    self.pos = self.pos + 1
    return result
  end

  while true do
    if self:peek() ~= '"' then
      self:error("expected object key")
    end

    local key = self:parse_string()
    self:skip_space()
    self:consume(":")
    result[key] = self:parse_value()
    self:skip_space()

    local char = self:next()
    if char == "}" then
      return result
    elseif char ~= "," then
      self:error("expected comma or closing brace")
    end

    self:skip_space()
  end
end

function Parser:parse_value()
  self:skip_space()

  local char = self:peek()
  if char == '"' then
    return self:parse_string()
  elseif char == "{" then
    return self:parse_object()
  elseif char == "[" then
    return self:parse_array()
  elseif char == "t" then
    self:consume("true")
    return true
  elseif char == "f" then
    self:consume("false")
    return false
  elseif char == "n" then
    self:consume("null")
    return json.null
  elseif char == "-" or char:match("%d") then
    return self:parse_number()
  end

  self:error("unexpected token")
end

function json.decode(source)
  if type(source) ~= "string" then
    error("JSON source must be a string", 2)
  end

  local parser = setmetatable({ source = source, pos = 1 }, Parser)
  local value = parser:parse_value()
  parser:skip_space()

  if parser.pos <= #source then
    parser:error("trailing data")
  end

  return value
end

return json
