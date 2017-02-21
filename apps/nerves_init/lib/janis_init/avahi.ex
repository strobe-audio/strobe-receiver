defmodule JanisInit.Avahi do
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Logger.warn "Launching avahi-daemon..."
    daemon = Porcelain.spawn(avahi_daemon(), args())
    dnsconfd = Porcelain.spawn(avahi_dnsconfd(), [])
    Logger.warn inspect([daemon, dnsconfd])
    {:ok, {daemon, dnsconfd}}
  end

  def args do
    ["--debug", "--file=/etc/avahi/avahi-daemon.conf"]
  end
  def cmd do
    "#{avahi_daemon} #{Enum.join(args, " ")}"
  end
  def avahi_daemon do
    System.find_executable("avahi-daemon")
  end
  def avahi_dnsconfd do
    System.find_executable("avahi-dnsconfd")
  end
end
