defmodule OpentelemetryTesla.MixProject do
  use Mix.Project

  def project do
    [
      app: :opentelemetry_tesla,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description()
    ]
  end

  defp description() do
    "Telemetry handler that creates OpenTelemetry spans from Tesla HTTP client events."
  end

  defp package do
    [
      name: "OpentelemetryTesla",
      maintainers: ["Ricardo Paiva"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ricardoccpaiva/opentelemetry_tesla"}
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
      {:telemetry, "~> 0.4"},
      {:opentelemetry, "~> 1.0.0-rc.2"},
      {:opentelemetry_telemetry, "~> 1.0.0-beta.2"},
      {:tesla, "~> 1.4"}
    ]
  end
end
