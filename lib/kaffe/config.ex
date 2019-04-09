defmodule Kaffe.Config do
  def heroku_kafka_endpoints do
    "KAFKA_URL"
    |> System.get_env()
    |> parse_endpoints()
  end

  def parse_endpoints(endpoints) when is_list(endpoints), do: endpoints

  def parse_endpoints(url) when is_binary(url) do
    url
    |> String.replace("kafka+ssl://", "")
    |> String.replace("kafka://", "")
    |> String.split(",")
    |> Enum.map(&url_endpoint_to_tuple/1)
  end

  def parse_overrides(overrides) do
    case Map.get(overrides, :endpoints) do
      nil -> overrides
      endpoints -> Map.put(overrides, :endpoints, parse_endpoints(endpoints))
    end
  end

  def url_endpoint_to_tuple(endpoint) do
    [ip, port] = endpoint |> String.split(":")
    {ip |> String.to_atom(), port |> String.to_integer()}
  end

  def sasl_config(%{mechanism: :plain, login: login, password: password})
      when not is_nil(password) and not is_nil(login),
      do: [sasl: {:plain, login, password}]

  def sasl_config(_), do: []

  def ssl_config do
    ssl_config(client_cert(), client_cert_key())
  end

  def ssl_config(_client_cert = nil, _client_cert_key = nil) do
    []
  end

  def ssl_config(client_cert, client_cert_key) do
    [
      ssl: [
        cert: client_cert,
        key: client_cert_key
      ]
    ]
  end

  def client_cert do
    case System.get_env("KAFKA_CLIENT_CERT") do
      nil -> nil
      cert -> extract_der(cert)
    end
  end

  def client_cert_key do
    case System.get_env("KAFKA_CLIENT_CERT_KEY") do
      nil -> nil
      cert_key -> extract_type_and_der(cert_key)
    end
  end

  def decode_pem(pem) do
    pem
    |> :public_key.pem_decode()
    |> List.first()
  end

  def extract_der(cert) do
    {_type, der, _} = decode_pem(cert)
    der
  end

  def extract_type_and_der(cert_key) do
    {type, der_cert, _} = decode_pem(cert_key)
    {type, der_cert}
  end
end
