defmodule Quantonex.IndicatorsTest do
  use ExUnit.Case

  @dataset_error "There must be at least 2 elements in the dataset."

  test "sma/1: invalid empty dataset and implicit period" do
    assert Quantonex.Indicators.sma([]) == {:error, @dataset_error}
  end

  test "sma/1: invalid non-empty dataset and implicit period" do
    assert Quantonex.Indicators.sma([1]) == {:error, @dataset_error}
  end

  test "sma/1: valid non-empty integer dataset and implicit period" do
    assert Quantonex.Indicators.sma([1, 2, 3]) == {:ok, Decimal.new(2)}
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

  test "sma/2: valid non-empty dataset and explicit invalid period" do
    assert Quantonex.Indicators.sma([1, 2, 3], 1) == {:error, "Period must be at least 2."}
  end

  test "sma/2: valid non-empty dataset and invalid period greater than dataset length" do
    assert Quantonex.Indicators.sma([1, 2, 3], 4) ==
             {:error, "Period can't be greater than the length of the dataset."}
  end

  test "sma/2: valid non-empty integer dataset and explicit valid period" do
    assert Quantonex.Indicators.sma([1, 2, 3], 2) == {:ok, Decimal.from_float(2.5)}
  end
end
