defmodule Janis do
  require Logger
  def start(_type, _args) do
    IO.inspect [:Janis, :start]
    Janis.Supervisor.start_link
  end

  def milliseconds do
    :erlang.monotonic_time(:milli_seconds)
  end
  def microseconds do
    :erlang.monotonic_time(:micro_seconds)
  end

  def broadcaster_connect(service, address, port, config) do
    Logger.info "Broadcaster ONLINE     #{address}:#{port} #{inspect config}"
    Janis.Broadcasters.start_broadcaster(service, address, port, config)
  end

  def broadcaster_disconnect(service) do
    Logger.info "Broadcaster DISCONNECT #{inspect service}"
    Janis.Broadcasters.stop_broadcaster(service)
  end

  def receiver_id do
    id_from_ifs(:inet.getifaddrs)
  end

  defp id_from_ifs({:ok, ifs}) do
    List.first(valid_ifs(ifs)) |> id_from_if
  end

  defp valid_ifs(ifs) do
    Enum.filter ifs, fn({_name, opts}) ->
      valid_if_flags?(opts) && valid_if_addrs?(opts)
    end
  end

  @required_if_flags Enum.into([:up, :broadcast, :running, :multicast], HashSet.new)
  @invalid_if_flags  Enum.into([:loopback, :pointtopoint], HashSet.new)

  defp valid_if_flags?(opts) do
    flags = Enum.into(opts[:flags], HashSet.new)
    Set.subset?(@required_if_flags, flags) && Set.disjoint?(@invalid_if_flags, flags)
  end

  defp valid_if_addrs?(opts) do
    Enum.all? [:addr, :netmask, :broadaddr], fn(key) ->
      Keyword.has_key?(opts, key)
    end
  end

  defp id_from_if({_name, opts} = if) do
    Enum.map(opts[:hwaddr], fn(b) ->
      Integer.to_string(b, 16) |> String.downcase |> String.rjust(2, ?0)
    end) |> Enum.join("-")
  end
end
