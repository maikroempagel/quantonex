defmodule Quantonex.IndicatorsTest do
  use ExUnit.Case, async: true

  doctest Quantonex.Indicators

  @dataset_error "There must be at least 1 element in the dataset."

  test "ema/1: period 0 returns error" do
    price = Decimal.from_float(22.81)

    assert Quantonex.Indicators.ema(price, 0) == {:error, "Period must be at least 1."}
  end

  test "ema/1: period less than 0 returns error" do
    price = Decimal.from_float(22.81)

    assert Quantonex.Indicators.ema(price, -3) == {:error, "Period must be at least 1."}
  end

  test "ema/1: calulate first ema using sma" do
    price = Decimal.from_float(22.81)
    period = 9
    expected_ema = Decimal.from_float(22.81)

    {:ok, actual_ema} = Quantonex.Indicators.ema(price, period)

    assert Decimal.equal?(actual_ema, expected_ema) == true
  end

  test "ema/2: calulate next ema using previous ema" do
    price = Decimal.from_float(22.91)
    period = 9
    previous_ema = Decimal.from_float(22.81)
    expected_ema = Decimal.from_float(22.83)

    {:ok, actual_ema} = Quantonex.Indicators.ema(price, period, previous_ema)

    assert Decimal.equal?(actual_ema, expected_ema) == true,
           "expected #{expected_ema}, but was #{actual_ema}!"
  end

  test "sma/1: invalid empty dataset and implicit period" do
    assert Quantonex.Indicators.sma([]) == {:error, @dataset_error}
  end

  test "sma/1: valid non-empty dataset and implicit period" do
    assert Quantonex.Indicators.sma([1]) == {:ok, Decimal.new(1)}
  end

  test "sma/1: valid non-empty float dataset and implicit period" do
    assert Quantonex.Indicators.sma([2.1, 2.0, -2.0]) == {:ok, Decimal.from_float(0.7)}
  end

  test "sma/1: invalid non-numeric dataset" do
    data = ["a", "b"]

    assert Quantonex.Indicators.sma(data) ==
             {:error, "One of the elements in the dataset is non-numeric."}
  end

  test "sma/2: invalid empty dataset and explicit invalid period" do
    assert Quantonex.Indicators.sma([], 1) == {:error, @dataset_error}
  end

  test "sma/2: invalid empty dataset and explicit valid period" do
    assert Quantonex.Indicators.sma([], 2) == {:error, @dataset_error}
  end

  test "vwap/3: initial data point" do
    data_point = %Quantonex.DataPoint{
      complete: false,
      high: Decimal.new(8),
      low: Decimal.new(4),
      close: Decimal.new(6),
      volume: 10
    }

    expected_vwap = %{
      cumulative_volume: 10,
      cumulative_volume_price: Decimal.new(60),
      value: Decimal.new(6)
    }

    assert Quantonex.Indicators.vwap(data_point) == {:ok, expected_vwap}
  end

  test "vwap/3: data point and cumulative values" do
    data_point = %Quantonex.DataPoint{
      complete: false,
      high: Decimal.new(12),
      low: Decimal.new(8),
      close: Decimal.new(10),
      volume: 20
    }

    expected_vwap = %{
      cumulative_volume: 30,
      cumulative_volume_price: Decimal.new(240),
      value: Decimal.new(8)
    }

    assert Quantonex.Indicators.vwap(data_point, 10, Decimal.new(40)) == {:ok, expected_vwap}
  end
end
