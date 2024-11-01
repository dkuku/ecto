import Kernel, except: [apply: 2]

defmodule Ecto.Query.Builder.Comment do
  @moduledoc false

  alias Ecto.Query.Builder
  alias Ecto.Query.CommentExpr

  @spec escape(Macro.t(), Macro.Env.t()) :: Macro.t()
  def escape(comment, _env) when is_binary(comment), do: comment

  def escape(expr, env) do
    {expr, {_params, _acc}} =
      Builder.escape(expr, :any, {[], %{}}, [], env)

    expr
  end

  @doc """
  Called at runtime to assemble comment.
  """
  def comment!(query, comment, file, line, opts) do
    safe? = is_atom(comment)

    if safe? || opts[:validated] || opts[:escape], do: :noop, else: validate(comment)

    comment =
      if opts[:escape], do: URI.encode(comment, &URI.char_unreserved?/1), else: comment

    comment = %CommentExpr{
      expr: comment,
      line: line,
      file: file,
      cache: safe? || opts[:cache]
    }

    apply(query, comment)
  end

  def build(query, {:^, _, [var]}, opts, %Macro.Env{} = env) do
    quote do
      Ecto.Query.Builder.Comment.comment!(
        unquote(query),
        unquote(var),
        unquote(env.file),
        unquote(env.line),
        unquote(opts)
      )
    end
  end

  def build(query, comment, _opts, %Macro.Env{} = env) do
    Builder.apply_query(query, __MODULE__, [escape(comment, env)], env)
  end

  @doc """
  The callback applied by `build/4` to build the query.
  """
  @spec apply(Ecto.Queryable.t(), String.t() | CommentExpr.t()) :: Ecto.Query.t()
  def apply(%Ecto.Query{comments: comments} = query, comment) do
    %{query | comments: comments ++ [comment]}
  end

  def apply(query, comment) do
    apply(Ecto.Queryable.to_query(query), comment)
  end

  defp validate(comment) when is_binary(comment) do
    if String.contains?(comment, "*/") do
      raise ArgumentError, "comment must not contain a closing */ character"
    end

    comment
  end
end
