defmodule Quantonex.IndicatorsTest do
  use ExUnit.Case, async: true

  doctest Quantonex.Indicators

  @dataset_error "There must be at least 2 elements in the dataset."

  test "sma/1: invalid empty dataset and implicit period" do
    assert Quantonex.Indicators.sma([]) == {:error, @dataset_error}
  end

  test "sma/1: invalid non-empty dataset and implicit period" do
    assert Quantonex.Indicators.sma([1]) == {:error, @dataset_error}
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
