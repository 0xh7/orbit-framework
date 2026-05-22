# Security

Orbit is an early HTTP framework. Treat the standalone server as a plain HTTP/1.1
server for trusted deployments behind a mature TLS terminator or reverse proxy.

Please do not open public issues for vulnerabilities. Use GitHub's private
vulnerability reporting if it is available for the repository, or contact the
maintainer privately before publishing details.

## Current Boundaries

- TLS is not implemented.
- HTTP/2 is not implemented.
- WebSockets are not implemented.
- Chunked request bodies are rejected.
- Request size limits are enforced before handlers run.
