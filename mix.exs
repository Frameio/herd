defmodule Herd.MixProject do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :herd,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:libring, "~> 1.1"},
      {:ex_doc, "~> 0.19", only: :dev},
      {:poolboy, "~> 1.5"}
    ]
  end

  defp description do
    """
    Connection manager for a cluster of nodes
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Michael Guarino"],
      links: %{"GitHub" => "https://github.com/Frameio/herd"}
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/Frameio/herd"
    ]
  end
end
