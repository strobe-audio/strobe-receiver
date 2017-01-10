defmodule Janis.Broadcaster.Event do
  use GenServer
  require Logger

  defmodule Handler do
    use GenEvent
    def handle_event({state, source, broadcaster}, owner) when state in [:online, :offline] do
      GenServer.cast(owner, {state, source, broadcaster})
      {:ok, owner}
    end
  end

  defmodule S do
    defstruct [:manager, :broadcaster, :pid]
  end

  def start_link(manager) do
    GenServer.start_link(__MODULE__, manager)
  end

  def init(manager) do
    Janis.set_logger_metadata
    GenEvent.add_mon_handler(manager, Handler, self())
    {:ok, %S{manager: manager}}
  end

  def handle_cast({:online, source, broadcaster}, %S{broadcaster: nil} = state) do
    {:ok, pid} = start_and_link_broadcaster(source, broadcaster)
    {:noreply, %S{state | broadcaster: broadcaster, pid: pid}}
  end
  def handle_cast({:online, _source, _broadcaster}, state) do
    {:noreply, state}
  end
  def handle_cast({:offline, _source, broadcaster}, %S{broadcaster: broadcaster} = state) do
    # Stop broadcaster instance
    {:noreply, %S{state | broadcaster: nil}}
  end
  def handle_cast({:offline, _source, _broadcaster}, state) do
    {:noreply, state}
  end


  def handle_info({:DOWN, _ref, :process, pid, reason}, %S{pid: pid} = state) do
    Logger.warn "Broadcaster terminated #{ inspect reason }"
    {:noreply, %S{state | pid: nil, broadcaster: nil}}
  end

  defp start_and_link_broadcaster(source, broadcaster) do
    Logger.info "Starting broadcaster #{source} -> #{ inspect broadcaster }"
    pid = case Janis.Broadcaster.start_broadcaster(broadcaster) do
      {:ok, pid} ->
        Process.monitor(pid)
        pid
      {:error, {:already_started, pid}} ->
        pid
    end
    {:ok, pid}
  end
end
