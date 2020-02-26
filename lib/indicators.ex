defmodule Quantonex.Indicators do
  @moduledoc """
  Contains technical indicators.
  """

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

  # Helpers

  defp create_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp create_decimal(value), do: Decimal.new(value)
end
