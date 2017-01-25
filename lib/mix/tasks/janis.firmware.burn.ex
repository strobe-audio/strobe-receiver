defmodule Mix.Tasks.Janis.Firmware.Burn do
  use Mix.Task

  @shortdoc "Builds and burns firmware with a set version"

  def run(_args) do
    Mix.Task.run("janis.firmware")
    Mix.Task.run("firmware.burn", ["--task", "complete"])
  end
end

