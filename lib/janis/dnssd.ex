defmodule Janis.DNSSD do
  use     GenServer
  require Logger

  @name         Otis.DNSSD
  @service_name "_peep-broadcaster._tcp"

  defmodule S do
    @moduledoc false

    defstruct [:browser, :broadcaster]
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    Process.flag(:trap_exit, true)
    browser = case IO.inspect(:dnssd.browse(@service_name)) do
      {:ok, browser} ->
        browser
      {:error, error} ->
        Logger.warn "Unable to start DNSSD browser: Error #{error}"
        nil
    end
    {:ok, %S{browser: browser}}
  end

  def terminate(reason, %{browser: browser} = _state) do
    Logger.warn "Terminate #{inspect reason}"
    :dnssd.stop(browser)
    :ok
  end

  def handle_info({:dnssd, _ref, msg}, state) do
    state = case dnssd_resolve(msg, state) do
      {:ok, broadcaster} ->
        GenEvent.notify(Janis.Broadcaster.Event, {:online, :dnssd, broadcaster})
        Logger.info "Broadcaster up #{ inspect broadcaster}"
        %S{ state | broadcaster: broadcaster }
      :down ->
        Logger.warn "Broadcaster service offline"
        GenEvent.notify(Janis.Broadcaster.Event, {:offline, :dnssd, state.broadcaster})
        %S{ state | broadcaster: nil }
      {:conflict, event} ->
        Logger.warn "Multiple broadcasters on network, ignoring #{ to_string(event) }..."
        state
    end
    {:noreply, state}
  end

  defp dnssd_resolve({:browse, :add, {service_name, service_type, domain} = service}, %S{broadcaster: nil}) do
    :dnssd.resolve_sync(service_name, service_type, domain)
    |> broadcaster(service)
  end
  defp dnssd_resolve({:browse, :add, _service}, _state) do
    {:conflict, :add}
  end

  defp dnssd_resolve({:browse, :remove, _service}, _state) do
    :down
  end

  defp broadcaster({:ok, {address, port, texts}}, _service) do
    config = parse_texts(texts)
    broadcaster = struct(%Janis.Broadcaster{host: address, port: port}, config) |> Janis.Broadcaster.resolve
    {:ok, broadcaster}
  end

  defp parse_texts(texts) do
    Keyword.new texts, &parse_text/1
  end

  @integer_keys ["ctrl_port", "data_port", "stream_interval", "packet_size"]

  defp parse_text({key, value})
  when key in @integer_keys do
    {String.to_atom(key), String.to_integer(value)}
  end
  defp parse_text({key, value}) do
    {String.to_atom(key), value}
  end
end
