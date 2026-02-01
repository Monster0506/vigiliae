defmodule Vigiliae.MixProject do
  use Mix.Project

  def project do
    [
      app: :vigiliae,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Vigiliae.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:optimus, "~> 0.5"}
    ]
  end

  defp escript do
    [
      main_module: Vigiliae.CLI,
      name: "vigiliae"
    ]
  end
end
