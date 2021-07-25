defmodule OpentelemetryTeslaTest do
  use ExUnit.Case
  require Record

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  setup do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    OpentelemetryTesla.setup()
    :ok
  end

  test "Records Spans for Tesla HTTP client if metadata is missing" do
    :telemetry.execute(
      [:tesla, :request, :start],
      %{},
      %{}
    )

    :telemetry.execute(
      [:tesla, :request, :stop],
      %{duration: 1000},
      %{}
    )

    assert_receive {:span,
                    span(
                      name: "External HTTP Request",
                      attributes: [{"http.request.measurement", 1000}]
                    )}
  end

  test "Records Spans for Tesla HTTP client with metadata" do
    tesla_env = %{
      env: %Tesla.Env{
        __client__: %Tesla.Client{adapter: nil, fun: nil, post: [], pre: []},
        __module__: __MODULE__,
        body: nil,
        headers: [],
        method: :get,
        opts: [],
        query: [],
        status: nil,
        url: "http://end_of_the_inter.net"
      }
    }

    :telemetry.execute(
      [:tesla, :request, :start],
      %{},
      %{}
    )

    :telemetry.execute(
      [:tesla, :request, :stop],
      %{duration: 1000},
      tesla_env
    )

    assert_receive {:span,
                    span(
                      name: "External HTTP Request",
                      attributes: [
                        {"http.method", :get},
                        {"http.opts", []},
                        {"http.query", []},
                        {"http.status", nil},
                        {"http.url", "http://end_of_the_inter.net"},
                        {"http.request.measurement", 1000}
                      ]
                    )}
  end
end
