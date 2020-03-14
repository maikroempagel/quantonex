defmodule Quantonex.Indicators do
  @moduledoc """
  Contains technical indicators.
  """

  alias Quantonex.DataPoint

  @dataset_min_size_error "There must be at least 1 element in the dataset."
  @period_min_value_error "Period must be at least 1."
  @period_max_value_error "Period can't be greater than the length of the dataset."

  @zero Decimal.new(0)

  @typedoc """
  Represents a smoothing method.

    * `:ema` - exponential moving average
    * `:sma` - simple moving average
  """
  @type smoothing_method :: :ema | :sma

  @doc """
  Calculates a list of exponential moving averages (EMAs) for a given dataset and period.

  The first `n` elements (`n == period`) are used to calculate the initial EMA using a SMA.
  Each successive value is calculated using an EMA.

  Possible return values are:

  * `{:error, reason}`
  * `{:ok, values}`

  The returned list of EMA values has the same length as the input dataset, so they can
  be joined again.

  ## Examples

    ```
    dataset = 1..11 |> Enum.map(fn x -> x end)
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

    {:ok, emas} = Quantonex.Indicators.ema(dataset, 10)
    {:ok,
    [#Decimal<0>, #Decimal<0>, #Decimal<0>, #Decimal<0>, #Decimal<0>, #Decimal<0>,
    #Decimal<0>, #Decimal<0>, #Decimal<0>, #Decimal<5.5>,
    #Decimal<6.500000000000000000000000000>]}

    Enum.zip(dataset, emas)
    [
      {1, #Decimal<0>},
      {2, #Decimal<0>},
      {3, #Decimal<0>},
      {4, #Decimal<0>},
      {5, #Decimal<0>},
      {6, #Decimal<0>},
      {7, #Decimal<0>},
      {8, #Decimal<0>},
      {9, #Decimal<0>},
      {10, #Decimal<5.5>},
      {11, #Decimal<6.500000000000000000000000000>}
    ]
    ```
  """
  @spec ema(dataset :: nonempty_list(price :: String.t() | number()), period :: pos_integer()) ::
          {:error, reason :: String.t()} | {:ok, nonempty_list(values :: Decimal.t())}

  def ema([], _period), do: {:error, @dataset_min_size_error}

  def ema(dataset, period) when is_list(dataset) and period < 1,
    do: {:error, @period_min_value_error}

  def ema(dataset, period) when is_list(dataset) and period > length(dataset),
    do: {:error, @period_max_value_error}

  def ema(dataset, period) when is_list(dataset) do
    try do
      {:ok, seed} =
        dataset
        |> Enum.take(period)
        |> Enum.map(&to_decimal/1)
        |> sma()

      initial_emas = 1..(period - 1) |> Enum.map(fn _ -> @zero end)

      values =
        dataset
        |> Enum.slice(period..(length(dataset) - 1))
        |> Enum.map(&to_decimal/1)
        |> Enum.reduce_while([seed | initial_emas], fn current_price, acc ->
          [previous_ema | _tail] = acc

          case ema(current_price, period, previous_ema) do
            {:ok, value} -> {:cont, [value | acc]}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
        |> Enum.reverse()

      {:ok, values}
    rescue
      e in Decimal.Error ->
        {:error, "An error occured while calculating the EMA value: " <> e.message}
    end
  end

  @doc """
  Calculates a single exponential moving average (EMA) for a given price, period and another EMA.

  This is a convenience function to avoid calculation using a complete dataset.
  See `Quantonex.Indicators.ema/2` for how to calculate an initial EMA.

  Possible return values are:

  * `{:error, reason}`
  * `{:ok, value}`

  ## Examples

    ```
    previous_ema = Decimal.from_float(5.5)
    #Decimal<5.5>

    {:ok, value} = Quantonex.Indicators.ema(11, 10, previous_ema)
    {:ok, #Decimal<6.500000000000000000000000000>}
    ```
  """
  @spec ema(price :: String.t() | number(), period :: pos_integer(), previous_ema :: Decimal.t()) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}
  def ema(price, period, previous_ema) do
    try do
      multiplier = weighted_multiplier(period) |> IO.inspect(label: :weighted)

      result =
        previous_ema
        |> to_decimal()
        |> Decimal.mult(Decimal.sub(Decimal.new(1), multiplier))

      value =
        price
        |> Decimal.mult(multiplier)
        |> Decimal.add(result)

      {:ok, value}
    rescue
      e in Decimal.Error ->
        {:error, "An error occured while calculating the EMA value: " <> e.message}
    end
  end

  @typedoc """
  Represents a relative strength index (RSI).
  """
  @type relative_strength_index :: %{
          value: Decimal.t()
        }

  @doc """
  Calculates a list of relative strength indexes (RSIs) for a given dataset.
  """
  @spec rsi(
          dataset :: nonempty_list(price :: String.t() | number()),
          period :: non_neg_integer()
        ) ::
          {:error, reason :: String.t()}
          | {:ok, values :: nonempty_list(RSI.t())}

  def rsi([], _period), do: {:error, @dataset_min_size_error}

  def rsi(dataset, period),
    do: calculate_rsi(dataset, period, &calculate_simple_moving_average/2)

  defp calculate_rsi(dataset, period, fun) do
    try do
      results =
        dataset
        |> Enum.map(&to_decimal/1)
        |> Enum.with_index()
        |> Enum.reduce(fn x, acc ->
          {current_price, index} = x

          case acc do
            # the first iteration
            {previous_price, _} ->
              {up_movement, down_movement} = up_and_down_movements(previous_price, current_price)

              previous_value = %{
                price: previous_price,
                relative_strength: @zero,
                value: @zero
              }

              current_value = %{
                price: current_price,
                up_sum: up_movement,
                down_sum: down_movement,
                relative_strength: @zero,
                value: @zero
              }

              [current_value, previous_value]

            [previous | _tail] = list ->
              {up_movement, down_movement} = up_and_down_movements(previous.price, current_price)

              up_sum = Decimal.add(up_movement, previous.up_sum)
              down_sum = Decimal.add(down_movement, previous.down_sum)

              {up_average, down_average, relative_strength, relative_strength_index} =
                case index do
                  # no RSI
                  x when x < period ->
                    {@zero, @zero}
                    |> rsi2()

                  # first calculation of the RSI
                  x when x == period ->
                    up_average = fun.([up_sum], period)
                    down_average = fun.([down_sum], period)

                    {up_average, down_average}
                    |> rsi2()

                  # subsequent calculations of the RSI
                  x when x > period ->
                    up_average =
                      Decimal.mult(previous.up_average, Decimal.new(period - 1))
                      |> Decimal.add(up_movement)
                      |> Decimal.div(Decimal.new(period))

                    down_average =
                      Decimal.mult(previous.down_average, Decimal.new(period - 1))
                      |> Decimal.add(down_movement)
                      |> Decimal.div(Decimal.new(period))

                    {relative_strength, relative_strength_index} =
                      calculate_relative_strength_index2(up_average, down_average)

                    {
                      up_average,
                      down_average,
                      relative_strength,
                      relative_strength_index
                    }
                end

              current_value = %{
                price: current_price,
                up_sum: up_sum,
                down_sum: down_sum,
                up_average: up_average,
                down_average: down_average,
                relative_strength: relative_strength,
                value: relative_strength_index
              }

              [current_value | list]
          end
        end)
        |> Enum.reverse()

      {:ok, results}
    rescue
      e in Decimal.Error ->
        {:error, "An error occured while calculating the RSI value: " <> e.message}
    end
  end

  defp rsi2({@zero = up_average, @zero = down_average}),
    do: {up_average, down_average, @zero, @zero}

  defp rsi2({up_average, down_average}) do
    {relative_strength, relative_strength_index} =
      calculate_relative_strength_index2(up_average, down_average)

    {up_average, down_average, relative_strength, relative_strength_index}
  end

  defp calculate_relative_strength_index2(up_average, down_average) do
    max_rsi = Decimal.new(100)

    # no down movements
    if Decimal.equal?(down_average, Decimal.new(0)) do
      {0, max_rsi}
    else
      relative_strength = Decimal.div(up_average, down_average)

      # RSI: 100 – 100 / ( 1 + relative_strength)
      first_calc = Decimal.new(1) |> Decimal.add(relative_strength)
      second_calc = Decimal.div(max_rsi, first_calc)

      relative_strength_index = Decimal.sub(max_rsi, second_calc)

      {relative_strength, relative_strength_index}
    end
  end

  @doc """
  Calculates a simple moving average (SMA) for a given dataset.

  The period of the SMA is fixed and equal to the length of the dataset.

  Possible return values are:

  * `{:error, reason}`
  * `{:ok, value}`

  ## Examples

    ```
    iex> Quantonex.Indicators.sma([1, 2, 3])
    {:ok, Decimal.new(2)}
    ```
  """
  @spec sma(dataset :: nonempty_list(price :: String.t() | number())) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}
  def sma([]), do: {:error, @dataset_min_size_error}

  def sma(dataset) when is_list(dataset) do
    try do
      value = calculate_simple_moving_average(dataset, length(dataset))

      {:ok, value}
    rescue
      e in Decimal.Error ->
        {:error, "An error occured while calculating the SMA value: " <> e.message}
    end
  end

  @typedoc """
  Represents a volume weighted average price.

    * `value` - the volume weighted average price
    * `cumulative_volume` - the previous volume plus the current volume
    * `cumulative_volume_price` - the previous volume price plus the current volume price
  """
  @type volume_weighted_average_price :: %{
          cumulative_volume: non_neg_integer(),
          cumulative_volume_price: Decimal.t(),
          value: Decimal.t()
        }

  @doc """
  Calculates a list of volume weighted average prices (VWAPs) for a given dataset.

  The following data point properties are used to calculate a VWAP value.

  * `high`
  * `low`
  * `close`
  * `volume`

  Possible return values are:

  * `{:error, reason}`
  * `{:ok, values}`

  The returned list of VWAP values has the same length as the input dataset, so they can
  be joined again.

  ## Examples

    ```
    dataset = [%Quantonex.DataPoint{
                  close: #Decimal<127.28>,
                  high: #Decimal<127.36>,
                  low: #Decimal<126.99>,
                  volume: 89329
                },...]

    {:ok, vwaps} = Quantonex.Indicators.vwap(dataset)
    {:ok,
      [%{
        cumulative_volume: 89329,
        cumulative_volume_price: #Decimal<11363542.09>,
        value: #Decimal<127.21>
      }, ...]
    }

    Enum.zip(dataset, vwaps)
    [
      ...
    ]
    ```
  """
  @spec vwap(dataset :: nonempty_list(DataPoint.t())) ::
          {:error, reason :: String.t()}
          | {:ok, values :: nonempty_list(volume_weighted_average_price())}
  def vwap([]), do: {:error, @dataset_min_size_error}

  def vwap(dataset) when is_list(dataset) do
    values =
      dataset
      |> Enum.reduce_while([], fn data_point, acc ->
        case acc do
          [] ->
            case vwap(data_point, 0, @zero) do
              {:ok, value} -> {:cont, [value]}
              {:error, reason} -> {:halt, {:error, reason}}
            end

          [previous_vwap | _tail] ->
            {:ok, value} =
              vwap(
                data_point,
                previous_vwap[:cumulative_volume],
                previous_vwap[:cumulative_volume_price]
              )

            {:cont, [value | acc]}
        end
      end)

    case values do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, values |> Enum.reverse()}
    end
  end

  @doc """
  Calculates a single volume weighted average price (VWAP).

  The following data point properties are used to calculate a VWAP value.

  * `high`
  * `low`
  * `close`
  * `volume`

  Possible return values are:

  * `{:error, reason}`
  * `{:ok, values}`

  ## Examples

  ```
  data_point = %Quantonex.DataPoint{
    close: Decimal.new(6),
    high: Decimal.new(8),
    low: Decimal.new(4),
    volume: 10
  }

  {:ok,
    %{
      "cumulative_volume": cumulative_volume,
      "cumulative_volume_price": cumulative_volume_price,
      "value": value
    }
  } = Quantonex.Indicators.vwap(data_point)
  ```

  Successive calculations can be done by passing previously calculated cumulative values to
  the function.

  ```
  next_data_point = %Quantonex.DataPoint{
    close: Decimal.new(8),
    high: Decimal.new(10),
    low: Decimal.new(6),
    volume: 20
  }

  Quantonex.Indicators.vwap(next_data_point, cumulative_volume, cumulative_volume_price)
  ```
  """
  @spec vwap(
          data_point :: DataPoint.t(),
          cumulative_volume :: non_neg_integer(),
          cumulative_volume_price :: Decimal.t()
        ) ::
          {:error, reason :: String.t()} | {:ok, value :: volume_weighted_average_price()}
  def vwap(
        %DataPoint{} = data_point,
        cumulative_volume \\ 0,
        cumulative_volume_price \\ Decimal.new(0)
      ) do
    try do
      average_price =
        data_point.high
        |> Decimal.add(data_point.low)
        |> Decimal.add(data_point.close)
        |> Decimal.div(3)

      volume_price = Decimal.mult(average_price, data_point.volume)

      new_cumulative_volume = cumulative_volume + data_point.volume
      new_cumulative_volume_price = Decimal.add(cumulative_volume_price, volume_price)

      value = Decimal.div(new_cumulative_volume_price, new_cumulative_volume)

      {
        :ok,
        %{
          cumulative_volume: new_cumulative_volume,
          cumulative_volume_price: new_cumulative_volume_price,
          value: value
        }
      }
    rescue
      e in Decimal.Error ->
        {:error, "An error occured while calculating the VWAP value: " <> e.message}
    end
  end

  ## Helpers

  defp calculate_simple_moving_average(dataset, period) do
    dataset
    |> Enum.map(&to_decimal/1)
    |> Enum.reduce(fn x, acc -> Decimal.add(x, acc) end)
    |> calculate_average(period)
  end

  defp calculate_average(sum, divisor), do: Decimal.div(sum, Decimal.new(divisor))

  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  # create decimals from either strings, integers or decimals
  defp to_decimal(value), do: Decimal.new(value)

  defp weighted_multiplier(period) do
    period_increment = Decimal.new(period + 1)

    Decimal.new(2)
    |> Decimal.div(period_increment)
  end

  defp up_movement(price1, price2) do
    diff = Decimal.sub(price2, price1)

    case Decimal.gt?(diff, 0) do
      true -> diff
      false -> Decimal.new(0)
    end
  end

  defp down_movement(price1, price2) do
    diff = Decimal.sub(price2, price1)

    case Decimal.lt?(diff, 0) do
      true -> Decimal.abs(diff)
      false -> Decimal.new(0)
    end
  end

  defp up_and_down_movements(price1, price2) do
    up = up_movement(price1, price2)
    down = down_movement(price1, price2)

    {up, down}
  end
end
