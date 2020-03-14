defmodule Quantonex.IndicatorsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Quantonex.DataPoint
  alias Quantonex.Indicators

  doctest Quantonex.Indicators

  @test_data_path Path.expand("../test/data", __DIR__)

  @dataset_min_size_error "There must be at least 1 element in the dataset."
  @period_min_value_error "Period must be at least 1."

  describe "ema/2" do
    test "empty dataset" do
      assert Indicators.ema([], 0) == {:error, @dataset_min_size_error}
    end

    test "period 0" do
      dataset = [22.81]

      assert Indicators.ema(dataset, 0) == {:error, @period_min_value_error}
    end

    test "period less than 0" do
      dataset = [22.81]

      assert Indicators.ema(dataset, -3) == {:error, @period_min_value_error}
    end

    test "non-numeric dataset" do
      invalid_element = "a"
      dataset = [invalid_element]

      error_message =
        "An error occured while calculating the EMA value: invalid_operation: number parsing syntax: #{
          invalid_element
        }"

      assert Indicators.ema(dataset, 1) == {:error, error_message}
    end

    test "verify dataset" do
      period = 10

      test_data = parse_ema_test_data()

      dataset =
        test_data
        |> Enum.map(fn x ->
          {price, _ema} = x

          price
        end)

      {:ok, actual} = Indicators.ema(dataset, period)

      test_data
      |> Enum.with_index()
      |> Enum.each(fn x ->
        {{_price, expected_ema}, index} = x

        actual_ema = Enum.at(actual, index)

        assert Decimal.equal?(actual_ema, expected_ema),
               "Expected #{expected_ema}, but was #{actual_ema}!"
      end)
    end

    test "float dataset with period equal to the length of the dataset" do
      dataset = [
        22.2734,
        22.194,
        22.0847,
        22.1741,
        22.184,
        22.1344,
        22.2337,
        22.4323,
        22.2436,
        22.2933
      ]

      # this is equal to SMA(10)
      expected_results = [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        Decimal.new("22.22475")
      ]

      {:ok, actual} = Indicators.ema(dataset, 10)

      verify_results(actual, expected_results)
    end

    test "integer dataset with period less than length of dataset" do
      dataset = 1..10 |> Enum.map(fn x -> x end)

      expected_results = [
        0,
        0,
        0,
        0,
        Decimal.new(3),
        Decimal.new(4),
        Decimal.new(5),
        Decimal.new(6),
        Decimal.new(7),
        Decimal.new(8)
      ]

      {:ok, actual} = Indicators.ema(dataset, 5)

      verify_results(actual, expected_results)
    end

    test "string dataset with period less than length of dataset" do
      dataset = 1..10 |> Enum.map(fn x -> Integer.to_string(x) end)

      expected_results = [
        0,
        0,
        0,
        0,
        Decimal.new(3),
        Decimal.new(4),
        Decimal.new(5),
        Decimal.new(6),
        Decimal.new(7),
        Decimal.new(8)
      ]

      {:ok, actual} = Indicators.ema(dataset, 5)

      verify_results(actual, expected_results)
    end
  end

  describe "ema/3" do
    test "non-numeric price" do
      previous_ema = Decimal.from_float(5.5)
      invalid_price = "a"

      error_message =
        "An error occured while calculating the EMA value: invalid_operation: number parsing syntax: #{
          invalid_price
        }"

      assert Indicators.ema(invalid_price, 10, previous_ema) == {:error, error_message}
    end

    test "period 10" do
      previous_ema = Decimal.from_float(5.5)

      expected = Decimal.from_float(6.5)
      {:ok, actual} = Quantonex.Indicators.ema(11, 10, previous_ema)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  describe "rsi/2" do
    test "empty dataset" do
      dataset = []

      assert Indicators.rsi(dataset, 3) == {:error, @dataset_min_size_error}
    end

    test "simple moving average" do
      period = 14

      test_data = parse_rsi_test_data()

      dataset =
        test_data
        |> Enum.map(fn x ->
          {price, _rsi} = x

          price
        end)

      {:ok, actual} = Indicators.rsi(dataset, period)

      test_data
      |> Enum.with_index()
      |> Enum.each(fn x ->
        {{_price, expected_rsi}, index} = x

        actual_value = Enum.at(actual, index)
        actual_rsi = actual_value[:value]

        assert Decimal.equal?(actual_rsi, expected_rsi),
               "Expected #{expected_rsi}, but was #{actual_rsi}!"
      end)
    end
  end

  describe "sma/1" do
    test "empty dataset" do
      assert Indicators.sma([]) == {:error, @dataset_min_size_error}
    end

    test "single element non-numeric dataset" do
      invalid_element = "a"
      dataset = [invalid_element]

      error_message =
        "An error occured while calculating the SMA value: invalid_operation: number parsing syntax: #{
          invalid_element
        }"

      assert Indicators.sma(dataset) == {:error, error_message}
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

      {:ok, actual} = Indicators.sma(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "integer dataset" do
      dataset =
        [
          101,
          100,
          103,
          99,
          96,
          99,
          95,
          91,
          93,
          89
        ]
        |> Enum.map(fn x -> x end)

      expected = Decimal.from_float(96.6)

      {:ok, actual} = Indicators.sma(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end

    test "string dataset" do
      dataset =
        [
          101,
          100,
          103,
          99,
          96,
          99,
          95,
          91,
          93,
          89
        ]
        |> Enum.map(fn x -> Integer.to_string(x) end)

      expected = Decimal.from_float(96.6)

      {:ok, actual} = Indicators.sma(dataset)

      assert Decimal.equal?(actual, expected),
             "Expected #{expected}, but was #{actual}!"
    end
  end

  describe "vwap/1" do
    test "empty dataset" do
      dataset = []

      assert Indicators.vwap(dataset) == {:error, @dataset_min_size_error}
    end

    test "zero volume" do
      data_point = %Quantonex.DataPoint{
        high: Decimal.from_float(127.36),
        low: Decimal.from_float(126.99),
        close: Decimal.from_float(127.28),
        volume: 0
      }

      error_message =
        "An error occured while calculating the VWAP value: invalid_operation: 0 / 0"

      assert Indicators.vwap([data_point]) == {:error, error_message}
    end

    test "verify dataset" do
      test_data = parse_vwap_test_data()

      dataset =
        test_data
        |> Enum.map(fn x ->
          {data_point, _vwap} = x

          data_point
        end)

      {:ok, actual} = Indicators.vwap(dataset)

      test_data
      |> Enum.with_index()
      |> Enum.each(fn x ->
        {{_data_point, expected_vwap}, index} = x

        actual_vwap = Enum.at(actual, index)

        assert actual_vwap[:cumulative_volume] == expected_vwap[:cumulative_volume]

        assert Decimal.equal?(
                 actual_vwap[:cumulative_volume_price],
                 expected_vwap[:cumulative_volume_price]
               )

        assert Decimal.equal?(
                 actual_vwap[:value],
                 expected_vwap[:value]
               )
      end)
    end
  end

  describe "vwap/3" do
    test "zero volume" do
      data_point = %Quantonex.DataPoint{
        high: Decimal.from_float(127.36),
        low: Decimal.from_float(126.99),
        close: Decimal.from_float(127.28),
        volume: 0
      }

      error_message =
        "An error occured while calculating the VWAP value: invalid_operation: 0 / 0"

      assert Indicators.vwap(data_point, 0, 0) == {:error, error_message}
    end

    test "data point with implicit cumulative volume price" do
      data_point = %Quantonex.DataPoint{
        complete: false,
        high: Decimal.from_float(127.36),
        low: Decimal.from_float(126.99),
        close: Decimal.from_float(127.28),
        volume: 89_329
      }

      expected_vwap = %{
        cumulative_volume: 89_329,
        cumulative_volume_price: Decimal.from_float(11_363_542.09),
        value: Decimal.from_float(127.21)
      }

      assert Quantonex.Indicators.vwap(data_point, 0) == {:ok, expected_vwap}
    end

    test "data point with implicit cumulative values" do
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

  ## Helpers

  defp parse_ema_test_data() do
    # test data taken from: https://school.stockcharts.com/doku.php?id=technical_indicators:vwap_intraday

    test_data_path = Path.join([@test_data_path, "ema_test_data"])

    lines = File.read!(test_data_path) |> String.split("\n", trim: true)

    lines
    |> Enum.slice(1..(length(lines) - 1))
    |> Enum.map(&String.split(&1, ","))
    |> Enum.map(fn x ->
      price = Decimal.new(Enum.at(x, 0))
      ema = Decimal.new(Enum.at(x, 1))

      {price, ema}
    end)
  end

  defp parse_rsi_test_data() do
    # test data taken from: https://school.stockcharts.com/doku.php?id=technical_indicators:moving_averages

    test_data_path = Path.join([@test_data_path, "rsi_test_data"])

    lines = File.read!(test_data_path) |> String.split("\n", trim: true)

    lines
    |> Enum.slice(1..(length(lines) - 1))
    |> Enum.map(&String.split(&1, ","))
    |> Enum.map(fn x ->
      price = Decimal.new(Enum.at(x, 0))
      rsi = Decimal.new(Enum.at(x, 1))

      {price, rsi}
    end)
  end

  defp parse_vwap_test_data() do
    # test data taken from: https://school.stockcharts.com/doku.php?id=technical_indicators:vwap_intraday

    test_data_path = Path.join([@test_data_path, "vwap_test_data"])

    lines = File.read!(test_data_path) |> String.split("\n", trim: true)

    lines
    |> Enum.slice(1..(length(lines) - 1))
    |> Enum.map(&String.split(&1, ","))
    |> Enum.map(fn x ->
      data_point = %DataPoint{
        high: Decimal.new(Enum.at(x, 0)),
        low: Decimal.new(Enum.at(x, 1)),
        close: Decimal.new(Enum.at(x, 2)),
        volume: String.to_integer(Enum.at(x, 3))
      }

      vwap = %{
        cumulative_volume: String.to_integer(Enum.at(x, 4)),
        cumulative_volume_price: Decimal.new(Enum.at(x, 5)),
        value: Decimal.new(Enum.at(x, 6))
      }

      {data_point, vwap}
    end)
  end

  defp verify_results(actual_results, expected_results) do
    actual_results
    |> Enum.with_index()
    |> Enum.each(fn x ->
      {value, index} = x

      expected = Enum.at(expected_results, index)

      assert Decimal.equal?(value, expected),
             "Expected #{expected}, but was #{value}!"
    end)
  end
end
