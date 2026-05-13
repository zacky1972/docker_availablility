defmodule DockerAvailabilityTest do
  use ExUnit.Case, async: false

  doctest DockerAvailability

  setup do
    tmp_dir =
      Path.join([
        System.tmp_dir!(),
        "docker_availability_test_#{System.unique_integer([:positive])}"
      ])

    bin_dir = Path.join(tmp_dir, "bin")
    File.mkdir_p!(bin_dir)

    original_path = System.get_env("PATH")
    System.put_env("PATH", bin_dir)

    on_exit(fn ->
      case original_path do
        nil -> System.delete_env("PATH")
        path -> System.put_env("PATH", path)
      end

      File.rm_rf(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir, bin_dir: bin_dir}
  end

  describe "executable/0" do
    test "returns the docker executable path when docker exists in PATH", %{bin_dir: bin_dir} do
      docker = write_fake_docker!(bin_dir, successful_version_script())

      assert DockerAvailability.executable() == {:ok, docker}
    end

    test "returns docker_not_found when docker does not exist in PATH" do
      assert DockerAvailability.executable() == {:error, :docker_not_found}
    end
  end

  describe "check/0" do
    test "returns executable and Docker client/server versions when Docker is usable", %{
      bin_dir: bin_dir
    } do
      docker = write_fake_docker!(bin_dir, successful_version_script("27.3.1", "27.3.2"))

      assert {:ok, info} = DockerAvailability.check()

      assert info == %{
               executable: docker,
               client_version: "27.3.1",
               server_version: "27.3.2"
             }
    end

    test "queries client version before server version", %{tmp_dir: tmp_dir, bin_dir: bin_dir} do
      log_file = Path.join(tmp_dir, "docker_calls.log")

      write_fake_docker!(
        bin_dir,
        """
        echo "$*" >> #{sh_quote(log_file)}

        if [ "$1" = "version" ] && [ "$2" = "--format" ]; then
          case "$3" in
            "{{.Client.Version}}") echo "27.3.1"; exit 0 ;;
            "{{.Server.Version}}") echo "27.3.2"; exit 0 ;;
          esac
        fi

        echo "unexpected docker args: $*" >&2
        exit 2
        """
      )

      assert {:ok, _info} = DockerAvailability.check()

      assert File.read!(log_file) ==
               "version --format {{.Client.Version}}\n" <>
                 "version --format {{.Server.Version}}\n"
    end

    test "trims client and server version output", %{bin_dir: bin_dir} do
      write_fake_docker!(
        bin_dir,
        """
        if [ "$1" = "version" ] && [ "$2" = "--format" ]; then
          case "$3" in
            "{{.Client.Version}}") printf "  27.3.1  \\n"; exit 0 ;;
            "{{.Server.Version}}") printf "\\t27.3.2\\n"; exit 0 ;;
          esac
        fi

        echo "unexpected docker args: $*" >&2
        exit 2
        """
      )

      assert {:ok, %{client_version: "27.3.1", server_version: "27.3.2"}} =
               DockerAvailability.check()
    end

    test "returns docker_not_found when docker executable does not exist in PATH" do
      assert DockerAvailability.check() == {:error, :docker_not_found}
    end

    test "returns docker_command_failed when the client version command fails", %{
      bin_dir: bin_dir
    } do
      write_fake_docker!(
        bin_dir,
        """
        if [ "$1" = "version" ] && [ "$2" = "--format" ]; then
          case "$3" in
            "{{.Client.Version}}") echo "client version failed" >&2; exit 42 ;;
            "{{.Server.Version}}") echo "server version should not be queried" >&2; exit 99 ;;
          esac
        fi

        echo "unexpected docker args: $*" >&2
        exit 2
        """
      )

      assert DockerAvailability.check() ==
               {:error, {:docker_command_failed, 42, "client version failed"}}
    end

    test "returns docker_unavailable when the server version command fails", %{
      bin_dir: bin_dir
    } do
      write_fake_docker!(
        bin_dir,
        """
        if [ "$1" = "version" ] && [ "$2" = "--format" ]; then
          case "$3" in
            "{{.Client.Version}}") echo "27.3.1"; exit 0 ;;
            "{{.Server.Version}}") echo "Cannot connect to the Docker daemon" >&2; exit 1 ;;
          esac
        fi

        echo "unexpected docker args: $*" >&2
        exit 2
        """
      )

      assert DockerAvailability.check() ==
               {:error, {:docker_unavailable, 1, "Cannot connect to the Docker daemon"}}
    end

    test "combines stdout and stderr for failed Docker commands", %{bin_dir: bin_dir} do
      write_fake_docker!(
        bin_dir,
        """
        if [ "$1" = "version" ] && [ "$2" = "--format" ]; then
          case "$3" in
            "{{.Client.Version}}")
              echo "client stdout"
              echo "client stderr" >&2
              exit 7
              ;;
            "{{.Server.Version}}")
              echo "server version should not be queried" >&2
              exit 99
              ;;
          esac
        fi

        echo "unexpected docker args: $*" >&2
        exit 2
        """
      )

      assert {:error, {:docker_command_failed, 7, output}} = DockerAvailability.check()
      assert output =~ "client stdout"
      assert output =~ "client stderr"
    end
  end

  describe "available?/0" do
    test "returns true when check/0 succeeds", %{bin_dir: bin_dir} do
      write_fake_docker!(bin_dir, successful_version_script())

      assert DockerAvailability.available?()
    end

    test "returns false when docker executable is missing" do
      refute DockerAvailability.available?()
    end

    test "returns false when the client version command fails", %{bin_dir: bin_dir} do
      write_fake_docker!(
        bin_dir,
        """
        if [ "$1" = "version" ] && [ "$2" = "--format" ]; then
          case "$3" in
            "{{.Client.Version}}") echo "client version failed" >&2; exit 42 ;;
            "{{.Server.Version}}") echo "server version should not be queried" >&2; exit 99 ;;
          esac
        fi

        echo "unexpected docker args: $*" >&2
        exit 2
        """
      )

      refute DockerAvailability.available?()
    end

    test "returns false when the Docker daemon is unavailable", %{bin_dir: bin_dir} do
      write_fake_docker!(
        bin_dir,
        """
        if [ "$1" = "version" ] && [ "$2" = "--format" ]; then
          case "$3" in
            "{{.Client.Version}}") echo "27.3.1"; exit 0 ;;
            "{{.Server.Version}}") echo "Cannot connect to the Docker daemon" >&2; exit 1 ;;
          esac
        fi

        echo "unexpected docker args: $*" >&2
        exit 2
        """
      )

      refute DockerAvailability.available?()
    end
  end

  defp write_fake_docker!(bin_dir, body) do
    path = Path.join(bin_dir, "docker")

    File.write!(path, "#!/bin/sh\n" <> body)
    :ok = File.chmod(path, 0o755)

    path
  end

  defp successful_version_script(client_version \\ "27.3.1", server_version \\ "27.3.1") do
    """
    if [ "$1" = "version" ] && [ "$2" = "--format" ]; then
      case "$3" in
        "{{.Client.Version}}") echo "#{client_version}"; exit 0 ;;
        "{{.Server.Version}}") echo "#{server_version}"; exit 0 ;;
      esac
    fi

    echo "unexpected docker args: $*" >&2
    exit 2
    """
  end

  defp sh_quote(value) do
    "'" <> String.replace(value, "'", "'\"'\"'") <> "'"
  end
end
