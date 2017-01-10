defmodule Janis.SSDP do
  use     GenServer
  require Logger
  alias   Nerves.SSDPClient

  @service_uuid "ba31231a-5aee-11e6-8407-002500f418fc"

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    Janis.set_logger_metadata
    poll(1)
    {:ok, nil}
  end

  def handle_info(:discover, state) do
    state = find_broadcaster(state)
    poll()
    {:noreply, state}
  end

  defp service_name do
    "uuid:#{@service_uuid}::urn:com.peepaudio:broadcaster"
  end

  defp target do
    "urn:com.peepaudio:broadcaster"
  end

  defp find_broadcaster(service) do
    discover() |> match |> monitor(service)
  end

  # offline
  defp monitor(nil, nil) do
    nil
  end
  # service has come online
  defp monitor(service, nil) when not is_nil(service) do
    GenEvent.notify(Janis.Broadcaster.Event, {:online, :ssdp, broadcaster(service)})
    service
  end
  # service has gone offline
  defp monitor(nil, service) when not is_nil(service) do
    GenEvent.notify(Janis.Broadcaster.Event, {:offline, :ssdp, broadcaster(service)})
    nil
  end
  # service still online
  defp monitor(service, service) do
    service
  end
  # two broadcasters on network
  defp monitor(_another_service, service) do
    service
  end

  defp match(services) do
    services[service_name()]
  end

  defp discover do
    SSDPClient.discover(target: target())
  end

  defp poll(delay \\ 1000)
  defp poll(delay) do
    Process.send_after(self(), :discover, delay)
  end

  def broadcaster(service) do
    struct(Janis.Broadcaster, parse_texts(service)) |> Janis.Broadcaster.resolve
  end

  defp parse_texts(texts) do
    Keyword.new texts, &parse_text/1
  end

  @integer_keys [:"ctrl_port", :"data_port", :"stream_interval", :"packet_size", :port]

  defp parse_text({key, value})
  when key in @integer_keys do
    {key, String.to_integer(value)}
  end
  defp parse_text({key, value}) do
    {key, value}
  end
end
