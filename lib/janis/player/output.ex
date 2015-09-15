defmodule Janis.Player.Output do
  use     GenServer
  require Logger

  @name Janis.Player.Output
  def start_link(address \\ {127,0,0,1}, port \\ 4711) do
    GenServer.start_link(__MODULE__, {address, port}, name: @name)
  end

  def init({address, port}) do
    Logger.info "Connecting to audio on address #{inspect address}:#{port}"
    socket = case :gen_tcp.connect(address, port, [:inet, :binary, active: true]) do
      {:ok, socket} -> socket
      {:error, :econnrefused} ->
        Logger.warn "No audio output..."
        nil
    end
    {:ok, socket}
  end

  def send(data) do
    GenServer.cast(@name, {:send, data})
  end

  def handle_cast({:send, data}, socket) when is_nil(socket) do
    {:noreply, socket}
  end

  def handle_cast({:send, data}, socket) do
    :ok = :gen_tcp.send(socket, data)
    {:noreply, socket}
  end
end
