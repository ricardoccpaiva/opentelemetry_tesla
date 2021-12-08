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
    bypass = Bypass.open()

    :application.stop(:opentelemetry)
    :application.set_env(:opentelemetry, :tracer, :otel_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{scheduled_delay_ms: 1, exporter: {:otel_exporter_pid, self()}}}
    ])

    :application.start(:opentelemetry)

    OpentelemetryTesla.setup()

    {:ok, bypass: bypass}
  end

  test "Records spans for Tesla HTTP client", %{bypass: bypass} do
    defmodule TestClient do
      def get(client) do
        Tesla.get(client, "/users/")
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    client = TestClient.client(endpoint_url(bypass.port))

    TestClient.get(client)

    assert_receive {:span,
                    span(
                      name: "HTTP GET",
                      attributes: [
                        "http.method": "GET",
                        "http.url": url,
                        "http.target": "/users/",
                        "http.host": "localhost",
                        "http.scheme": "http",
                        "http.status_code": 204
                      ]
                    )}

    assert url == "http://localhost:#{bypass.port}/users/"
  end

  test "Marks Span status as :error when HTTP request fails", %{bypass: bypass} do
    defmodule TestClient do
      def get(client) do
        Tesla.get(client, "/users/")
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users", fn conn ->
      Plug.Conn.resp(conn, 500, "")
    end)

    client = TestClient.client(endpoint_url(bypass.port))

    TestClient.get(client)

    assert_receive {:span, span(status: {:status, :error, ""})}
  end

  test "Marks Span status as :errors when max redirects are exceeded", %{bypass: bypass} do
    defmodule TestClient do
      def get(client) do
        Tesla.get(client, "/users/")
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry,
          {Tesla.Middleware.FollowRedirects, max_redirects: 1}
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect(bypass, "GET", "/users", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("Location", "/users/1")
      |> Plug.Conn.resp(301, "")
    end)

    Bypass.expect(bypass, "GET", "/users/1", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("Location", "/users/2")
      |> Plug.Conn.resp(301, "")
    end)

    client = TestClient.client(endpoint_url(bypass.port))

    TestClient.get(client)

    assert_receive {:span, span(status: {:status, :error, ""})}
  end

  test "Appends query string parameters to http.url attribute", %{bypass: bypass} do
    defmodule TestClient do
      def get(client, id) do
        params = [id: id]
        Tesla.get(client, "/users/:id", opts: [path_params: params])
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry,
          Tesla.Middleware.PathParams,
          {Tesla.Middleware.Query, [token: "some-token", array: ["foo", "bar"]]}
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users/2", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    client = TestClient.client(endpoint_url(bypass.port))

    TestClient.get(client, "2")

    assert_receive {:span, span(name: "HTTP GET", attributes: attributes)}

    assert attributes[:"http.url"] ==
             "http://localhost:#{bypass.port}/users/2?token=some-token&array%5B%5D=foo&array%5B%5D=bar"
  end

  test "http.url attribute is correct when request doesn't contain query string parameters", %{
    bypass: bypass
  } do
    defmodule TestClient do
      def get(client, id) do
        params = [id: id]
        Tesla.get(client, "/users/:id", opts: [path_params: params])
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry,
          Tesla.Middleware.PathParams,
          {Tesla.Middleware.Query, []}
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users/2", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    client = TestClient.client(endpoint_url(bypass.port))

    TestClient.get(client, "2")

    assert_receive {:span, span(name: "HTTP GET", attributes: attributes)}

    assert attributes[:"http.url"] ==
             "http://localhost:#{bypass.port}/users/2"
  end

  test "Handles url path arguments correctly", %{bypass: bypass} do
    defmodule TestClient do
      def get(client, id) do
        params = [id: id]
        Tesla.get(client, "/users/:id", opts: [path_params: params])
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry,
          Tesla.Middleware.PathParams,
          {Tesla.Middleware.Query, [token: "some-token"]}
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users/2", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    client = TestClient.client(endpoint_url(bypass.port))

    TestClient.get(client, "2")

    assert_receive {:span, span(name: "HTTP GET", attributes: attributes)}

    assert attributes[:"http.target"] == "/users/2"
  end

  test "Records http.response_content_length param into the span", %{bypass: bypass} do
    defmodule TestClient do
      def get(client, id) do
        params = [id: id]
        Tesla.get(client, "/users/:id", opts: [path_params: params])
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry,
          Tesla.Middleware.PathParams,
          {Tesla.Middleware.Query, [token: "some-token"]}
        ]

        Tesla.client(middleware)
      end
    end

    response = "HELLO 👋"

    Bypass.expect_once(bypass, "GET", "/users/2", fn conn ->
      Plug.Conn.resp(conn, 200, response)
    end)

    client = TestClient.client(endpoint_url(bypass.port))

    TestClient.get(client, "2")

    assert_receive {:span, span(name: "HTTP GET", attributes: attributes)}

    {response_size, _} = Integer.parse(attributes[:"http.response_content_length"])
    assert response_size == byte_size(response)
  end

  test "Records spans for exceptions" do
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
                            {"exception.stacktrace", _stacktrace}
                            | %{}
                          ]
                        )
                      ],
                      status: ^expected_status
                    )}
  end

  test "Appends the given `span_name` option to span's name", %{
    bypass: bypass
  } do
    defmodule TestClient do
      def get(client) do
        Tesla.get(client, "/users/")
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry,
          {Tesla.Middleware.OpenTelemetry, span_name: "external-service"}
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    client = TestClient.client(endpoint_url(bypass.port))
    TestClient.get(client)

    assert_receive {:span, span(name: "HTTP GET - external-service", attributes: _)}
  end

  test "Configures ok-ish/expected HTTP response statuses so spans are not flagged as errors", %{
    bypass: bypass
  } do
    defmodule TestClient do
      def get(client) do
        Tesla.get(client, "/users/")
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          Tesla.Middleware.Telemetry,
          {Tesla.Middleware.OpenTelemetry,
           span_name: "external-service", non_error_statuses: [404]}
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users", fn conn ->
      Plug.Conn.resp(conn, 404, "")
    end)

    client = TestClient.client(endpoint_url(bypass.port))
    TestClient.get(client)

    assert_receive {:span, span(status: status)}

    refute status == OpenTelemetry.status(:error, "")
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/"
end
