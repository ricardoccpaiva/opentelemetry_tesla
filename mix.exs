defmodule OpentelemetryTesla.MixProject do
  use Mix.Project

  def project do
    [
      app: :opentelemetry_tesla,
      version: "1.3.2-rc.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
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
    "Telemetry handler that creates OpenTelemetry spans from Tesla HTTP client events."
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:tls_certificate_check, "~> 1.15", only: [:dev, :test]},
      {:opentelemetry_api, "~> 1.1.0"},
      {:opentelemetry, "~> 1.1.0", only: [:dev, :test]},
      {:opentelemetry_exporter, "~> 1.1.0", only: [:dev, :test]},
      {:opentelemetry_telemetry, "~> 1.0.0"},
      {:tesla, "~> 1.4"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test}
    ]
  end
end
