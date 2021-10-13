defmodule Tesla.Middleware.OpenTelemetry do
  @behaviour Tesla.Middleware

  def call(env, next, _options) do
    env
    |> Tesla.put_headers(inject([]))
    |> Tesla.run(next)
  end

  defp inject(carrier), do: :otel_propagator_text_map.inject(carrier)
end
