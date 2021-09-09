# OpenTelemetryTesla

[![Build Status](https://github.com/ricardoccpaiva/opentelemetry_tesla/actions/workflows/elixir.yml/badge.svg)](https://github.com/ricardoccpaiva/opentelemetry_tesla/actions)

This library is divided into two components:
  - Tesla middleware that injects tracing headers into HTTP requests

  - Telemetry handler that creates OpenTelemetry spans from Tesla HTTP client events

The handler implementation attaches to the following events: 
  - `[:tesla, :request, :start]` - emitted at the beginning of the request.
      * Measurement: `%{system_time: System.system_time()}`
      * Metadata: `%{env: Tesla.Env.t()}`
  - `[:tesla, :request, :stop]` - emitted at the end of the request.
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{env: Tesla.Env.t()} | %{env: Tesla.Env.t(), error: term()}`
  - `[:tesla, :request, :exception]` - emitted when an exception has been raised.
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{kind: Exception.kind(), reason: term(), stacktrace: Exception.stacktrace()}`

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `opentelemetry_tesla` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:opentelemetry_tesla, "~> 1.1.0-rc.1"}
  ]
end
```

## Setup
If you want to use Telemetry handler, make sure you add the following lines to your application start:
```elixir
OpenTelemetry.register_application_tracer(:my_telemetry_api)
OpentelemetryTesla.setup()
```

To propagate tracing information you'll also have to add the tesla middleware.
```elixir
plug Tesla.Middleware.OpenTelemetry
```
