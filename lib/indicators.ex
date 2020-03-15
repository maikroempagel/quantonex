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
      # every ema value with an index < period is set to 0
      initial_emas = 1..(period - 1) |> Enum.map(fn _ -> @zero end)

      # the first EMA is based on a SMA
      {:ok, seed} =
        dataset
        |> Enum.take(period)
        |> Enum.map(&to_decimal/1)
        |> sma()

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
        # reverse to match the order of the input dataset
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
      # 2 / (period + 1)
      multiplier = weighted_multiplier(period)

      # (price - previous_ema) * multiplier + previous_ema
      value =
        previous_ema
        |> to_decimal()
        |> Decimal.mult(Decimal.sub(Decimal.new(1), multiplier))
        |> Decimal.add(Decimal.mult(price, multiplier))

      {:ok, value}
    rescue
      e in Decimal.Error ->
        {:error, "An error occured while calculating the EMA value: " <> e.message}
    end
  end

  @doc """
  Calculates a list of relative strength indexes (RSIs) for a given dataset.
  """
  @spec rsi(
          dataset :: nonempty_list(price :: String.t() | number()),
          period :: non_neg_integer()
        ) ::
          {:error, reason :: String.t()}
          | {:ok, values :: nonempty_list(Decimal.t())}

  def rsi([], _period), do: {:error, @dataset_min_size_error}

  def rsi(dataset, period) do
    try do
      init_map = %{
        current_price: @zero,
        previous_price: @zero,
        up_movement: @zero,
        up_sum: @zero,
        down_movement: @zero,
        down_sum: @zero,
        up_average: @zero,
        down_average: @zero,
        relative_strength: @zero,
        value: @zero
      }

      results =
        dataset
        |> Enum.map(&to_decimal/1)
        |> Enum.with_index()
        |> Enum.reduce(fn price_with_index, acc ->
          {current_price, index} = price_with_index

          {previous_rsi, previous_items} =
            case acc do
              # the first iteration and initialization of our result rsi dataset
              {first_price, _index} ->
                previous_rsi = %{init_map | current_price: first_price}

                {
                  previous_rsi,
                  [previous_rsi]
                }

              [previous_rsi | _tail] ->
                {previous_rsi, acc}
            end

          current_rsi =
            init_map
            |> Map.put(:current_price, current_price)
            |> Map.put(:previous_price, previous_rsi.current_price)
            |> rsi_up_movement()
            |> rsi_down_movement()
            |> rsi_up_sum(previous_rsi)
            |> rsi_down_sum(previous_rsi)
            |> rsi_up_average(previous_rsi, index, period)
            |> rsi_down_average(previous_rsi, index, period)
            |> rsi_strength(index, period)
            |> rsi_index(index, period)

          [current_rsi | previous_items]
        end)
        |> Enum.map(fn x -> x.value end)
        |> Enum.reverse()

      {:ok, results}
    rescue
      e in Decimal.Error ->
        {:error, "An error occured while calculating the RSI value: " <> e.message}
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
        {cumulative_volume, cumulative_volume_price} =
          case acc do
            [] ->
              {0, @zero}

            [previous_vwap | _tail] ->
              {previous_vwap.cumulative_volume, previous_vwap.cumulative_volume_price}
          end

        case vwap(data_point, cumulative_volume, cumulative_volume_price) do
          {:ok, value} -> {:cont, [value | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
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
        cumulative_volume_price \\ @zero
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

  defp rsi_down_average(current_rsi, _previous_rsi, index, period) when index < period,
    do: current_rsi

  defp rsi_down_average(%{:down_sum => down_sum} = current_rsi, _previous_rsi, index, period)
       when index == period do
    %{current_rsi | down_average: calculate_simple_moving_average([down_sum], period)}
  end

  defp rsi_down_average(
         %{:down_movement => current_down_movement} = current_rsi,
         %{
           :down_average => previous_down_average
         } = _previous_rsi,
         _index,
         period
       ) do
    down_average =
      Decimal.mult(previous_down_average, Decimal.new(period - 1))
      |> Decimal.add(current_down_movement)
      |> Decimal.div(Decimal.new(period))

    %{current_rsi | down_average: down_average}
  end

  defp rsi_index(rsi_map, index, period) when index < period, do: rsi_map

  defp rsi_index(%{:relative_strength => relative_strength} = rsi_map, _index, _period) do
    max_rsi = Decimal.new(100)

    # RSI: 100 – 100 / ( 1 + relative_strength)
    first_calc = Decimal.new(1) |> Decimal.add(relative_strength)
    second_calc = Decimal.div(max_rsi, first_calc)

    relative_strength_index = Decimal.sub(max_rsi, second_calc)

    %{rsi_map | value: relative_strength_index}
  end

  defp rsi_strength(%{:down_average => @zero} = rsi_map, index, period) when index < period,
    do: rsi_map

  defp rsi_strength(
         %{
           :up_average => up_average,
           :down_average => down_average
         } = rsi_map,
         _index,
         _period
       ) do
    %{rsi_map | relative_strength: Decimal.div(up_average, down_average)}
  end

  defp rsi_up_sum(
         %{:up_movement => up_movement} = current_rsi,
         %{:up_sum => up_sum} = _previous_rsi
       ) do
    up_sum = Decimal.add(up_movement, up_sum)

    %{current_rsi | up_sum: up_sum}
  end

  defp rsi_down_sum(
         %{:down_movement => down_movement} = current_rsi,
         %{:down_sum => down_sum} = _previous_rsi
       ) do
    down_sum = Decimal.add(down_movement, down_sum)

    %{current_rsi | down_sum: down_sum}
  end

  defp rsi_down_movement(
         %{:previous_price => previous_price, :current_price => current_price} = rsi_map
       ) do
    diff = Decimal.sub(current_price, previous_price)

    case Decimal.lt?(diff, 0) do
      true -> %{rsi_map | down_movement: Decimal.abs(diff)}
      false -> %{rsi_map | down_movement: @zero}
    end
  end

  defp rsi_up_average(current_rsi, _previous_rsi, index, period) when index < period,
    do: current_rsi

  defp rsi_up_average(%{:up_sum => up_sum} = current_rsi, _previous_rsi, index, period)
       when index == period do
    %{current_rsi | up_average: calculate_simple_moving_average([up_sum], period)}
  end

  defp rsi_up_average(
         %{:up_movement => current_up_movement} = current_rsi,
         %{
           :up_average => previous_up_average
         } = _previous_rsi,
         _index,
         period
       ) do
    up_average =
      Decimal.mult(previous_up_average, Decimal.new(period - 1))
      |> Decimal.add(current_up_movement)
      |> Decimal.div(Decimal.new(period))

    %{current_rsi | up_average: up_average}
  end

  defp rsi_up_movement(
         %{:previous_price => previous_price, :current_price => current_price} = rsi_map
       ) do
    diff = Decimal.sub(current_price, previous_price)

    case Decimal.gt?(diff, 0) do
      true -> %{rsi_map | up_movement: diff}
      false -> %{rsi_map | up_movement: @zero}
    end
  end

  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  # create decimals from either strings, integers or decimals
  defp to_decimal(value), do: Decimal.new(value)

  defp weighted_multiplier(period) do
    period_increment = Decimal.new(period + 1)

    Decimal.new(2)
    |> Decimal.div(period_increment)
  end
end
