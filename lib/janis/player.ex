defmodule Janis.Player do
  use Supervisor

  @supervisor_name Janis.Player

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start_player(address, stream_info) do
    start_player(@supervisor_name, address, stream_info)
  end

  def start_player(supervisor, address, stream_info) do
    Supervisor.start_child(supervisor, [address, stream_info])
  end

  def stop_player do
    stop_player(@supervisor_name)
  end

  def stop_player(supervisor) do
    Supervisor.which_children(supervisor) |> terminate_players(supervisor)
  end

  def terminate_players([child | children], supervisor) do
    case child do
    {_id, :restarting, _worker, _modules} ->
      :ok
    {_id, :undefined, _worker, _modules} ->
      :ok
    {_id, pid, _worker, _modules} ->
      terminate_player(supervisor, pid)
    end
    terminate_players(children, supervisor)
  end

  def terminate_players([], _supervisor) do
  end

  def terminate_player(supervisor, player) do
    :ok = Supervisor.terminate_child(supervisor, player)
  end

  def init(:ok) do
    children = [
      supervisor(Janis.Player.Supervisor, [], [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end



