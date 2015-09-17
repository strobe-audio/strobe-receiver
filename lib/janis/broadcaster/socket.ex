defmodule Janis.Broadcaster.Socket do
  use GenServer
  require Logger

  def start_link(service, address, port, config) do
    GenServer.start_link(__MODULE__, {service, address, port, config})
  end

  def init({service, address, port, config} = broadcaster) do
    Logger.info "Connecting to websocket #{inspect broadcaster}"
    Process.flag(:trap_exit, true)
    %Socket.Web{} = socket = Socket.Web.connect! {address, port}, path: socket_path_with_id(config)
    {:ok, socket}
  end

  def terminate(reason, state) do
    Logger.info "Stopping Broadcaster.Socket"
    :ok
  end

  defp socket_path_with_id(config) do
    "#{config[:socket_path]}?id=#{id}"
  end

  defp id do
    Janis.receiver_id
  end
end
