defmodule DockerAvailability.MixProject do
  use Mix.Project

  @version "1.0.2"
  @source_url "https://github.com/zacky1972/docker_availability"

  def project do
    [
      app: :docker_availability,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "DockerAvailability",
      description: description(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package(),
      aliases: aliases(),
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp description do
    "A small Elixir probe for checking whether Docker is installed and usable."
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    [
      name: "docker_availability",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md CHANGELOG.md),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp aliases do
    [
      check: [
        "hex.audit",
        "compile --warnings-as-errors --force",
        "format --check-formatted --migrate",
        "credo",
        "deps.unlock --check-unused",
        "spellweaver.check",
        "dialyzer"
      ],
      precommit: [
        "hex.audit",
        "compile --warnings-as-errors --force",
        "format --migrate",
        "credo",
        "deps.unlock --unused",
        "spellweaver.check",
        "dialyzer",
        "test"
      ]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nstandard, "~> 0.3", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:spellweaver, "~> 0.1", only: [:dev, :test], runtime: false}
    ]
  end
end
