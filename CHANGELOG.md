# Changelog

## v1.0.4

  * Update docs.

## v1.0.3

  * Correct License notice in README.md.

## v1.0.2

  * Support Elixir 1.17-20 and Erlang/OTP 27 and 28.

## v1.0.1

  * Support Elixir 1.18-20 and Erlang/OTP 28.

## v1.0.0

  * Initial release.
  * Add `DockerAvailability.executable/0` for locating the Docker CLI executable in `PATH`.
  * Add `DockerAvailability.available?/0` as a boolean convenience check for Docker usability.
  * Add `DockerAvailability.check/0` for collecting Docker executable, client version, and server version diagnostics.
  * Add unit tests using a fake `docker` executable so the test suite does not require a running Docker daemon or Docker images.