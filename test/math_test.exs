defmodule Janis.MathTest do

  defmodule ExponentialMovingAverage do
    use ExUnit.Case, async: true

    alias Janis.Math.ExponentialMovingAverage, as: A
    alias Janis.Math.MovingAverage, as: MA

    test "starts with a count of 0" do
      a = A.new(0.1)
      assert a.n == 0
    end

    test "it takes the first value as the average" do
      a = A.new(0.1)
      a = MA.update(a, 3.0)
      assert MA.average(a) == 3.0
    end

    test "it applies the weighting factor on subsequent updates" do
      a = A.new(0.1)
      a = MA.update(a, 3.0)
      a = MA.update(a, 6.0)
      assert_in_delta MA.average(a), 3.3, 0.00001
      a = MA.update(a, 4.0)
      assert_in_delta MA.average(a), 3.37, 0.00001
    end
  end
  defmodule DoubleExponentialMovingAverage do
    use ExUnit.Case, async: true

    alias Janis.Math.DoubleExponentialMovingAverage, as: A
    alias Janis.Math.MovingAverage, as: MA

    test "starts with a count of 0" do
      a = A.new(0.1, 0.1)
      assert a.n == 0
    end

    test "it takes the first value as the average" do
      a = A.new(0.1, 0.1)
      a = MA.update(a, 3.0)
      assert MA.average(a) == 3.0
    end

    test "it takes the second value as the average" do
      a = A.new(0.1, 0.1)
      a = MA.update(a, 3.0)
      a = MA.update(a, 4.0)
      assert_in_delta MA.average(a), 4.0, 0.000001
    end

    test "it applies the weighting factor on subsequent updates" do
      a = A.new(0.1, 0.1)

      a = MA.update(a, 3.0)
      a = MA.update(a, 6.0)
      assert_in_delta MA.average(a), 6.0, 0.00001
      a = MA.update(a, 4.0)
      assert_in_delta MA.average(a), 8.5, 0.00001
    end
  end
end
