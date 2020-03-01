defmodule Quantonex.IndicatorsTest do
  use ExUnit.Case, async: true

  doctest Quantonex.Indicators

  @dataset_error "There must be at least 1 element in the dataset."
  @period_min_value_error "Period must be at least 1."
  @period_max_value_error "Period can't be greater than the length of the dataset."

  @ema_cal_error "An error occured while calculating the EMA value."

  describe "ema/1" do
    test "period 0" do
      dataset = []

      assert Quantonex.Indicators.ema(dataset) == {:error, @dataset_error}
    end

    test "single element non-numeric dataset" do
      dataset = ["a"]

      assert Quantonex.Indicators.ema(dataset) == {:error, @ema_cal_error}
    end

    test "non-numeric dataset" do
      dataset = ["a", "b"]

      assert Quantonex.Indicators.ema(dataset) == {:error, @ema_cal_error}
    end

    test "float dataset" do
      dataset = [
        22.81,
        23.09,
        22.91,
        23.23,
        22.83,
        23.05,
        23.02,
        23.29,
        23.41
      ]

      expected = Decimal.new("23.1044064512")

      {:ok, actual} = Quantonex.Indicators.ema(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "integer dataset" do
      dataset = 1..10 |> Enum.map(fn x -> x end)

      expected = Decimal.new("6.239368480121215716994461520")

      {:ok, actual} = Quantonex.Indicators.ema(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  describe "ema/2" do
    test "period 0" do
      dataset = [Decimal.from_float(22.81)]

      assert Quantonex.Indicators.ema(dataset, 0) == {:error, @period_min_value_error}
    end

    test "period less than 0" do
      dataset = [Decimal.from_float(22.81)]

      assert Quantonex.Indicators.ema(dataset, -3) == {:error, @period_min_value_error}
    end

    test "period greater than length of dataset" do
      dataset = [Decimal.from_float(22.81)]

      assert Quantonex.Indicators.ema(dataset, 2) ==
               {:error, @period_max_value_error}
    end

    test "single element non-numeric dataset" do
      dataset = ["a"]

      assert Quantonex.Indicators.ema(dataset, 1) == {:error, @ema_cal_error}
    end

    test "non-numeric dataset" do
      dataset = ["a", "b"]

      assert Quantonex.Indicators.ema(dataset, 2) == {:error, @ema_cal_error}
    end

    test "float dataset" do
      dataset = [
        22.81,
        23.09,
        22.91,
        23.23,
        22.83,
        23.05,
        23.02,
        23.29,
        23.41
      ]

      expected = Decimal.new("23.1044064512")

      {:ok, actual} = Quantonex.Indicators.ema(dataset, 9)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "integer dataset" do
      dataset = 1..10 |> Enum.map(fn x -> x end)

      expected = Decimal.new("6.67108864")

      {:ok, actual} = Quantonex.Indicators.ema(dataset, 9)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "float dataset with period less than length of dataset" do
      dataset = [
        22.81,
        23.09,
        22.91,
        23.23,
        22.83,
        23.05,
        23.02,
        23.29,
        23.41
      ]

      expected = Decimal.new("23.17543209876543209876543209")

      {:ok, actual} = Quantonex.Indicators.ema(dataset, 5)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "integer dataset with period less than length of dataset" do
      dataset = 1..10 |> Enum.map(fn x -> x end)

      expected = Decimal.new("8.395061728395061728395061728")

      {:ok, actual} = Quantonex.Indicators.ema(dataset, 5)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  test "ema/2: period greater than length of dataset" do
    dataset = [Decimal.from_float(22.81)]

    assert Quantonex.Indicators.ema(dataset, 2) ==
             {:error, @period_max_value_error}
  end

  test "ema/2: explicit period equal to length of dataset" do
    dataset = [
      22.81,
      23.09,
      22.91,
      23.23,
      22.83,
      23.05,
      23.02,
      23.29,
      23.41
    ]

    expected_ema = Decimal.new("23.1044064512")

    {:ok, actual_ema} = Quantonex.Indicators.ema(dataset, 9)

    assert Decimal.equal?(actual_ema, expected_ema)
  end

  test "ema/2: period less than the length of dataset" do
    dataset = [
      22.81,
      23.09,
      22.91,
      23.23,
      22.83,
      23.05,
      23.02,
      23.29,
      23.41
    ]

    expected_ema = Decimal.new("23.17543209876543209876543209")

    {:ok, actual_ema} = Quantonex.Indicators.ema(dataset, 5)

    assert Decimal.equal?(actual_ema, expected_ema)
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

  test "vwap/3: data point with cumulative volume price implicit" do
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

    assert Quantonex.Indicators.vwap(data_point, 0) == {:ok, expected_vwap}
  end

  test "vwap/3: data point with both cumulative values implicit" do
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
