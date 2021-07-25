# OpenTelemetryTesla

[![Build Status](https://github.com/ricardoccpaiva/opentelemetry_tesla/actions/workflows/elixir.yml/badge.svg)](https://github.com/ricardoccpaiva/opentelemetry_tesla/actions)

Telemetry handler that creates OpenTelemetry spans from Tesla HTTP client events.

It attaches to the following events: 
  - `[:tesla, :request, :start]` - emitted at the beginning of the request.
      * Measurement: `%{system_time: System.system_time()}`
      * Metadata: `%{env: Tesla.Env.t()}`
  - `[:tesla, :request, :stop]` - emitted at the end of the request.
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{env: Tesla.Env.t()} | %{env: Tesla.Env.t(), error: term()}`
  - `[:tesla, :request, :exception]` - emitted when an exception has been raised.
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{kind: Exception.kind(), reason: term(), stacktrace: Exception.stacktrace()}`

OpenTelemetry span is enriched with the following attributes that are parsed from Tesla `stop` event.
 - `[:method, :opts, :query, :status, :url]`
 - `:headers`, it creates one attribute per item in the headers list
 - `measurement` corresponds to the duration of the request

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `opentelemetry_tesla` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:opentelemetry_tesla, "~> 0.1.0"}
  ]
end
```
