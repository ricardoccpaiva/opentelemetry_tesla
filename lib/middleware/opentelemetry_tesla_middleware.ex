defmodule Tesla.Middleware.OpenTelemetry do
  @moduledoc """
  Injects tracing header to external requests and configures some
  span's behaviours.
  ## Options
    * `:span_name` - appends the given string to the generated span's name of
      _HTTP + verb_.
    * `:non_error_statuses` - configures expected HTTP response status errors,
      usually >= 400, to not mark spans as errors. E.g., expected 404
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

  require OpenTelemetry.Tracer
  @behaviour Tesla.Middleware

  def call(env, next, options \\ []) do
    span_name = get_span_name(env, options[:span_name])

    OpenTelemetry.Tracer.with_span span_name, %{kind: :client} do
      env
      |> maybe_put_non_error_statuses(options[:non_error_statuses])
      |> Tesla.put_headers(:otel_propagator_text_map.inject([]))
      |> Tesla.run(next)
      |> set_span_attributes()
      |> handle_result()
    end
  end

  defp get_span_name(_env, span_name_opt) when is_binary(span_name_opt), do: span_name_opt

  defp get_span_name(env, _span_name_opt) do
    case env.opts[:path_params] do
      nil -> "HTTP #{http_method(env.method)}"
      _ -> URI.parse(env.url).path
    end
  end

  defp maybe_put_non_error_statuses(env, nil), do: env
  defp maybe_put_non_error_statuses(env, []), do: env

  defp maybe_put_non_error_statuses(env, [_|_] = non_error_statuses) do
    case env.opts[:non_error_statuses] do
      nil -> Tesla.put_opt(env, :non_error_statuses, non_error_statuses)
      _ -> env
    end
  end

  defp set_span_attributes({_, %Tesla.Env{} = env} = result) do
    OpenTelemetry.Tracer.set_attributes(build_attrs(env))

    result
  end

  defp set_span_attributes(result) do
    result
  end

  defp handle_result({:ok, %Tesla.Env{status: status, opts: opts} = env}) when status >= 400 do
    non_error_statuses = Keyword.get(opts, :non_error_statuses, [])

    if status not in non_error_statuses do
      OpenTelemetry.Tracer.set_status(OpenTelemetry.status(:error, ""))
    end

    {:ok, env}
  end

  defp handle_result({:error, {Tesla.Middleware.FollowRedirects, :too_many_redirects}} = result) do
    OpenTelemetry.Tracer.set_status(OpenTelemetry.status(:error, ""))

    result
  end

  defp handle_result({:ok, env}) do
    {:ok, env}
  end

  defp handle_result(result) do
    OpenTelemetry.Tracer.set_status(OpenTelemetry.status(:error, ""))

    result
  end

  defp build_attrs(%Tesla.Env{
         method: method,
         url: url,
         status: status_code,
         headers: headers,
         query: query
       }) do
    url = Tesla.build_url(url, query)
    uri = URI.parse(url)

    attrs = %{
      "http.method": http_method(method),
      "http.url": url,
      "http.target": uri.path,
      "http.host": uri.host,
      "http.scheme": uri.scheme,
      "http.status_code": status_code
    }

    maybe_append_content_length(attrs, headers)
  end

  defp maybe_append_content_length(attrs, headers) do
    case Enum.find(headers, fn {k, _v} -> k == "content-length" end) do
      nil ->
        attrs

      {_key, content_length} ->
        Map.put(attrs, :"http.response_content_length", content_length)
    end
  end

  defp http_method(method) do
    method
    |> Atom.to_string()
    |> String.upcase()
  end
end
