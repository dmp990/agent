defmodule Codingagent.MixProject do
  use Mix.Project

  def project do
    [
      app: :codingagent,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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
      {:req, "~> 0.5"},
      {:dotenvy, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      agent: ["run -e 'Codingagent.CLI.main(System.argv())' --"]
    ]
  end
end
