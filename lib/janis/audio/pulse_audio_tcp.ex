defmodule Janis.Audio.PulseAudioTCP do
  use     GenServer
  require Logger

  def start_link(name) do
    address = {127,0,0,1}
    port    = 4711
    GenServer.start_link(__MODULE__, {address, port}, name: name)
  end

  def init({address, port}) do
    Logger.info "Connecting to audio on address #{inspect address}:#{port}"
    Process.flag(:trap_exit, true)
    socket  = connect(address, port) |> link_socket
    {:ok, socket}
  end

  defp connect(address, port) do
    case :gen_tcp.connect(address, port, [:inet, :binary, active: true]) do
      {:ok, socket} -> socket
      {:error, :econnrefused} ->
        Logger.warn "============== No audio output... ================"
        nil
    end
  end

  defp link_socket(nil) do
    nil
  end

  defp link_socket(socket) do
    Process.link(socket)
    socket
  end

  def handle_cast({:play, data}, socket) when is_nil(socket) do
    {:noreply, socket}
  end

  def handle_cast({:play, data}, socket) do
    :ok = :gen_tcp.send(socket, data)
    {:noreply, socket}
  end

  def terminate(reason, state) do
    Logger.info "Stopping #{__MODULE__}"
    :ok
  end
end
