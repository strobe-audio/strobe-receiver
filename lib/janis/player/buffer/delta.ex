defmodule Janis.Player.Buffer.Delta do
  @moduledoc "Smear changes to time delta into the smallest increment possible"

  require Logger
  use     Monotonic

  def new(current_delta) do
    %{current: current_delta, pending: 0, d: 0, time: 0}
  end

  def update(new_delta, next_measurement_time, %{current: current, pending: pending} = _state) do
    diff = new_delta - (current + pending)
    t = next_measurement_time - monotonic_milliseconds
    d = (diff / t)
    %{ current: current, pending: diff, d: d, time: monotonic_milliseconds}
  end

  def current(%{current: current, pending: 0} = state) do
    {current, state}
  end

  def current(%{current: current, pending: pending} = state) when pending > 1000 do
    Logger.debug "Applying large time delta #{pending}"
    now = monotonic_milliseconds
    current = current + pending
    pending = 0
    {current, %{state | current: current, pending: pending, time: now}}
  end

  # TODO: use this line-drawing algo to spread the chagnes
  # more evenly:
  #   https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
  def current(%{current: current, pending: pending, d: d, time: t} = state) do
    now = monotonic_milliseconds
    dt  = now - t
    c   = round Float.ceil(d * dt)
    c   = Enum.min [pending, c]
    current = current + c
    pending = pending - c
    {current, %{state | current: current, pending: pending, time: now}}
  end
end

