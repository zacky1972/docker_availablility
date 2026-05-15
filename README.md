# DockerAvailability

`DockerAvailability` is a small Elixir library for checking whether Docker is installed and usable from the current host process.

It checks more than the presence of the `docker` command. A host may have the Docker CLI installed while the Docker daemon is stopped, unreachable, or inaccessible to the current user. `DockerAvailability` probes both the Docker client and the Docker server so callers can fail early with clear diagnostics.

## Installation

When the package is published to Hex, add `docker_availability` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:docker_availability, "~> 1.0.0"}
  ]
end
```

During development, you can also depend on this repository directly:

```elixir
def deps do
  [
    {:docker_availability, github: "zacky1972/docker_availability", branch: "main"}
  ]
end
```

Then fetch dependencies:

```sh
mix deps.get
```

## Which function should I use?

| Need | Use | Result |
| --- | --- | --- |
| A simple yes/no answer | `DockerAvailability.available?/0` | `true` or `false` |
| The resolved Docker CLI path | `DockerAvailability.executable/0` | `{:ok, path}` or `{:error, :docker_not_found}` |
| Diagnostics, version information, or structured error handling | `DockerAvailability.check/0` | `{:ok, info}` or `{:error, reason}` |

Use `available?/0` when a boolean is enough, for example when deciding whether to skip Docker-dependent work.

Use `executable/0` when you only need to know whether the Docker CLI is installed and where it is located. This function does not check whether the Docker daemon is running or reachable.

Use `check/0` when the caller needs diagnostic details, Docker client and server version information, or structured error handling.

## Usage

Use `available?/0` when you only need a boolean answer:

```elixir
if DockerAvailability.available?() do
  IO.puts("Docker is available")
else
  IO.puts("Docker is not available")
end
```

Use `executable/0` when you only need to know whether the `docker` executable exists in `PATH`:

```elixir
DockerAvailability.executable()
#=> {:ok, "/usr/bin/docker"}

DockerAvailability.executable()
#=> {:error, :docker_not_found}
```

Use `check/0` when you need diagnostic details:

```elixir
case DockerAvailability.check() do
  {:ok, info} ->
    IO.puts("Docker executable: #{info.executable}")
    IO.puts("Docker client: #{info.client_version}")
    IO.puts("Docker server: #{info.server_version}")

  {:error, :docker_not_found} ->
    IO.puts("The docker executable was not found in PATH")

  {:error, {:docker_command_failed, status, output}} ->
    IO.puts("Docker client command failed with status #{status}")
    IO.puts(output)

  {:error, {:docker_unavailable, status, output}} ->
    IO.puts("Docker daemon is not available with status #{status}")
    IO.puts(output)
end
```

## API

### `DockerAvailability.executable/0`

Returns the path to the `docker` executable.

It only checks the current process `PATH` by using `System.find_executable/1`. It does not check whether the Docker daemon is running.

Return values:

```elixir
{:ok, "/usr/bin/docker"}
{:error, :docker_not_found}
```

`{:ok, path}` means the executable was found. `path` is the resolved path returned by the current process environment.

`{:error, :docker_not_found}` means no `docker` executable was available in `PATH`.

### `DockerAvailability.available?/0`

Returns `true` when Docker is installed and usable by the current process. This is a convenience wrapper around `check/0`.

Return values:

```elixir
true
false
```

It returns `false` for all error cases, including a missing executable, a failed Docker client command, or an unreachable Docker daemon.

Use `check/0` instead when the caller needs to know why Docker is not available.

### `DockerAvailability.check/0`

Performs the full availability check. It verifies that:

1. the `docker` executable exists in `PATH`
2. the Docker client version can be queried
3. the Docker server version can be queried

Returns `{:ok, info}` when Docker is usable:

```elixir
{:ok,
 %{
   executable: "/usr/bin/docker",
   client_version: "24.0.0",
   server_version: "24.0.0"
 }}
```

The `info` map contains:

| Field | Meaning |
| --- | --- |
| `:executable` | The resolved path to the Docker executable. |
| `:client_version` | The Docker client version reported by the executable. |
| `:server_version` | The Docker server version reported by the daemon. |

The version fields are intended to be strings returned by Docker version commands.

Returns one of the following errors:

```elixir
{:error, :docker_not_found}
{:error, {:docker_command_failed, status, output}}
{:error, {:docker_unavailable, status, output}}
```

| Error | Meaning |
| --- | --- |
| `:docker_not_found` | No `docker` executable could be found in `PATH`. |
| `{:docker_command_failed, status, output}` | The Docker executable was found, but a Docker command failed while retrieving client information. |
| `{:docker_unavailable, status, output}` | The Docker client exists, but the Docker server or daemon is stopped, unreachable, or inaccessible to the current user. |

`status` is the Docker command exit status. `output` is the trimmed combined standard output and standard error from the Docker command.

## What this library does not do

`DockerAvailability` is a probe only. It does not:

- install Docker
- start or stop the Docker daemon
- pull, build, run, or remove Docker images or containers
- modify Docker state
- require a specific Docker image

## Examples

A common use case is to skip Docker-dependent work when Docker is not available:

```elixir
case DockerAvailability.check() do
  {:ok, _info} ->
    run_docker_dependent_work()

  {:error, reason} ->
    {:skip, {:docker_unavailable, reason}}
end
```

For test suites, `available?/0` can be used to guard integration tests:

```elixir
setup_all do
  unless DockerAvailability.available?() do
    ExUnit.configure(exclude: [:docker])
  end

  :ok
end
```

## Testing

Run the test suite with:

```sh
mix test
```

The unit tests use a fake `docker` executable placed in a temporary `PATH`, so they do not require a real Docker daemon or any Docker image.

## Development

Fetch dependencies:

```sh
mix deps.get
```

Run tests:

```sh
mix test
```

Run the project checks:

```sh
mix check
```

`mix check` validates the project from a contributor-facing perspective. It runs dependency auditing, compilation with warnings treated as errors, formatting checks, static analysis, dependency-lock validation, spelling checks, and Dialyzer.

Run the maintainer pre-commit checks before opening a pull request:

```sh
mix precommit
```

`mix precommit` runs the maintainer workflow, including formatting, static checks, and tests. Contributors should run this command before submitting changes when the full toolchain is available locally.

## Documentation

Generate documentation locally with:

```sh
mix docs
```

The README is the primary user-facing guide and is included in the generated documentation. Keep the README and module documentation in sync when changing public API behavior, examples, or error descriptions.

After the package is published, documentation should be available on HexDocs.

## Requirements

- Elixir `~> 1.17`
- Docker CLI and daemon, when checking real Docker availability at runtime

## License

Copyright (c) 2026 University of Kitakyushu

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>.

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
