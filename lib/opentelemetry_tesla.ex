defmodule OpentelemetryTesla do
  alias OpenTelemetry.Span

  @moduledoc """
  OpentelemetryTesla uses [telemetry](https://hexdocs.pm/telemetry/) handlers to create `OpenTelemetry` spans from Tesla HTTP client events.
  Supported events include request start/stop and also when an exception is raised.
  ## Usage
  In your application start:
      def start(_type, _args) do
        OpenTelemetry.register_application_tracer(:my_telemetry_api)
        OpentelemetryTesla.setup()
        children = [
          {Phoenix.PubSub, name: MyApp.PubSub},
          MyAppWeb.Endpoint
        ]
        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end
  """

  @tracer_id :opentelemetry_tesla

  @doc """
  Initializes and configures telemetry handlers.
  """
  @spec setup() :: :ok
  def setup() do
    {:ok, otel_tracer_vsn} = :application.get_key(@tracer_id, :vsn)
    OpenTelemetry.register_tracer(@tracer_id, otel_tracer_vsn)

    attach_request_start_handler()
    attach_request_stop_handler()
    attach_request_exception_handler()
    :ok
  end

  defp attach_request_start_handler() do
    :telemetry.attach(
      "#{__MODULE__}.request_start",
      [:tesla, :request, :start],
      &__MODULE__.handle_start/4,
      %{}
    )
  end

  defp attach_request_stop_handler() do
    :telemetry.attach(
      "#{__MODULE__}.request_stop",
      [:tesla, :request, :stop],
      &__MODULE__.handle_stop/4,
      %{}
    )
  end

  defp attach_request_exception_handler() do
    :telemetry.attach(
      "#{__MODULE__}.request_exception",
      [:tesla, :request, :exception],
      &__MODULE__.handle_exception/4,
      %{}
    )
  end

  def handle_start(_event, _measurements, %{env: %Tesla.Env{method: method}} = metadata, _config) do
    http_method = http_method(method)

    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      "HTTP #{http_method}",
      metadata,
      %{kind: :client}
    )
  end

  def handle_stop(_event, _measurements, %{env: %Tesla.Env{status: status}} = metadata, _config)
       when status > 400 do
    end_span(metadata, :error)
  end

  def handle_stop(
         _event,
         _measurements,
         %{env: _env, error: {Tesla.Middleware.FollowRedirects, :too_many_redirects}} = metadata,
         _config
       ) do
    end_span(metadata, :error)
  end

  def handle_stop(_event, _measurements, metadata, _config) do
    end_span(metadata)
  end

  defp end_span(metadata, status \\ :ok) do
    span_attrs = build_attrs(metadata)
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, metadata)

    OpenTelemetry.Span.set_attributes(ctx, span_attrs)

    if status == :error do
      Span.set_status(ctx, OpenTelemetry.status(:error, ""))
    end

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, metadata)
  end

  def handle_exception(
         _event,
         _measurements,
         %{kind: kind, reason: reason, stacktrace: stacktrace} = metadata,
         _config
       ) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, metadata)

    exception = Exception.normalize(kind, reason, stacktrace)

    Span.record_exception(ctx, exception, stacktrace, %{})
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, metadata)
  end

  defp build_attrs(%{
         env: %Tesla.Env{
           method: method,
           url: url,
           status: status_code,
           headers: headers,
           query: query
         }
       }) do
    uri =
      query
      |> Enum.into(%{})
      |> URI.encode_query()
      |> build_full_uri(url)

    attrs = [
      "http.method": http_method(method),
      "http.url": URI.to_string(uri),
      "http.target": uri.path,
      "http.host": uri.host,
      "http.scheme": uri.scheme,
      "http.status_code": status_code
    ]

    maybe_append_content_length(attrs, headers)
  end

  defp build_full_uri("", url) do
    URI.parse(url)
  end

  defp build_full_uri(query_string, url) do
    URI.parse("#{url}?#{query_string}")
  end

  defp maybe_append_content_length(attrs, headers) do
    case Enum.find(headers, fn {k, _v} -> k == "content-length" end) do
      nil ->
        attrs

      {_key, content_length} ->
        :lists.append(attrs, "http.response_content_length": content_length)
    end
  end

  defp http_method(method) do
    method
    |> Atom.to_string()
    |> String.upcase()
  end
end
