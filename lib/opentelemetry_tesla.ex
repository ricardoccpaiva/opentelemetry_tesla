defmodule OpentelemetryTesla do
  alias OpenTelemetry.Span

  @moduledoc """
  OpentelemetryTesla uses [telemetry](https://hexdocs.pm/telemetry/) handlers to create `OpenTelemetry` spans from Tesla HTTP client events.
  Supported events include request start/stop and also when an exception is raised.
  ## Usage
  In your application start:
      def start(_type, _args) do
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

  def handle_start(
        _event,
        _measurements,
        %{env: %Tesla.Env{} = env} = metadata,
        _config
      ) do
    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      span_name(env),
      metadata,
      %{kind: :client}
    )
  end

  def handle_stop(
        _event,
        _measurements,
        %{env: %Tesla.Env{status: status, opts: opts}} = metadata,
        _config
      )
      when status > 400 do
    non_error_statuses = Keyword.get(opts, :non_error_statuses, [])

    if status in non_error_statuses do
      end_span(metadata, :ok)
    else
      end_span(metadata, :error)
    end
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

  defp end_span(%{env: %Tesla.Env{} = env} = metadata, status \\ :ok) do
    span_attrs = build_attrs(metadata)
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, metadata)

    OpenTelemetry.Span.update_name(ctx, span_name(env))
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

    Span.record_exception(ctx, exception, stacktrace, [])
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
    url = Tesla.build_url(url, query)
    uri = URI.parse(url)

    attrs = [
      "http.method": http_method(method),
      "http.url": url,
      "http.target": uri.path,
      "http.host": uri.host,
      "http.scheme": uri.scheme,
      "http.status_code": status_code
    ]

    maybe_append_content_length(attrs, headers)
  end

  defp maybe_append_content_length(attrs, headers) do
    case Enum.find(headers, fn {k, _v} -> k == "content-length" end) do
      nil ->
        attrs

      {_key, content_length} ->
        :lists.append(attrs, "http.response_content_length": content_length)
    end
  end

  defp span_name(env) do
    http_method = http_method(env.method)

    span_name =
      if env.opts[:span_name],
        do: " - #{to_string(env.opts[:span_name])}",
        else: ""

    "HTTP #{http_method}#{span_name}"
  end

  defp http_method(method) do
    method
    |> Atom.to_string()
    |> String.upcase()
  end
end
