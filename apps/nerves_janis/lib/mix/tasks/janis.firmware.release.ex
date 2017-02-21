defmodule Mix.Tasks.Janis.Firmware.Release do
  use Mix.Task

  alias ExAws.S3

  @shortdoc "Builds and uploads firmware"

  def run(_args) do
    start_applications()
    version = version()
    IO.puts "Firmware version #{system()}:#{version}\n"
    # Ensure that the firmware version baked into the code is the same as we
    # are using
    System.put_env("JANIS_FIRMWARE_VERSION", version)
    Mix.Task.run "firmware"
    copy_firmware(system, version)
    upload_firmware(system, version)
    upload_metadata(system, version)
  end

  defp copy_firmware(system, version) do
    IO.inspect "Copying firmware from #{firmware_path(system)} to #{firmware_path(system, version)}"
    :ok = File.cp(firmware_path(system), firmware_path(system, version))
    firmware_path(system, version)
  end

  defp upload_firmware(system, version) do
    firmware_path(system, version)
    |> S3.Upload.stream_file
    |> S3.upload("janis-firmware-releases", firmware_key(system, version), content_type: "application/x-firmware", acl: :private)
    |> ExAws.request!
  end

  defp upload_metadata(system, version) do
    S3.put_object("janis-firmware-releases", metadata_key(system), metadata(system, version), content_type: "application/json", acl: :public_read)
    |> ExAws.request!
  end

  defp firmware_key(system, version) do
    "firmware/#{system}/#{version}.fw"
  end

  defp firmware_path(system, version \\ "nerves_janis") do
    Path.expand("_images/#{system}/#{version}.fw")
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

  defp start_applications do
    [:poison, :hackney, :sweet_xml] |> Enum.each(&Application.ensure_all_started/1)
  end

  defp metadata_key(system) do
    "firmware/#{system}.json"
  end

  defp metadata(system, version) do
    %{ version: version, system: system} |> Poison.encode!(pretty: true)
  end
end
