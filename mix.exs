defmodule OpentelemetryTesla.MixProject do
  use Mix.Project

  def project do
    [
      app: :opentelemetry_tesla,
      version: "2.0.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp description() do
    "Tesla middleware that creates OpenTelemetry spans and injects tracing headers into HTTP requests for Tesla clients."
  end

  defp package do
    [
      name: "opentelemetry_tesla",
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
      {:opentelemetry, "~> 1.0.0", only: :test},
      {:opentelemetry_api, "~> 1.0.0"},
      {:opentelemetry_telemetry, "~> 1.0.0"},
      {:tesla, "~> 1.4"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test},
      {:jason, "~> 1.3", only: :test}
    ]
  end
end
