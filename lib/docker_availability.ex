defmodule DockerAvailability do
  @moduledoc """
  Detects whether Docker is installed and usable on the host system.

  This module provides a small probe for Docker availability. It checks both
  the Docker client executable and the Docker daemon because a host may have
  the `docker` command installed while the daemon is stopped, unreachable, or
  inaccessible to the current user.

  ## Which function should I use?

    * Use `available?/0` when the caller only needs a boolean yes/no answer.
    * Use `executable/0` when the caller needs to know whether the Docker CLI
      is installed and where it is located.
    * Use `check/0` when the caller needs diagnostics, version information, or
      structured error handling.

  ## Return shapes

  `executable/0` returns either:

      {:ok, "/usr/bin/docker"}
      {:error, :docker_not_found}

  `available?/0` returns either:

      true
      false

  `check/0` returns either:

      {:ok,
       %{
         executable: "/usr/bin/docker",
         client_version: "24.0.0",
         server_version: "24.0.0"
       }}

  or one of these error tuples:

      {:error, :docker_not_found}
      {:error, {:docker_command_failed, status, output}}
      {:error, {:docker_unavailable, status, output}}

  ## Error reasons

    * `:docker_not_found` means no `docker` executable could be found in `PATH`.
    * `{:docker_command_failed, status, output}` means the Docker executable was
      found, but a Docker command failed while retrieving client information.
    * `{:docker_unavailable, status, output}` means the Docker client exists,
      but the Docker server or daemon is stopped, unreachable, or inaccessible
      to the current user.

  `status` is the Docker command exit status. `output` is the trimmed combined
  standard output and standard error from the Docker command.

  The functions in this module do not install Docker, start the Docker daemon,
  or modify Docker state.
  """

  @typedoc """
  Result returned by `check/0`.

  Successful results contain the resolved Docker executable path and the client
  and server version values reported by Docker. Error results contain one of the
  documented Docker availability reasons.
  """
  @type check_result ::
          {:ok,
           %{
             executable: Path.t(),
             client_version: String.t() | nil,
             server_version: String.t() | nil
           }}
          | {:error, reason()}

  @typedoc """
  Error reason returned by `check/0`.

    * `:docker_not_found` means no `docker` executable could be found in `PATH`.
    * `{:docker_command_failed, status, output}` means a Docker command failed
      while retrieving client information.
    * `{:docker_unavailable, status, output}` means the Docker server or daemon
      was not available to the current process.
  """
  @type reason ::
          :docker_not_found
          | {:docker_command_failed, non_neg_integer(), String.t()}
          | {:docker_unavailable, non_neg_integer(), String.t()}

  @doc """
  Returns the path to the Docker executable.

  This function searches for `docker` in the current process `PATH` by using
  `System.find_executable/1`.

  Return values:

      {:ok, "/usr/bin/docker"}
      {:error, :docker_not_found}

  `{:ok, path}` means the executable was found. `path` is the resolved path
  returned by the current process environment.

  `{:error, :docker_not_found}` means no `docker` executable was available in
  `PATH`.

  This function does not check whether the Docker daemon is running. Use
  `check/0` or `available?/0` when daemon connectivity also matters.
  """
  @spec executable() :: {:ok, Path.t()} | {:error, :docker_not_found}
  def executable() do
    case System.find_executable("docker") do
      nil -> {:error, :docker_not_found}
      path -> {:ok, path}
    end
  end

  @doc """
  Returns whether Docker is installed and usable.

  This is a boolean convenience wrapper around `check/0`.

  Return values:

      true
      false

  Returns `true` only when all of the following conditions are satisfied:

    * the `docker` executable is found in `PATH`
    * the Docker client version can be queried
    * the Docker server version can be queried, which implies that the Docker
      daemon is reachable by the current process

  Returns `false` for all error cases, including a missing executable, a failed
  Docker client command, or an unreachable Docker daemon.

  Use `check/0` instead when the caller needs diagnostic details.
  """
  @spec available?() :: boolean()
  def available?() do
    match?({:ok, _}, check())
  end

  @doc """
  Checks whether Docker is installed and usable.

  This function performs the full Docker probe. It first locates the Docker
  executable with `executable/0`, then runs Docker version commands to obtain
  both the client and server versions.

  Returns `{:ok, info}` when Docker is usable:

      {:ok,
       %{
         executable: "/usr/bin/docker",
         client_version: "24.0.0",
         server_version: "24.0.0"
       }}

  The returned map contains:

    * `:executable` - the resolved path to the Docker executable
    * `:client_version` - the Docker client version reported by the executable
    * `:server_version` - the Docker server version reported by the daemon

  The version fields are intended to be strings returned by Docker version
  commands.

  Returns one of the following error tuples:

      {:error, :docker_not_found}
      {:error, {:docker_command_failed, status, output}}
      {:error, {:docker_unavailable, status, output}}

  Error reasons:

    * `:docker_not_found` means no `docker` executable could be found in `PATH`.
    * `{:docker_command_failed, status, output}` means the Docker executable was
      found, but a Docker command failed while retrieving client information.
    * `{:docker_unavailable, status, output}` means the Docker client exists,
      but the Docker server or daemon is stopped, unreachable, or inaccessible
      to the current user.

  `status` is the Docker command exit status. `output` is the trimmed combined
  standard output and standard error from the Docker command.
  """
  @spec check() :: check_result()
  def check() do
    with {:ok, docker} <- executable(),
         {:ok, client_version} <- docker_version(docker, "Client.Version"),
         {:ok, server_version} <- docker_version(docker, "Server.Version") do
      {:ok, %{executable: docker, client_version: client_version, server_version: server_version}}
    end
  end

  defp docker_version(docker, field) do
    args = ["version", "--format", "{{." <> field <> "}}"]

    case System.cmd(docker, args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, status} when field == "Server.Version" ->
        {:error, {:docker_unavailable, status, String.trim(output)}}

      {output, status} ->
        {:error, {:docker_command_failed, status, String.trim(output)}}
    end
  rescue
    e in ErlangError -> {:error, {:docker_command_failed, 127, Exception.message(e)}}
  end
end
