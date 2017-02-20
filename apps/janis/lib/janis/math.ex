defmodule Janis.Math do
  defprotocol MovingAverage do

    @type t :: Janis.Math.MovingAverage

    @doc "Update the average with a new value"
    def update(avg, value)

    @doc "Get the current smoothed average"
    def average(avg)
  end

  defmodule ExponentialMovingAverage do
    defstruct alpha: 1.0, n: 0, a: 0

    alias __MODULE__, as: A

    def new(alpha) do
      %A{alpha: alpha}
    end

    def update(%A{ n: 0 } = ema, v) do
      increment(%A{ema | a: v})
    end

    def update(%A{alpha: alpha, a: a} = ema, v) do
      a_t = (alpha * v) + ((1.0 - alpha) * a)
      increment(%A{ ema | a: a_t })
    end

    def average(%A{} = ema), do: ema.a

    defp increment(ema) do
      %A{ ema | n: ema.n + 1 }
    end
  end


  defimpl MovingAverage, for: ExponentialMovingAverage do
    def update(avg, value), do: ExponentialMovingAverage.update(avg, value)
    def average(avg), do: ExponentialMovingAverage.average(avg)
  end

  # https://en.wikipedia.org/wiki/Exponential_smoothing#Double_exponential_smoothing
  defmodule DoubleExponentialMovingAverage do
    defstruct alpha: 1.0, beta: 1.0, n: 0, s: 0, b: 0, bb: [], ss: []

    @stabilisation_period 50

    alias __MODULE__, as: A

    # α is the data smoothing factor, 0 < α < 1
    # β is the trend smoothing factor, 0 < β < 1
    def new(alpha, beta) do
      %A{alpha: alpha, beta: beta}
    end

    def update(%A{ n: 0 } = ema, v) do
      increment(%A{ema | s: v, b: v, bb: [], ss: [v]})
    end

    def update(%A{ n: n } = ema, v) when n < @stabilisation_period do
      ss = [ v | ema.ss ]
      s_t = Enum.sum(ema.ss) / n
      bb = [ s_t - ema.s | ema.bb ]
      b_t = Enum.sum(ema.bb) / n
      increment(%A{ema | s: s_t, b: b_t, bb: bb, ss: ss})
    end

    def update(%A{ n: n } = ema, v) when n == @stabilisation_period do
      _update(%A{ ema | bb: [], ss: []}, v)
    end

    def update(ema, v) do
      _update(ema, v)
    end

    defp _update(%A{alpha: alpha, beta: beta, s: s, b: b} = ema, v) do
      s_t = (alpha * v) + (1.0 - alpha) * (s + b)
      b_t = beta * (s_t - s) + (1.0 - beta) * b
      increment(%A{ ema | s: s_t, b: b_t })
    end

    def average(%A{} = ema), do: ema.s

    defp increment(ema) do
      %A{ ema | n: ema.n + 1 }
    end
  end
  defimpl MovingAverage, for: DoubleExponentialMovingAverage do
    def update(avg, value), do: DoubleExponentialMovingAverage.update(avg, value)
    def average(avg), do: DoubleExponentialMovingAverage.average(avg)
  end
end
