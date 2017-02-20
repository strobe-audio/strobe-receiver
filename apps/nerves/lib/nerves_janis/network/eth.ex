defmodule NervesJanis.Network.Eth do
  use GenServer

  require Logger

  defmodule Handler do
    use GenEvent

    def handle_event(event, parent) do
      send(parent, event)
      {:ok, parent}
    end
  end

  def start_link(dev \\ "eth0") do
    GenServer.start_link(__MODULE__, dev, name: __MODULE__)
  end

  def init(dev) do
    Logger.info "Starting #{__MODULE__}:#{dev}"
    Nerves.NetworkInterface.event_manager |> GenEvent.add_handler(Handler, self())
    send(self(), :setup)
    {:ok, dev}
  end

  def handle_info(:setup, dev) do
    Nerves.Networking.setup(String.to_atom(dev), [mode: "dhcp"])
    {:noreply, dev}
  end

  def handle_info({:nerves_network_interface, _, :ifchanged, %{ifname: dev} = event}, dev) do
    Logger.debug "nerves_network_interface:ifchanged #{dev} #{inspect event}"
    device_changed(dev, ethernet_carrier?(), event)
    {:noreply, dev}
  end
  def handle_info(_evt, dev) do
    {:noreply, dev}
  end

  defp device_changed(dev, true, _evt) do
    Logger.info "Ethernet connection #{dev} online"
    NervesJanis.Network.Wlan.disable
  end
  defp device_changed(dev, false, _evt) do
    Logger.info "Ethernet connection #{dev} offline"
    NervesJanis.Network.Wlan.enable
  end

  defp ethernet_carrier? do
    carrier = File.stream!("/sys/class/net/eth0/carrier", [:read, :utf8], :line)
    case Enum.map(carrier, &String.trim_trailing/1) |> IO.iodata_to_binary do
      "1" -> true
      _   -> false
    end
  end
end
