defmodule JanisInit.Avahi do
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Logger.warn "Launching avahi-daemon..."
    daemon = Port.open({:spawn, avahi_daemon()}, [:binary, parallelism: true])
    dnsconfd = Port.open({:spawn, avahi_dnsconfd()}, [:binary, parallelism: true])
    Logger.warn inspect([daemon, dnsconfd])
    {:ok, {daemon, dnsconfd}}
  end

  def args do

  end
  def cmd(exe, args) do
    "#{exe} #{Enum.join(args, " ")}"
  end
  def avahi_daemon do
    cmd(System.find_executable("avahi-daemon"),  ["--debug", "--file=/etc/avahi/avahi-daemon.conf"])
  end
  def avahi_dnsconfd do
    System.find_executable("avahi-dnsconfd")
  end
end
