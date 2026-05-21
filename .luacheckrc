std = "lua51"
codes = true
max_line_length = false

globals = {
  "describe",
  "it",
  "before_each",
  "after_each",
}

files["bin/orbit"] = {
  globals = { "arg" },
}
