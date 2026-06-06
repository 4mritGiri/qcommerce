defmodule Qcommerce.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QcommerceWeb.Telemetry,
      Qcommerce.Repo,
      {DNSCluster, query: Application.get_env(:qcommerce, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Qcommerce.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Qcommerce.Finch},
      # Start a worker by calling: Qcommerce.Worker.start_link(arg)
      # {Qcommerce.Worker, arg},
      # Start to serve requests, typically the last entry
      QcommerceWeb.Endpoint,
      Qcommerce.Delivery.RiderTracker
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Qcommerce.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Qcommerce.Settings.ensure_cache()
        {:ok, pid}
      other ->
        other
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QcommerceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
