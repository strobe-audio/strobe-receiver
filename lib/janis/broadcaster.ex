defmodule Janis.Broadcaster do
  use Supervisor

  @supervisor_name Janis.Broadcaster
  @child_name Janis.Broadcaster

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start_broadcaster(service, address, port, config) do
    start_broadcaster(@supervisor_name, service, address, port, config)
  end

  def start_broadcaster(supervisor, service, address, port, config) do
    Supervisor.start_child(supervisor, [service, address, port, config])
  end

  def stop_broadcaster(service) do
    stop_broadcaster(@supervisor_name, service)
  end

  def stop_broadcaster(supervisor, service) do
    Supervisor.which_children(supervisor) |> terminate_broadcasters(supervisor)
  end

  def terminate_broadcasters([child | children], supervisor) do
    case child do
    {_id, :restarting, _worker, _modules} ->
      :ok
    {_id, :undefined, _worker, _modules} ->
      :ok
    {_id, pid, _worker, _modules} ->
      terminate_broadcaster(supervisor, pid)
    end
    terminate_broadcasters(children, supervisor)
  end

  def terminate_broadcasters([], supervisor) do
  end

  def terminate_broadcaster(supervisor, broadcaster) do
    IO.inspect [:terminate_broadcaster, broadcaster]
    :ok = Supervisor.terminate_child(supervisor, broadcaster)
  end

  def translate_packet({_timestamp, _data} = packet) do
    GenServer.call(Janis.Broadcaster.Monitor, {:translate_packet, packet})
  end

  def init(:ok) do
    children = [
      supervisor(Janis.Broadcaster.Supervisor, [], [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end



