defmodule Quantonex.Indicators do
  @moduledoc """
  Contains technical indicators.
  """

  alias Quantonex.DataPoint

  @dataset_min_size_error "There must be at least 1 element in the dataset."
  @rsi_dataset_min_size_error "There must be at least 2 elements in the dataset."
  @period_min_value_error "Period must be at least 1."
  @rsi_period_min_value_error "Period must be at least 2."
  @period_max_value_error "Period can't be greater than the length of the dataset."

  @ema_calc_error "An error occured while calculating the EMA value."
  @rsi_calc_error "An error occured while calculating the RSI value."

  @typedoc """
  Represents a volume weighted average price.

    * `value` - the volume weighted average price.
    * `cumulative_volume` - the previous volume plus the current volume.
    * `cumulative_volume_price` - the previous volume price plus the current volume price.
  """
  @type vwap :: %{
          cumulative_volume: non_neg_integer(),
          cumulative_volume_price: Decimal.t(),
          value: Decimal.t()
        }

  @typedoc """
  Identifies a smoothing method.

    * `ema` - exponential moving average
    * `sma` - simple moving average
  """
  @type smoothing_method :: :ema | :sma

  @doc """
  Calculates an exponential moving average for a period that is equal to the length of the dataset.

  The first price within the period is used as seed for the calculation of the exponential moving average.

  ## Examples

  ```
  dataset = 1..100 |> Enum.map(fn x -> x end)
  Quantonex.Indicators.ema(dataset)
  {:ok, #Decimal<57.33397616251147565606871631>}
  ```
  """
  @spec ema(dataset :: nonempty_list(String.t() | number())) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}

  def ema(dataset) when is_list(dataset), do: ema(dataset, length(dataset))

  @doc """
  Calculates an exponential moving average for a given dataset and period.

  The last `n` elements of the dataset are used for the calculation with `n == period`.
  The first price within the period is used as seed for the calculation of the exponential moving average.

  ## Examples

  ```
  dataset = 1..100 |> Enum.map(fn x -> x end)
  Quantonex.Indicators.ema(1..100, 50)
  {:ok, #Decimal<78.95012934442930569062237731>}
  ```
  """
  @spec ema(dataset :: nonempty_list(String.t() | number()), period :: pos_integer()) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}

  def ema(dataset, _period) when is_list(dataset) and length(dataset) < 1,
    do: {:error, @dataset_min_size_error}

  def ema(dataset, period) when is_list(dataset) and period < 1,
    do: {:error, @period_min_value_error}

  def ema(dataset, period) when is_list(dataset) and period > length(dataset),
    do: {:error, @period_max_value_error}

  def ema(dataset, period) when is_list(dataset) do
    try do
      # use only the last number of elements
      start_index = length(dataset) - period
      end_index = length(dataset) - 1
      range = start_index..end_index

      # the first price is used as previous ema
      # the subsequent prices are used for the ema caluclation
      [previous_ema | rest] = dataset |> Enum.slice(range)

      # make sure the value can be converted to a decimal
      previous_ema = previous_ema |> to_decimal()

      result =
        rest
        # create decimals from either strings, integers or floats
        |> Enum.map(&to_decimal/1)
        |> Enum.reduce_while(previous_ema, fn current_price, acc ->
          # calculate the current ema and handle the different return types
          case ema(current_price, period, acc) do
            {:ok, value} -> {:cont, value}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      case result do
        {:error, reason} ->
          {:error, reason}

        value ->
          {:ok, value}
      end
    rescue
      _ in Decimal.Error -> {:error, @ema_calc_error}
    end
  end

  defp ema(price, period, previous_ema) do
    try do
      previous_ema = to_decimal(previous_ema)
      multiplier = weighted_multiplier(period)
      result = previous_ema |> Decimal.mult(Decimal.sub(1, multiplier))

      value =
        price
        |> Decimal.mult(multiplier)
        |> Decimal.add(result)

      {:ok, value}
    rescue
      _ in Decimal.Error ->
        {:error, @ema_calc_error}
    end
  end

  @doc """
  Calculates the relative strength index for a dataset and period.
  """
  @spec rsi(
          dataset :: nonempty_list(String.t() | number()),
          smoothing_method :: smoothing_method(),
          period :: non_neg_integer()
        ) ::
          {:error, reason :: String.t()} | {:ok, rsi :: Decimal.t()}

  # we need at least 2 elements
  def rsi(dataset, _smoothing_method, _period) when is_list(dataset) and length(dataset) < 2,
    do: {:error, @rsi_dataset_min_size_error}

  # period can't be less than 1
  def rsi(dataset, _smoothing_method, period) when is_list(dataset) and period < 1,
    do: {:error, @rsi_period_min_value_error}

  def rsi(dataset, _smoothing_method, period)
      when is_list(dataset) and period > length(dataset) - 1,
      do: {:error, @period_max_value_error}

  def rsi(dataset, :ema, period), do: calculate_rsi(dataset, period, &ema/2)

  # def rsi(dataset, :sma, period), do: calculate_rsi(dataset, period, &sma/2)

  defp calculate_rsi(dataset, period, fun) do
    try do
      {_price, up_moves, down_moves} =
        dataset
        |> create_ranged_dataset(period + 1)
        |> calculate_up_and_down_movements()

      {:ok, average_up} =
        up_moves
        |> fun.(period)

      {:ok, average_down} =
        down_moves
        |> fun.(period)

      {:ok, calculate_relative_strength_index(average_up, average_down)}
    rescue
      _ in Decimal.Error ->
        {:error, @rsi_calc_error}
    end
  end

  @doc """
  Calculates a simple moving average (SMA) for a given dataset.

  The period of the SMA is fixed and equal to the length of the dataset.

  The return value is one of the following:

  * `{:error, reason}`
  * `{:ok, value}`

  ## Examples

    iex> Quantonex.Indicators.sma([1, 2, 3])
    {:ok, Decimal.new(2)}
  """
  @spec sma(dataset :: nonempty_list(String.t() | number())) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}
  def sma([]), do: {:error, @dataset_min_size_error}

  def sma(dataset) do
    try do
      value = dataset |> calculate_simple_moving_average()

      {:ok, value}
    rescue
      e in RuntimeError ->
        {:error, "An error occured while calculating the SMA value: " <> e.message}

      e in Decimal.Error ->
        {:error, "An error occured while calculating the SMA value: " <> e.message}
    end
  end

  @doc """
  Calculates a volume weighted average price.

  To calculate the initial vwap value, both `cumulative_volume` and `cumulative_volume_price` are set to `0`.

  ```
  data_point = %Quantonex.DataPoint{
    complete: true,
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

  Any subsequent calculation can be done by passing the previously calculated cumulative values to
  the function.

  ```
  next_data_point = %Quantonex.DataPoint{
    complete: false,
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
          {:error, reason :: String.t()} | {:ok, value :: vwap()}
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
      _ in Decimal.Error ->
        {:error, "An error occured while calculating the VWAP value."}
    end
  end

  ## Helpers

  defp calculate_simple_moving_average(dataset) do
    dataset
    |> Enum.map(&to_decimal/1)
    |> Enum.reduce(fn x, acc -> Decimal.add(x, acc) end)
    |> calculate_average(length(dataset))
  end

  defp calculate_average(sum, divisor), do: Decimal.div(sum, Decimal.new(divisor))

  defp calculate_relative_strength_index(average_up, average_down) do
    max_rsi = Decimal.new(100)

    # no down movements
    if Decimal.equal?(average_down, Decimal.new(0)) do
      max_rsi
    else
      relative_strength = Decimal.div(average_up, average_down)

      # RSI: 100 – 100 / ( 1 + relative_strength)
      first_calc = Decimal.new(1) |> Decimal.add(relative_strength)
      second_calc = Decimal.div(max_rsi, first_calc)

      Decimal.sub(max_rsi, second_calc)
    end
  end

  defp calculate_up_move(previous_price, current_price) do
    diff = Decimal.sub(current_price, previous_price)

    case Decimal.gt?(diff, 0) do
      true -> diff
      false -> Decimal.new(0)
    end
  end

  defp calculate_down_move(previous_price, current_price) do
    diff = Decimal.sub(current_price, previous_price)

    case Decimal.lt?(diff, 0) do
      true -> Decimal.abs(diff)
      false -> Decimal.new(0)
    end
  end

  defp calculate_up_and_down_movements(dataset) do
    dataset
    |> Enum.reduce({}, fn current_price, acc ->
      case acc do
        # first iteration
        {} ->
          {current_price, [], []}

        # subsequent iterations
        {previous_price, up_movements, down_movements} ->
          up_movements = [calculate_up_move(previous_price, current_price) | up_movements]
          down_movements = [calculate_down_move(previous_price, current_price) | down_movements]

          {current_price, up_movements, down_movements}
      end
    end)
  end

  defp create_ranged_dataset(dataset, period) do
    # use only the last n elements
    start_index = length(dataset) - period
    end_index = length(dataset) - 1
    range = start_index..end_index

    # the first price is used as previous ema
    # the subsequent prices are used for the ema caluclation
    dataset
    |> Enum.slice(range)
    # create decimals from either strings, integers or floats
    |> Enum.map(&to_decimal/1)
  end

  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  # create decimals from either strings, integers or decimals
  defp to_decimal(value), do: Decimal.new(value)

  defp weighted_multiplier(period) do
    period_increment = Decimal.new(period + 1)

    Decimal.new(2)
    |> Decimal.div(period_increment)
  end

  defp second_element([_head | []]), do: nil
  defp second_element(dataset), do: dataset[1]
end
