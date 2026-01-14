Code.require_file("../../../support/eval_helpers.exs", __DIR__)

defmodule Ecto.Query.Builder.CommentTest do
  use ExUnit.Case, async: true

  doctest Ecto.Query.Builder.Comment

  import Ecto.Query
  import Support.EvalHelpers

  test "raises on invalid comment" do
    assert_raise ArgumentError, "comment must not contain a closing */ character", fn ->
      quote_and_eval(%Ecto.Query{} |> comment(^"*/"))
    end
  end

  test "allows for skipping validation on invalid comment" do
    quote_and_eval(%Ecto.Query{} |> comment(^"*/", validated: true))
  end

  test "comment with string" do
    query = %Ecto.Query{} |> comment("FOO")
    assert query.comments == ["FOO"]
  end

  test "comment with atom" do
    query = "posts" |> comment(:foo)
    assert query.comments == [:foo]
  end

  test "comment with variable" do
    query = %Ecto.Query{} |> comment(^"FOO")
    assert [%Ecto.Query.CommentExpr{expr: "FOO"}] = query.comments
  end

  test "comment with variable can be escaped" do
    query = %Ecto.Query{} |> comment(^"F/O O", escape: true)
    assert [%Ecto.Query.CommentExpr{expr: "F%2FO%20O"}] = query.comments
  end

  test "duplicated comment" do
    query = %Ecto.Query{} |> comment("FOO") |> comment("BAR")
    assert query.comments == ["FOO", "BAR"]
  end
end
