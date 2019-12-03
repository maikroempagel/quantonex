defmodule QuantonexTest do
  use ExUnit.Case

  @dataset_error "There must be at least 2 data points."
  @period_error "Period must be at least 2."

  test "invalid empty data set and implicit period" do
    assert Quantonex.sma([]) == {:error, @dataset_error}
  end

  test "invalid empty data set and explicit invalid period" do
    assert Quantonex.sma([], 1) == {:error, @dataset_error}
  end

  test "invalid empty data set and explicit valid period" do
    assert Quantonex.sma([], 2) == {:error, @dataset_error}
  end

  test "invalid non-empty data set and implicit period" do
    assert Quantonex.sma([1]) == {:error, @dataset_error}
  end

  test "valid non-empty data set and explicit invalid period" do
    assert Quantonex.sma([1, 2, 3], 1) == {:error, @period_error}
  end

  test "valid non-empty integer data set and implicit period" do
    assert Quantonex.sma([1, 2, 3]) == {:ok, Decimal.new(2)}
  end

  test "valid non-empty float data set and implicit period" do
    assert Quantonex.sma([2.1, 2.0, -2.0]) == {:ok, Decimal.from_float(0.7)}
  end

  test "invalid non-numeric data set" do
    data = ["a", "b"]
    assert Quantonex.sma(data) == {:error, "One of the data points is non-numeric."}
  end
end
