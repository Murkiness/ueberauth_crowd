defmodule UeberauthCrowd.MixProject do
  use Mix.Project

  def project do
    [
      app: :ueberauth_crowd,
      description: "Crowd OpenID Strategy for Überauth.",
      version: "0.1.0",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Überauth Crowd",
    ]
  end

  defp package do
    [
      name: "ueberauth_crowd",
      licenses: ["MIT"],
      maintainers: ["Vladimir Hohrenko", "Nikita Babushkin"],
      links: %{
        "GitHub" => "https://github.com/Murkiness/ueberauth_crowd",
      },
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Dependencies
      {:httpoison, "~> 1.7.0"},
      {:ueberauth, "~> 0.6"},

      # Testing
      {:meck, "~> 0.8.4", only: :test},

      # Code Maintenance
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:test, :dev], runtime: false},
      {:ex_doc, "~> 0.15", only: :dev, runtime: false}
    ]
  end
end
