defmodule Tesla.Middleware.OpenTelemetry do
  @moduledoc """
  Injects tracing header to external requests and configures some
  span's behaviours.

  ## Options

    * `:span_name` - string to be appended to the generated span name.
      Defaults to _HTTP_ plus the _request method_, e.g., _HTTP GET_.

    * `:non_error_statuses` - do not flag spans as errors for the given
      HTTP response status codes. E.g., sometimes a 404 is a valid and
      normal result; flagging it as an error can make it difficult to
      search/analyze the real ones.

  ## Examples

      middlewares = [
        ...,
        {Tesla.Middleware.OpenTelemetry, span_name: "my-external-service"}
      ]


      middlewares = [
        ...,
        {Tesla.Middleware.OpenTelemetry, non_error_statuses: [404]}
      ]
  """
  @behaviour Tesla.Middleware

  def call(env, next, options \\ []) do
    env
    |> maybe_put_span_name(options[:span_name])
    |> maybe_put_non_error_statuses(options[:non_error_statuses])
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

  defp maybe_put_non_error_statuses(env, nil), do: env

  defp maybe_put_non_error_statuses(env, non_error_statuses) when is_list(non_error_statuses) do
    case env.opts[:non_error_statuses] do
      nil ->
        Tesla.put_opt(env, :non_error_statuses, non_error_statuses)

      _ ->
        env
    end
  end
end
