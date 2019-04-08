defmodule Kaffe.Config.Producer do
  import Kaffe.Config, only: [heroku_kafka_endpoints: 0, parse_endpoints: 1, parse_overrides: 1]

  def configuration(overrides \\ %{}) do
    new_overrides = parse_overrides(overrides)
    base_config = %{
      endpoints: endpoints(new_overrides),
      producer_config: client_producer_config(new_overrides),
      client_name: config_get(:client_name, :kaffe_producer_client),
      topics: producer_topics(),
      partition_strategy: config_get(:partition_strategy, :md5)
    }
    Map.merge(base_config, new_overrides)
  end

  def producer_topics, do: config_get!(:topics)

  def endpoints(overrides) do
    cond do
      heroku_kafka?() -> heroku_kafka_endpoints()
      endpoints = Map.get(overrides, :endpoints) -> endpoints
      true -> parse_endpoints(config_get!(:endpoints))
    end
  end

  def client_producer_config(overrides) do
    base_config = default_client_producer_config() ++ maybe_heroku_kafka_ssl() ++ sasl_options()
    overrides_keyword_list = Enum.into(overrides, [])
    Keyword.merge(base_config, overrides_keyword_list)
  end

  def sasl_options do
    :sasl
    |> config_get(%{})
    |> Kaffe.Config.sasl_config()
  end

  def maybe_heroku_kafka_ssl do
    case heroku_kafka?() do
      true -> Kaffe.Config.ssl_config()
      false -> []
    end
  end

  def default_client_producer_config do
    [
      auto_start_producers: true,
      allow_topic_auto_creation: false,
      default_producer_config: [
        required_acks: config_get(:required_acks, -1),
        ack_timeout: config_get(:ack_timeout, 1000),
        partition_buffer_limit: config_get(:partition_buffer_limit, 512),
        partition_onwire_limit: config_get(:partition_onwire_limit, 1),
        max_batch_size: config_get(:max_batch_size, 1_048_576),
        max_retries: config_get(:max_retries, 3),
        retry_backoff_ms: config_get(:retry_backoff_ms, 500),
        compression: config_get(:compression, :no_compression),
        min_compression_batch_size: config_get(:min_compression_batch_size, 1024)
      ]
    ]
  end

  def heroku_kafka? do
    config_get(:heroku_kafka_env, false)
  end

  def config_get!(key) do
    Application.get_env(:kaffe, :producer)
    |> Keyword.fetch!(key)
  end

  def config_get(key, default) do
    Application.get_env(:kaffe, :producer)
    |> Keyword.get(key, default)
  end
end
