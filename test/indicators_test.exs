defmodule Quantonex.IndicatorsTest do
  use ExUnit.Case, async: true

  doctest Quantonex.Indicators

  @dataset_error "There must be at least 1 element in the dataset."
  @rsi_dataset_min_size_error "There must be at least 2 elements in the dataset."
  @period_min_value_error "Period must be at least 1."
  @period_max_value_error "Period can't be greater than the length of the dataset."

  @ema_calc_error "An error occured while calculating the EMA value."
  @rsi_calc_error "An error occured while calculating the RSI value."
  @sma_calc_error "An error occured while calculating the SMA value."

  describe "ema/1" do
    test "empty dataset" do
      dataset = []

      assert Quantonex.Indicators.ema(dataset) == {:error, @dataset_error}
    end

    test "single element non-numeric dataset" do
      dataset = ["a"]

      assert Quantonex.Indicators.ema(dataset) == {:error, @ema_calc_error}
    end

    test "non-numeric dataset" do
      dataset = ["a", "b"]

      assert Quantonex.Indicators.ema(dataset) == {:error, @ema_calc_error}
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

    test "string dataset" do
      dataset = 1..10 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.new("6.239368480121215716994461520")

      {:ok, actual} = Quantonex.Indicators.ema(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  describe "ema/2" do
    test "period 0" do
      dataset = [22.81]

      assert Quantonex.Indicators.ema(dataset, 0) == {:error, @period_min_value_error}
    end

    test "period less than 0" do
      dataset = [22.81]

      assert Quantonex.Indicators.ema(dataset, -3) == {:error, @period_min_value_error}
    end

    test "period greater than length of dataset" do
      dataset = [22.81]

      assert Quantonex.Indicators.ema(dataset, 2) ==
               {:error, @period_max_value_error}
    end

    test "single element non-numeric dataset" do
      dataset = ["a"]

      assert Quantonex.Indicators.ema(dataset, 1) == {:error, @ema_calc_error}
    end

    test "non-numeric dataset" do
      dataset = ["a", "b"]

      assert Quantonex.Indicators.ema(dataset, 2) == {:error, @ema_calc_error}
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

    test "string dataset" do
      dataset = 1..10 |> Enum.map(fn x -> Integer.to_string(x) end)

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

    test "string dataset with period less than length of dataset" do
      dataset = 1..10 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.new("8.395061728395061728395061728")

      {:ok, actual} = Quantonex.Indicators.ema(dataset, 5)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  describe "rsi/3" do
    test "empty dataset" do
      dataset = []

      assert Quantonex.Indicators.rsi(dataset, :sma, 3) == {:error, @rsi_dataset_min_size_error}
    end

    test "single element dataset" do
      dataset = [1]

      assert Quantonex.Indicators.rsi(dataset, :sma, 3) == {:error, @rsi_dataset_min_size_error}
    end

    test "period greater than length of dataset" do
      dataset = [22.81, 23, 24]

      assert Quantonex.Indicators.rsi(dataset, :sma, 4) ==
               {:error, @period_max_value_error}
    end

    test "non-numeric dataset" do
      dataset = ["a", "b"]

      assert Quantonex.Indicators.rsi(dataset, :sma, 1) == {:error, @rsi_calc_error}
    end

    test "float dataset using sma" do
      dataset = [
        44.3389,
        44.0902,
        44.1497,
        43.6124,
        44.3278,
        44.8264,
        45.0955,
        45.4245,
        45.8433,
        46.0826,
        45.8931,
        46.0328,
        45.614,
        46.282,
        46.282
      ]

      expected = Decimal.new("70.53278948369507787898641080")

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :sma, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "float dataset using ema" do
      dataset = [
        44.3389,
        44.0902,
        44.1497,
        43.6124,
        44.3278,
        44.8264,
        45.0955,
        45.4245,
        45.8433,
        46.0826,
        45.8931,
        46.0328,
        45.614,
        46.282,
        46.282
      ]

      expected = Decimal.new("64.73923473120352787432305673")

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :ema, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "increasing integer dataset using sma" do
      dataset = 1..15 |> Enum.map(fn x -> x end)

      expected = Decimal.new(100)

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :sma, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "increasing integer dataset using ema" do
      dataset = 1..15 |> Enum.map(fn x -> x end)

      expected = Decimal.new(100)

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :ema, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "decreasing integer dataset using sma" do
      dataset = 15..1 |> Enum.map(fn x -> x end)

      expected = Decimal.new(0)

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :sma, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "decreasing integer dataset using ema" do
      dataset = 15..1 |> Enum.map(fn x -> x end)

      expected = Decimal.new(0)

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :ema, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "increasing string dataset using sma" do
      dataset = 1..15 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.new(100)

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :sma, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "increasing string dataset using ema" do
      dataset = 1..15 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.new(100)

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :ema, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "decreasing string dataset using sma" do
      dataset = 15..1 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.new(0)

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :sma, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "decreasing string dataset using ema" do
      dataset = 15..1 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.new(0)

      {:ok, actual} = Quantonex.Indicators.rsi(dataset, :ema, 14)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  describe "sma/1" do
    test "period 0" do
      dataset = []

      assert Quantonex.Indicators.sma(dataset) == {:error, @dataset_error}
    end

    test "single element non-numeric dataset" do
      dataset = ["a"]

      assert Quantonex.Indicators.sma(dataset) == {:error, @sma_calc_error}
    end

    test "non-numeric dataset" do
      dataset = ["a", "b"]

      assert Quantonex.Indicators.sma(dataset) == {:error, @sma_calc_error}
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

      expected = Decimal.new("23.07111111111111111111111111")

      {:ok, actual} = Quantonex.Indicators.sma(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "integer dataset" do
      dataset = 1..10 |> Enum.map(fn x -> x end)

      expected = Decimal.from_float(5.5)

      {:ok, actual} = Quantonex.Indicators.sma(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "string dataset" do
      dataset = 1..10 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.from_float(5.5)

      {:ok, actual} = Quantonex.Indicators.sma(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  describe "sma/2" do
    test "period 0" do
      dataset = [22.81]

      assert Quantonex.Indicators.sma(dataset, 0) == {:error, @period_min_value_error}
    end

    test "period less than 0" do
      dataset = [22.81]

      assert Quantonex.Indicators.sma(dataset, -3) == {:error, @period_min_value_error}
    end

    test "period greater than length of dataset" do
      dataset = [22.81]

      assert Quantonex.Indicators.sma(dataset, 2) ==
               {:error, @period_max_value_error}
    end

    test "single element non-numeric dataset" do
      dataset = ["a"]

      assert Quantonex.Indicators.sma(dataset, 1) == {:error, @sma_calc_error}
    end

    test "non-numeric dataset" do
      dataset = ["a", "b"]

      assert Quantonex.Indicators.sma(dataset, 2) == {:error, @sma_calc_error}
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

      expected = Decimal.new("23.07111111111111111111111111")

      {:ok, actual} = Quantonex.Indicators.sma(dataset, 9)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "integer dataset" do
      dataset = 1..10 |> Enum.map(fn x -> x end)

      expected = Decimal.new(6)

      {:ok, actual} = Quantonex.Indicators.sma(dataset, 9)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "string dataset" do
      dataset = 1..10 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.new(6)

      {:ok, actual} = Quantonex.Indicators.sma(dataset, 9)

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

      expected = Decimal.from_float(23.12)

      {:ok, actual} = Quantonex.Indicators.sma(dataset, 5)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "integer dataset with period less than length of dataset" do
      dataset = 1..10 |> Enum.map(fn x -> x end)

      expected = Decimal.new(8)

      {:ok, actual} = Quantonex.Indicators.sma(dataset, 5)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "string dataset with period less than length of dataset" do
      dataset = 1..10 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.new(8)

      {:ok, actual} = Quantonex.Indicators.sma(dataset, 5)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  describe "vwap/3" do
    test "data point with cumulative volume price implicit" do
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

    test "data point with both cumulative values implicit" do
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

    test "data point and cumulative values" do
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
end
