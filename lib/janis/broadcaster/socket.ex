defmodule Janis.Broadcaster.Socket do
  use GenServer
  require Logger

  @name Janis.Broadcaster.Socket

  defmodule Event do
    @derive [Poison.Encoder]
    defstruct [:topic, :event, payload: %{}, ref: nil]
  end

  defmodule Poll do
    use     GenServer
    require Logger

    def start_link(parent, socket) do
      GenServer.start_link(__MODULE__, [parent, socket], [])
    end

    def init([parent, socket]) do
      Logger.debug "Starting #{__MODULE__}"
      state = start_task(%{parent: parent, socket: socket, task: nil})
      {:ok, state}
    end

    defp start_task(%{socket: socket, task: nil} = state) do
      task = Task.async fn -> Socket.Web.recv!(socket) end
      %{ state | task: task }
    end

    defp start_task(state) do
      Logger.warn "Task already running..."
      state
    end

    # Callback from our Task
    def handle_info({_task, event}, %{ task: task } = state) do
      process_event(event, state)
      {:noreply, %{state | task: nil}}
    end

    def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
      {:noreply, start_task(state)}
    end

    defp process_event({:text, msg}, %{parent: parent} = _state) do
      event = Poison.decode! msg, as: Event
      GenServer.cast(parent, {:event, event})
    end

    defp process_event(event, %{parent: parent} = _state) do
      Logger.debug "Got event #{inspect event}"
      GenServer.cast(parent, {:event, event})
    end
  end

  def join(%{latency: _latency} = connection) do
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
