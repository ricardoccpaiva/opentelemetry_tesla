import Config

config :opentelemetry,
  sampler: {:otel_sampler_always_on, %{}},
  tracer: :otel_tracer_default,
  processors: [{:otel_batch_processor, %{scheduled_delay_ms: 1}}]
