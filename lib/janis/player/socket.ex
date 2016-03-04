defmodule Janis.Player.Socket do
  @moduledoc """
  A shared base socket implementation
  """

  defmacro __using__(_opts) do
    quote location: :keep do
      use     GenServer
      require Logger

      defmodule S do
        @moduledoc false
        defstruct [:broadcaster, :buffer, :socket]
      end

      def start_link(broadcaster, latency, buffer) do
        GenServer.start_link(__MODULE__, [broadcaster, latency, buffer], [])
      end

      def init([broadcaster, latency, buffer]) do
        Logger.info "Init #{inspect broadcaster} latency: #{ latency }"
        Process.flag(:trap_exit, true)
        {:ok, socket} = connect(broadcaster, latency)
        {:ok, %S{broadcaster: broadcaster, buffer: buffer, socket: socket}}
      end

      def handle_info(event, state) do
        Logger.debug "#{ __MODULE__} unhandled event #{ inspect event }"
        {:noreply, state}
      end

      def terminate(reason, state) do
        Logger.info "Terminate #{ inspect reason }"
        :ok
      end

      def handle_message(message, state) do
        Logger.debug "#{ __MODULE__} unhandled message #{ inspect message }"
        state
      end

      def connect(broadcaster, latency) do
        broadcaster
        |> tcp_connect
        |> catch_connection_error
        |> tcp_configure
        |> register(broadcaster, latency)
      end

      defp catch_connection_error({:error, _reason} = error) do
        Logger.error "Failed to connect #{ inspect error }"
        throw(error)
      end
      defp catch_connection_error(connection) do
        connection
      end

      def register({:ok, socket}, broadcaster, latency) do
        params = broadcaster |> registration_params(latency) |> Poison.encode!
        :gen_tcp.send(socket, params)
        {:ok, socket}
      end

      defp tcp_connect(broadcaster) do
        :gen_tcp.connect(broadcaster.ip, port(broadcaster), [])
      end

      defp tcp_configure({:ok, socket}) do
        :ok = :inet.setopts(socket, mode: :binary, active: true, packet: 4, nodelay: true)
        {:ok, socket}
      end

      def registration_params(broadcaster, latency) do
        %{ id: id }
      end

      def id, do: Janis.receiver_id

      defoverridable [ handle_info: 2, registration_params: 2, handle_message: 2 ]
    end
  end
end
