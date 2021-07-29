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
      &handle_start/4,
      %{}
    )
  end

  defp attach_request_stop_handler() do
    :telemetry.attach(
      "#{__MODULE__}.request_stop",
      [:tesla, :request, :stop],
      &handle_stop/4,
      %{}
    )
  end

  defp attach_request_exception_handler() do
    :telemetry.attach(
      "#{__MODULE__}.request_exception",
      [:tesla, :request, :exception],
      &handle_exception/4,
      %{}
    )
  end

  defp handle_start(_event, _measurements, _metadata, _config) do
    OpentelemetryTelemetry.start_telemetry_span(
      @tracer_id,
      "External HTTP Request",
      %{},
      %{kind: :server}
    )
  end

  defp handle_stop(_event, %{duration: measurement}, metadata, _config) do
    span_args =
      metadata
      |> headers_span_args()
      |> :lists.append(span_args(metadata))
      |> :lists.append([{"http.request.measurement", measurement}])

    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, %{})

    OpenTelemetry.Span.set_attributes(ctx, span_args)

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, %{})
  end

  defp handle_exception(
         _event,
         %{duration: native_time},
         %{kind: kind, reason: reason, stacktrace: stacktrace},
         _config
       ) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, %{})

    exception = Exception.normalize(kind, reason, stacktrace)

    Span.record_exception(ctx, exception, stacktrace, duration: native_time)
    Span.set_status(ctx, OpenTelemetry.status(:error, ""))
    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, %{})
  end

  defp headers_span_args(metadata) do
    case Map.get(metadata, :env) do
      nil ->
        []

      map ->
        map
        |> Map.get(:headers)
        |> Enum.map(fn {key, value} -> {"http.headers.#{key}", value} end)
    end
  end

  defp span_args(metadata) do
    case Map.get(metadata, :env) do
      nil ->
        []

      map ->
        map
        |> Map.take([:method, :opts, :query, :status, :url])
        |> Enum.map(fn {key, value} -> {"http.#{key}", value} end)
    end
  end
end
