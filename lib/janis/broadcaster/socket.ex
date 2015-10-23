defmodule Janis.Broadcaster.Socket do
  use GenServer
  require Logger

  @name Janis.Broadcaster.Socket

  defmodule Event do
    @derive [Poison.Encoder]
    defstruct [:topic, :event, payload: %{}, ref: nil]
  end

  defmodule Poll do
    require Logger

    def start_link(parent, socket) do
      :proc_lib.start_link(__MODULE__, :init, [parent, socket])
    end

    def init(parent, socket) do
      Logger.debug "starting poll"
      Process.flag(:trap_exit, true)
      :proc_lib.init_ack({:ok, self})
      state = {parent, socket}
      loop(state)
    end

    def loop({_parent, socket} = state) do
      receive do
      after 0 ->
        Logger.debug "Waiting for message..."
        Socket.Web.recv!(socket) |> process_event(state)
      end
      loop(state)
    end

    defp process_event({:text, msg}, {parent, _socket} = state) do
      event = Poison.decode! msg, as: Event
      GenServer.cast(parent, {:event, event})
    end

    defp process_event(event, {parent, _socket} = state) do
      Logger.debug "Got event #{inspect event}"
      GenServer.cast(parent, {:event, event})
    end
  end

  def join(%{latency: _latency} = connection) do
    IO.inspect [Socket, :join, id]
    GenServer.cast(@name, {:join, connection})
  end

  def start_link(service, address, port, config) do
    GenServer.start_link(__MODULE__, {service, address, port, config}, name: @name)
  end

  def init({service, address, port, config} = broadcaster) do
    Logger.info "Connecting to websocket #{inspect broadcaster}"
    Process.flag(:trap_exit, true)
    %Socket.Web{} = socket = Socket.Web.connect! {address, port}, path: socket_path_with_id(config)
    Poll.start_link(self, socket)
    {:ok, socket}
  end

  def terminate(reason, state) do
    Logger.info "Stopping #{__MODULE__} #{ inspect reason }"
    :ok
  end

  def handle_cast({:join, %{latency: latency} = connection}, socket) do
    msg = Poison.encode!(event(%Event{event: "phx_join", ref: "1", payload: connection}))
    Socket.Web.send! socket, { :text, msg }
    {:noreply, socket}
  end

  def handle_cast({:event, %Event{event: "join_zone", payload: config} = event}, state) do
    Logger.debug "JOIN ZONE #{inspect config}"
    join_zone(config)
    {:noreply, state}
  end

  def handle_cast({:event, %Event{event: "set_volume", payload: %{"volume" => volume}}} = _event, state) do
    :ok = Janis.Audio.volume(volume)
    {:noreply, state}
  end

  def handle_cast({:event, event}, state) do
    Logger.debug "Event #{inspect event}"
    {:noreply, state}
  end

  defp event(%Event{} = event) do
    %Event{ event | topic: topic }
  end

  defp topic do
    "receiver:#{id}"
  end

  defp socket_path_with_id(config) do
    "#{config[:socket_path]}?id=#{id}"
  end

  defp id do
    Janis.receiver_id
  end

  defp join_zone(%{"address" => address, "port" => port, "interval" => packet_interval, "size" => packet_size, "volume" => volume}) do
    address = List.to_tuple(address)
    IO.inspect [:join, address, port, packet_interval, packet_size, volume]
    :ok = Janis.Audio.volume(volume)
    {:ok, pid} = Janis.Player.start_player({address, port}, {packet_interval, packet_size})
  end

  # Handle missing volume param
  defp join_zone(config) do
    join_zone(Map.put(config, "volume", 1.0))
  end
end
