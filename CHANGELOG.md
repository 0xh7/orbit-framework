# Changelog

## 0.2.1 - 2026-05-22

Fixed static file edge cases found during release review.

- Normalized trailing slashes in `app:static` mount paths.
- Changed directory read failures in static middleware to fall through instead of
  returning `500`.
- Added tests for trailing-slash static mounts and nested directory handling.

## 0.2.0 - 2026-05-22

Added practical response and file-serving helpers for Lua services.

- Added response cookies, cookie clearing, and request cookie parsing.
- Added redirects through `ctx:redirect`.
- Added static file middleware through `app:static`.
- Added repeated response header support for headers such as `Set-Cookie`.
- Added response header value validation to reject CR/LF injection.
- Added tests for cookies, redirects, static files, and repeated headers.

## 0.1.0 - 2026-05-22

Initial public release.

- Added the Orbit app, router, middleware, request, and response APIs.
- Added a plain HTTP/1.1 server over LuaSocket.
- Added route params, query parsing, response helpers, and JSON support.
- Added CLI commands for serving apps, creating a small project, and printing the
  framework version.
- Added tests for Lua 5.1, 5.2, 5.3, 5.4, and a LuaJIT smoke path.
