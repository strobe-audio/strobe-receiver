defmodule JanisInit do
  use Application
  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      worker(JanisInit.Alsa, []),
      worker(Task, [fn -> start_networking(:os.type, :eth0) end], restart: :transient),
      # worker(JanisInit.Dbus, []),
      worker(JanisInit.Avahi, []),
      worker(JanisInit.Chrt, [], restart: :transient),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JanisInit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_networking({:unix, :darwin}, _iface), do: :ok
  def start_networking(_os, iface)  do
    Logger.warn "start networking..."
    {:ok, _} = Nerves.Networking.setup iface, [mode: "dhcp", on_change: fn(changes) ->
      Logger.warn "networking change #{inspect(changes)}"
    end]
  end
end
