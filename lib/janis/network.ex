defmodule Janis.Network do
  use Bitwise

  @doc """
  Given a hostname that resolves to a set if IP address, return the best IP
  address to use based on our list of 'sane' network interfaces
  """
  def lookup(hostname) do
    {:ok, ips, _} = gethostbyname(hostname)
    best_ip(ips, local_interfaces)
  end

  @doc ~S"""
      iex> Janis.Network.best_ip(
      ...>   [{192, 168, 1, 99}, {10, 0, 0, 1}],
      ...>   [
      ...>     {'en0', [addr: {192, 168, 1, 98}, netmask: {255, 255, 255, 0}]},
      ...>     {'en1', [hwaddr: [0, 23, 242, 9, 32, 157]]}
      ...>   ]
      ...> )
      {:ok, {192, 168, 1, 99}}
  """
  def best_ip(ips, ifs) do
    {iface, ip} = ips |> Enum.map(&bind_interface(&1, ifs)) |> Enum.zip(ips) |> Enum.reject(fn
      {:error, _} -> true
      _ -> false
    end) |> List.first
    {:ok, ip}
  end

  @doc """
  Given a partciular host on the .local network, what's the best ip
  address to bind to in order to access it
  """
  def bind_address(host) do
    iface = bind_interface(host)
    {ip, netmask} = ip_and_network(iface)
    {:ok, ip}
  end

  @doc """
  Given a particular host on the .local domain, what's the best interface
  to bind to in order to connect to it?

  If a host resolves to multiple IPs and we have multiple ifaces that could
  connect to it we just return the first...
  """
  def bind_interface(host) when is_binary(host) do
    {:ok, ips, _} = gethostbyname(host)
    bind_interface(ips)
  end

  def bind_interface(ip) do
    bind_interface(ip, local_interfaces)
  end

  @doc ~S"""

      iex> Janis.Network.bind_interface(
      ...>   [{192, 168, 1, 99}, {10, 0, 0, 1}],
      ...>   [
      ...>     {'en0', [addr: {192, 168, 1, 98}, netmask: {255, 255, 255, 0}]},
      ...>     {'en1', [addr: {10, 0, 0, 10}, netmask: {255, 255, 255, 0}]}
      ...>   ]
      ...> )
      {'en0', [addr: {192, 168, 1, 98}, netmask: {255, 255, 255, 0}]}

      iex> Janis.Network.bind_interface(
      ...>   [{192, 168, 1, 99}, {10, 0, 0, 1}],
      ...>   [
      ...>     {'en1', [addr: {10, 0, 0, 10}, netmask: {255, 255, 255, 0}]}
      ...>   ]
      ...> )
      {'en1', [addr: {10, 0, 0, 10}, netmask: {255, 255, 255, 0}]}

      iex> Janis.Network.bind_interface({192, 168, 1, 99}, [
      ...>   {'en0', [addr: {192, 168, 1, 98}, netmask: {255, 255, 255, 0}]},
      ...>   {'en1', [addr: {10, 0, 0, 10}, netmask: {255, 255, 255, 0}]}
      ...> ])
      {'en0', [addr: {192, 168, 1, 98}, netmask: {255, 255, 255, 0}]}

      iex> Janis.Network.bind_interface({10, 0, 1, 1}, [
      ...>   {'en0', [addr: {192, 168, 1, 98}, netmask: {255, 255, 255, 0}]}
      ...> ])
      :error

  """
  def bind_interface(ips, ifs) when is_list(ips) do
    bind = ips |> Enum.map(&bind_interface(&1, ifs)) |> Enum.filter(fn
      :error -> false
      _      -> true
    end) |> List.first
  end

  def bind_interface(ip, ifs) when is_tuple(ip) do
    case ifs |> Enum.filter(&interface_for_network?(&1, ip)) do
      [] -> :error
      [iface | _t] -> iface
    end
  end

  @doc """
  A friendly version of :inet.gethostbyname

      iex> Janis.Network.gethostbyname "magnetised.net"
      {:ok, [{89, 16, 174, 87}], {'magnetised.net', [], :inet, 4}}

  """
  def gethostbyname(host) when is_binary(host) do
    host |> String.to_char_list |> gethostbyname
  end
  def gethostbyname(host) do
    {:ok, record} = :inet.gethostbyname(host)
    {:hostent, name, aliases, type, length, addresses} = record
    {:ok, addresses, {name, aliases, type, length}}
  end

  @doc ~S"""
  Convert a ip quad to an integer

      iex> Janis.Network.ip_to_int({1, 2, 3, 4})
      16909060
      iex> Janis.Network.ip_to_int({192, 168, 1, 1})
      3232235777

  """
  def ip_to_int({a, b, c, d}) do
    (a <<< 24) + (b <<< 16) + (c <<< 8) + d
  end

  @doc ~S"""
  Given the IP of a remote server and a network interface definition calculates
  if the given interface can connect to the remote server

      iex> Janis.Network.interface_for_network?(
      ...>   {'en0', [addr: {192, 168, 1, 98}, netmask: {255, 255, 255, 0}]},
      ...>   {192, 168, 1, 23}
      ...> )
      true
      iex> Janis.Network.interface_for_network?(
      ...>   {'en0', [addr: {192, 168, 1, 98}, netmask: {255, 255, 0, 0}]},
      ...>   {192, 168, 2, 23}
      ...> )
      true
      iex> Janis.Network.interface_for_network?(
      ...>   {'en0', [addr: {10, 0, 0, 1}, netmask: {255, 255, 255, 0}]},
      ...>   {192, 168, 1, 23}
      ...> )
      false
      iex> Janis.Network.interface_for_network?(
      ...>   {'stf0', []},
      ...>   {192, 168, 1, 23}
      ...> )
      false

  """
  def interface_for_network?(iface, ip) do
    case ip_and_network(iface) do
      {if_ip, if_net} ->
        if_net = ip_to_int(if_net)
        if_ip  = ip_to_int(if_ip)
        ip     = ip_to_int(ip)

        (if_ip &&& if_net) == (ip &&& if_net)
      :error -> false
    end
  end

  @doc ~S"""
  Returns the IPv4 address and netmask for the given interface


      iex> Janis.Network.ip_and_network({'en1',
      ...> [flags: [:up, :broadcast, :running, :multicast],
      ...>  hwaddr: [0, 23, 242, 9, 32, 157],
      ...>  addr: {65152, 0, 0, 0, 535, 62207, 65033, 8349},
      ...>  netmask: {65535, 65535, 65535, 65535, 0, 0, 0, 0}, addr: {192, 168, 1, 173},
      ...>  netmask: {255, 255, 255, 0}, broadaddr: {192, 168, 1, 255}]})
      {{192, 168, 1, 173},  {255, 255, 255, 0}}

  """
  def ip_and_network({_name, params} = _if) do
    ip = params |> Enum.filter fn
      {:addr, addr} -> ip_v4?(addr)
      _ -> false
    end
    net = params |> Enum.filter fn
      {:netmask, mask} -> ip_v4?(mask)
      _ -> false
    end
    case {ip, net} do
      {[], []} -> :error
      {[{:addr, ip}], [{:netmask, net}]} -> {ip, net}
    end
  end

  @doc """
  Tests if the given tuple defines an IPv4 address

      iex> Janis.Network.ip_v4?({255, 255, 255, 0})
      true
      iex> Janis.Network.ip_v4?({192, 168, 1, 255})
      true
      iex> Janis.Network.ip_v4?({65535, 65535, 65535, 65535, 0, 0, 0, 0})
      false
      iex> Janis.Network.ip_v4?({65152, 0, 0, 0, 535, 62207, 65033, 8349})
      false
  """
  def ip_v4?({_, _, _, _}) do
    true
  end
  def ip_v4?(_) do
    false
  end

  def interfaces do
    {:ok, ifs} = :inet.getifaddrs
    ifs
  end

  @doc ~S"""
  Gives back a list of the 'local' interfaces available on the current machine

      iex> Janis.Network.local_interfaces([{'lo0', []}, {'en1', []}, {'tap0', []}])
      [{'lo0', []}, {'en1', []}]

  """
  def local_interfaces(ifs \\ interfaces) do
    ifs |> Enum.filter &local_interface?/1
  end

  def interfaces_with_ip(ifs \\ interfaces) do
    ifs |> Enum.filter fn({_name, attrs}) ->
      attrs |> Enum.any? fn
        {:addr, _addr} -> true
        _ -> false
      end
    end
  end

  @doc ~S"""
  Converts a ipv4 address tuple into a dotted quad string

      iex> Janis.Network.ntoa({123, 123, 2, 1})
      "123.123.2.1"

  """
  def ntoa(addr) when is_tuple(addr) do
    :inet.ntoa(addr) |> to_string
  end


  @doc ~S"""
  Filters out VPN tap/tun interfaces plus other oddities

      iex> Janis.Network.local_interface?({'en0', []})
      true
      iex> Janis.Network.local_interface?({'lo0', []})
      true
      iex> Janis.Network.local_interface?({'gif0', []})
      false
      iex> Janis.Network.local_interface?({'tun0', []})
      false
      iex> Janis.Network.local_interface?({'tun9', []})
      false
      iex> Janis.Network.local_interface?({'tap0', []})
      false
      iex> Janis.Network.local_interface?({'tap1', []})
      false
      iex> Janis.Network.local_interface?({'fw0', []})
      false

  """
  def local_interface?({name, _attrs}) do
    local_interface?(to_string(name))
  end
  for n <- ~w(tap tun gif fw) do
    def local_interface?(unquote(n) <> _id), do: false
  end
  def local_interface?(name), do: true
end
