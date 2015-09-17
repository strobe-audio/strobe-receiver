defmodule Janis.Broadcaster.Monitor do
  use     GenServer
  require Logger

  def start_link(service, address, port, config) do
    GenServer.start_link(__MODULE__, {service, address, port, config})
  end

  # def init({service, address, port, config} = broadcaster) do
  def init({service, address, port, config} = broadcaster) do
    Logger.info "Starting Broadcaster.Monitor #{inspect broadcaster}"
    {:ok, {}}
  end
end
