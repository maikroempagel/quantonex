defmodule Quantonex.Indicators do
  @moduledoc """
  Contains technical indicators.
  """

  alias Quantonex.DataPoint

  @typedoc """
  Represents a volume weighted average price.

    * `value` - the volume weighted average price.
    * `cumulative_volume` - the previous volume plus the current volume.
    * `cumulative_volume_price` - the previous volume price plus the current volume price.
  """
  @type vwap :: %{
          cumulative_volume: integer(),
          cumulative_volume_price: Decimal.t(),
          value: Decimal.t()
        }

  @doc """
  Calculates a simple moving average for a period that is equal to the length of the dataset.

  ## Examples

      iex> Quantonex.Indicators.sma([1, 2, 3])
      {:ok, Decimal.new(2)}
  """
  @spec sma(dataset :: list(number())) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}
  def sma(dataset), do: dataset |> sma(length(dataset))

  @doc """
  Calculates a simple moving average for a given dataset and period.

  The last n elements of the dataset are used for the calculation.

  ## Examples

      iex> Quantonex.Indicators.sma([1, 2, 3], 2)
      {:ok, Decimal.from_float(2.5)}

      iex> Quantonex.Indicators.sma([1, 2, 3], 1)
      {:error, "Period must be at least 2."}

      iex> Quantonex.Indicators.sma([1, 2, 3], 4)
      {:error, "Period can't be greater than the length of the dataset."}
  """
  @spec sma(dataset :: list(number()), period :: integer()) ::
          {:error, reason :: String.t()} | {:ok, value :: Decimal.t()}
  def sma(dataset, _period) when length(dataset) < 2,
    do: {:error, "There must be at least 2 elements in the dataset."}

  def sma(_dataset, period) when period < 2, do: {:error, "Period must be at least 2."}

  def sma(dataset, period) when period > length(dataset),
    do: {:error, "Period can't be greater than the length of the dataset."}

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
          cumulative_volume :: integer(),
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
end
