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
        Socket.Stream.recv!(socket) |> process_event(state)
      end
      loop(state)
    end

    defp process_event(event, {parent, _socket} = state) do
      Logger.deug "Got event #{inspect event}"
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
    Logger.info "Stopping Broadcaster.Socket"
    :ok
  end

  def handle_cast({:join, %{latency: latency} = connection}, socket) do
    msg = Poison.encode!(event(%Event{event: "phx_join", ref: "1", payload: connection}))
    IO.inspect [:join, msg]
    Socket.Web.send! socket, { :text, msg }
    {:noreply, socket}
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
end
