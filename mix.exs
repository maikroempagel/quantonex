defmodule Quantonex.MixProject do
  use Mix.Project

  def project do
    [
      app: :quantonex,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
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
      {:credo, "~> 1.2"},
      {:decimal, "~> 1.8"},
      {:ex_doc, "~> 0.21.3"},
      {:excoveralls, "~> 0.12.2"}
    ]
  end
end
