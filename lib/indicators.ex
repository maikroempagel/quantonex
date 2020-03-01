defmodule Quantonex.Indicators do
  @moduledoc """
  Contains technical indicators.
  """

  alias Quantonex.DataPoint

  @dataset_min_size_error "There must be at least 1 element in the dataset."
  @period_min_value_error "Period must be at least 1."
  @period_max_value_error "Period can't be greater than the length of the dataset."

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
  @spec ema(dataset :: nonempty_list(number())) ::
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
  @spec ema(dataset :: nonempty_list(number()), period :: pos_integer()) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}
  def ema(dataset, period) when is_list(dataset) and period <= 0,
    do: {:error, @period_min_value_error}

  def ema(dataset, period) when is_list(dataset) and period > length(dataset),
    do: {:error, @period_max_value_error}

  def ema(dataset, period) when is_list(dataset) do
    # use only the last number of elements
    start_index = length(dataset) - period
    end_index = length(dataset) - 1
    range = start_index..end_index

    # the first price is used as previous ema
    # the subsequent prices are used for the ema caluclation
    [previous_ema | rest] = dataset |> Enum.slice(range)

    result =
      rest
      # create decimals from either integers or floats
      |> Enum.map(&create_decimal/1)
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
  end

  defp ema(price, period, previous_ema) do
    try do
      previous_ema = create_decimal(previous_ema)
      multiplier = weighted_multiplier(period)
      result = previous_ema |> Decimal.mult(Decimal.sub(1, multiplier))

      value =
        price
        |> Decimal.mult(multiplier)
        |> Decimal.add(result)

      {:ok, value}
    rescue
      _ in Decimal.Error ->
        {:error, "An error occured while calculating the EMA value."}
    end
  end

  @doc """
  Calculates a simple moving average for a period that is equal to the length of the dataset.

  ## Examples

      iex> Quantonex.Indicators.sma([1, 2, 3])
      {:ok, Decimal.new(2)}
  """
  @spec sma(dataset :: nonempty_list(number())) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}
  def sma(dataset), do: dataset |> sma(length(dataset))

  @doc """
  Calculates a simple moving average for a given dataset and period.

  The last `n` elements of the dataset are used for the calculation with `n == period`.

  ## Examples

      iex> Quantonex.Indicators.sma([1, 2, 3], 2)
      {:ok, Decimal.from_float(2.5)}

      iex> Quantonex.Indicators.sma([1, 2, 3], 4)
      {:error, "Period can't be greater than the length of the dataset."}
  """
  @spec sma(dataset :: nonempty_list(number()), period :: pos_integer()) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}
  def sma([], _period),
    do: {:error, @dataset_min_size_error}

  def sma(_dataset, period) when period < 1, do: {:error, @period_min_value_error}

  def sma(dataset, period) when period > length(dataset),
    do: {:error, @period_max_value_error}

  def sma(dataset, period) do
    try do
      value =
        dataset
        |> Enum.reverse()
        |> Enum.take(period)
        |> Enum.map(&create_decimal/1)
        |> Enum.reduce(fn x, acc -> Decimal.add(x, acc) end)
        |> Decimal.div(period)

      {:ok, value}
    rescue
      _ in Decimal.Error ->
        {:error, "One of the elements in the dataset is non-numeric."}
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

  # Helpers

  defp create_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp create_decimal(value), do: Decimal.new(value)

  defp weighted_multiplier(period) do
    period_increment = Decimal.new(period + 1)

    Decimal.new(2)
    |> Decimal.div(period_increment)
  end
end
