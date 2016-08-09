defmodule JanisInit.Chrt do
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Logger.warn "Changing real-time priority #{cmd()}"
    IO.inspect System.cmd(executable(), args())
    # daemon = Porcelain.spawn(avahi_daemon(), args())
    # dnsconfd = Porcelain.spawn(avahi_dnsconfd(), [])
    # Logger.warn inspect([daemon, dnsconfd])
    {:ok, {}}
  end

  def cmd do
    "#{executable()} #{Enum.join(args, " ")}"
  end
  def args do
    ["-r", "-p", "99", :os.getpid()]
  end
  def executable do
    System.find_executable("chrt")
  end
end
