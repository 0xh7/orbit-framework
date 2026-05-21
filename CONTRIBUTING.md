# Contributing

Orbit is kept small on purpose. Changes should make the framework easier to run,
easier to reason about, or safer at the HTTP boundary.

## Development

Install the local tools:

```sh
make install-deps
```

Run the checks before opening a change:

```sh
make rock
make lint
make test
make format-check
```

## Style

- Keep runtime dependencies limited to LuaSocket unless a change is discussed first.
- Prefer plain Lua modules with small public APIs.
- Add tests for routing, middleware, request parsing, response serialization, and CLI
  behavior when those areas change.
- Keep documentation direct and accurate. Do not document future behavior as if it
  already exists.
