defmodule Project4.Mixfile do
  use Mix.Project

  def project do
    [
      app: :project4,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      escript: [main_module: Main, emu_args: "-setcookie oreo"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

end
