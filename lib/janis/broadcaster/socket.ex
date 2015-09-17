defmodule Janis.Broadcaster.Socket do
  use GenServer
  require Logger

  def start_link(service, address, port, config) do
    GenServer.start_link(__MODULE__, {service, address, port, config})
  end

  def init({service, address, port, config} = broadcaster) do
    # server = {List.to_string(:inet.ntoa(address)), port}
    Logger.info "Connecting to websocket #{inspect broadcaster}"
    %Socket.Web{} = socket = Socket.Web.connect! {address, port}, path: socket_path_with_id(config)
    {:ok, socket}
  end

  defp socket_path_with_id(config) do
    "#{config[:socket_path]}?id=#{id}"
  end

  defp id do
    Janis.receiver_id
  end
end
