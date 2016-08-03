defmodule NervesJanis do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # worker(NervesJanis.Worker, [arg1, arg2, arg3]),
      worker(Task, [fn -> start_networking(:os.type, :eth0) end], restart: :transient),
      # worker(NervesJanis.Dbus.Uuidgen, []),
      worker(NervesJanis.Dbus, []),
      worker(NervesJanis.Avahi, []),
      # supervisor(Janis.Supervisor, []),
    ]


    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NervesJanis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_networking({:unix, :darwin}, _iface), do: :ok
  def start_networking(_os, iface)  do
    {:ok, _} = Nerves.Networking.setup iface, [mode: "dhcp"]
  end
end
