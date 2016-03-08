defmodule Janis.Player.Buffer.Delta do
  @moduledoc "Smear changes to time delta into the smallest increment possible"

  require Logger
  use     Monotonic

  defstruct [
    current: 0,
    pending: 0,
    d:       0,
    time:    0,
  ]

  alias __MODULE__, as: S

  def new(current_delta) do
    %S{current: current_delta}
  end

  def update(new_delta, next_measurement_time, %S{current: current, pending: pending} = _state) do
    diff = new_delta - (current + pending)
    t = next_measurement_time - monotonic_milliseconds
    d = (diff / t)
    %S{ current: current, pending: diff, d: d, time: monotonic_milliseconds}
  end

  def current(%S{current: current, pending: 0} = state) do
    {current, state}
  end

  def current(%S{current: current, pending: pending} = state) when pending > 1000 do
    Logger.warn "Applying large time delta #{pending}"
    now = monotonic_milliseconds
    current = current + pending
    pending = 0
    {current, %S{state | current: current, pending: pending, time: now}}
  end

  # TODO: use this line-drawing algo to spread the chagnes
  # more evenly:
  #   https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
  def current(%S{current: current, pending: pending, d: d, time: t} = state) do
    now = monotonic_milliseconds
    dt  = now - t
    c   = round Float.ceil(d * dt)
    c   = Enum.min [pending, c]
    current = current + c
    pending = pending - c
    {current, %S{state | current: current, pending: pending, time: now}}
  end
end

