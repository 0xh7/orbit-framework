# Security

Orbit is an early HTTP framework. Treat the standalone server as a plain HTTP/1.1
server for trusted deployments behind a mature TLS terminator or reverse proxy.

Please report security issues privately to the project maintainer once the public
repository is created. Until then, do not publish exploit details in an issue tracker.

## Current Boundaries

- TLS is not implemented.
- HTTP/2 is not implemented.
- WebSockets are not implemented.
- Chunked request bodies are rejected.
- Request size limits are enforced before handlers run.
