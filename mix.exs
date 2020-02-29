defmodule Quantonex.MixProject do
  use Mix.Project

  @github_url "https://github.com/maikroempagel/quantonex"

  @version "0.1.0"

  def project do
    [
      app: :quantonex,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      source_url: @github_url,
      homepage_url: @github_url,
      files: ~w(mix.exs lib LICENSE.txt README.md CHANGELOG.md),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false},
      {:decimal, "~> 1.8"},
      {:ex_doc, "~> 0.21.3", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12.2", only: :test},
      {:git_ops, "~> 1.1.1", only: :dev}
    ]
  end

  defp description() do
    """
    A technical analysis library for algorithmic trading written in Elixir.
    """
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md"
      ]
    ]
  end

  defp package() do
    [
      name: :quantonex,
      maintainers: ["Maik Römpagel"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url
      }
    ]
  end
end
