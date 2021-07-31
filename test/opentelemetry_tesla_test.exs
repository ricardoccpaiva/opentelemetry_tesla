defmodule OpentelemetryTeslaTest do
  use ExUnit.Case
  require Record

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry_api/include/opentelemetry.hrl") do
    Record.defrecord(name, spec)
  end

  setup do
    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    OpentelemetryTesla.setup()
    :ok
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
      tesla_env
    )

    :telemetry.execute(
      [:tesla, :request, :stop],
      %{duration: 1000},
      tesla_env
    )

    assert_receive {:span,
                    span(
                      name: "HTTP GET",
                      attributes: [
                        "http.method": "GET",
                        "http.url": "http://end_of_the_inter.net",
                        "http.target": nil,
                        "http.host": "end_of_the_inter.net",
                        "http.scheme": "http",
                        "http.status_code": nil
                      ]
                    )}
  end

  test "Records Spans for exceptions" do
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

    exception = %{
      kind: :error,
      reason: :timeout_value,
      stacktrace: [
        {:timer, :sleep, 1, [file: 'timer.erl', line: 152]},
        {Tesla.Adapter.Httpc, :call, 2, [file: 'lib/tesla/adapter/httpc.ex', line: 20]},
        {Tesla.Middleware.Telemetry, :call, 3,
         [file: 'lib/tesla/middleware/telemetry.ex', line: 97]}
      ]
    }

    :telemetry.execute(
      [:tesla, :request, :start],
      %{},
      tesla_env
    )

    :telemetry.execute(
      [:tesla, :request, :exception],
      %{duration: 10},
      exception
    )

    expected_status = OpenTelemetry.status(:error, "")

    assert_receive {:span,
                    span(
                      name: "HTTP GET",
                      attributes: _list,
                      kind: :client,
                      events: [
                        event(
                          name: "exception",
                          attributes: [
                            {"exception.type", "Elixir.ErlangError"},
                            {"exception.message", "Erlang error: :timeout_value"},
                            {"exception.stacktrace",
                             "    (stdlib 3.14) timer.erl:152: :timer.sleep/1\n    (tesla 1.4.2) lib/tesla/adapter/httpc.ex:20: Tesla.Adapter.Httpc.call/2\n    (tesla 1.4.2) lib/tesla/middleware/telemetry.ex:97: Tesla.Middleware.Telemetry.call/3\n"},
                            {:duration, 10}
                          ]
                        )
                      ],
                      status: ^expected_status
                    )}
  end
end
