defmodule Tesla.Middleware.OpenTelemetry do
  @behaviour Tesla.Middleware

  def call(env, next, options \\ []) do
    env
    |> maybe_put_span_name(options[:span_name])
    |> Tesla.put_headers(:otel_propagator_text_map.inject([]))
    |> Tesla.run(next)
  end

  defp maybe_put_span_name(env, nil), do: env

  defp maybe_put_span_name(env, span_name) when is_binary(span_name) do
    case env.opts[:span_name] do
      nil ->
        Tesla.put_opt(env, :span_name, span_name)

      _ ->
        env
    end
  end
end
