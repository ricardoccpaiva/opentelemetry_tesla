defmodule Tesla.Middleware.OpenTelemetry do
  @behaviour Tesla.Middleware

  def call(env, next, _options) do
    env
    |> Tesla.put_headers(:otel_propagator.text_map_inject([]))
    |> Tesla.run(next)
  end
end
