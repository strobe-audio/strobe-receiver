defmodule Janis.Broadcasters do
  use Supervisor

  @supervisor_name Janis.Broadcasters

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start_broadcaster(service, address, port, config) do
    start_broadcaster(@supervisor_name, service, address, port, config)
  end

  def start_broadcaster(supervisor, service, address, port, config) do
    Supervisor.start_child(supervisor, [service, address, port, config])
  end

  def init(:ok) do
    children = [
      supervisor(Janis.Broadcaster.Supervisor, [], [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end



