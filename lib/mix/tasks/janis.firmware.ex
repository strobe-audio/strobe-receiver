defmodule Mix.Tasks.Janis.Firmware do
  use Mix.Task

  alias ExAws.S3

  @shortdoc "Builds firmware with a set version"

  def run(_args) do
    version = version()
    IO.puts "Firmware version #{system()}:#{version}\n"
    # Ensure that the firmware version baked into the code is the same as we
    # are using
    System.put_env("JANIS_FIRMWARE_VERSION", version)
    Mix.Task.run("firmware")
  end

  defp system do
    NervesJanis.Mixfile.target
  end

  defp version do
    [:year, :month, :day, :hour, :minute, :second]
      |> Enum.map(&Map.get(now(), &1, 0))
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.pad_leading(&1, 2, "0"))
      |> Enum.join("")
  end

  defp now, do: DateTime.utc_now
end
