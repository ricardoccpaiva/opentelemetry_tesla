defmodule Tesla.Middleware.OpenTelemetryTest do
  use ExUnit.Case

  test "Injects distributed tracing headers" do
    OpentelemetryTelemetry.start_telemetry_span(
      "tracer_id",
      "my_label",
      %{},
      %{kind: :client}
    )

    assert {:ok,
            %Tesla.Env{
              headers: [
                {"traceparent", traceparent}
              ]
            }} =
             Tesla.Middleware.OpenTelemetry.call(
               %Tesla.Env{url: ""},
               [],
               []
             )

    assert is_binary(traceparent)
  end

  test "Puts the `span_name` option into Tesla.Env's `opts`" do
    assert {:ok, env} =
             Tesla.Middleware.OpenTelemetry.call(%Tesla.Env{url: ""}, [],
               span_name: "external-service"
             )

    assert env.opts[:span_name] == "external-service"
  end
end
