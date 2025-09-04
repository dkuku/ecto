<img width="250" src="https://github.com/elixir-ecto/ecto/raw/master/guides/images/logo.png#gh-light-mode-only" alt="Ecto">
<img width="250" src="https://github.com/elixir-ecto/ecto/raw/master/guides/images/logo-white.png#gh-dark-mode-only" alt="Ecto">

---

This is a fork of ecto with experimental comments support:

Add comment to the generated SQL.

In SQL queries, comment parameters are unique compared to other
parameters. Standard parameters are represented by placeholders like ?,
which the database engine binds to actual values. These parameters are
placed in query clauses, such as WHERE or ORDER BY, and directly affect
query execution by impacting filtering, sorting, or joining operations.

However, unlike other parameters, dynamic comments can affect both caching
and prepared statements in Ecto. Each unique dynamic comment changes the
generated SQL, preventing caching and causing new prepared statements
to be created repeatedly. In these cases, caching doesn’t make sense,
as it could lead to cache pollution—storing many slightly different
versions of essentially the same query, which reduces cache efficiency.

For frequently changing dynamic comments, consider sampling or other
strategies to limit the variety of comments and maintain caching
effectiveness.

- Runtime comments from pinned variables are not cached by default since
inserting dynamic values into the query makes each query unique, making
caching ineffective. You can override this behavior if your dynamic values
have only a few distinct values.
- Compile-time comments are cached and do not add any overhead to caching.
- Atoms are cached, and since atoms should not be created dynamically,
caching should remain effective.
- Dynamic values where the config option cache: true is provided.
Use this only if you're confident in your use case. :)

```elixir
    dynamic_value = "not cached by default"
    dynamic_atom = :cached
    query =
      Post
      |> comment(^dynamic_value)                # this is not cached
      |> comment("this is a cached comment")    # this is cached
      |> comment(^dynamic_atom)                 # this is cached
      |> comment(^dynamic_value, cache: true)   # this is cached
```

Comments are collected - the above will return a list containing all the comments.

Dynamic strings are validated for containing `*/` string.
it can be overridden by passing `validated: true` option when you are sure that it's safe.

A comment can be url escaped by passing `escape: true` option.
In this case the validation is skipped because it's safe in this case.

## Sample 1% of queries

Here's an example of how you can sample 1% of queries to add a dynamic comment without heavily
impacting caching or prepared statements. By randomly adding comments to only a small percentage
of queries, you can reduce cache pollution and repeated preparation of statements while still
getting some traces for debugging or monitoring purposes.

```elixir
    defp sample_comment(query, comment_text) do
      if :rand.uniform(100) == 1 do
        comment(query, comment_text)
      else
        query
      end
    end

    query =
      Post
      |> sample_comment("Sampled for monitoring")
```

## Add it globally to your app

Modify your Repo module

```elixir
    defmodule MyApp.Repo do
      require Ecto.Query

      use Ecto.Repo,
        otp_app: :sqlcomm,
        adapter: Ecto.Adapters.Postgres

      def default_options(_operation) do
        [stacktrace: true]
      end

      def prepare_query(_operation, query, opts) do
        caller = Sqlcommenter.extract_repo_caller(opts, __MODULE__)
        sqlcommenter = [app: "sqlcomm", caller: Sqlcommenter.escape(caller), team: "team_sql"]
        comment = Sqlcommenter.to_str(sqlcommenter)
        {Ecto.Query.comment(query, ^comment, cache: true, validated: true), opts}
      end
    end
```

A bit more performant version

```elixir
    defmodule MyApp.Repo do
      require Ecto.Query

      use Ecto.Repo,
        otp_app: :sqlcomm,
        adapter: Ecto.Adapters.Postgres

      def default_options(_operation) do
        [stacktrace: true]
      end

      def prepare_query(_operation, query, opts) do
        if opts[:sqlcomment] do
          {Ecto.Query.comment(query, ^opts[:sqlcomment], validated: true), opts}
        else
          caller = Sqlcommenter.extract_repo_caller(opts, __MODULE__)
          sqlcommenter = [app: "sqlcomm", caller: Sqlcommenter.escape(caller), team: "team_sql"]
          comment = generate_comment(sqlcommenter)
          {Ecto.Query.comment(query, ^comment, cache: true, validated: true), opts}
        end
      end

      def generate_comment(sqlcommenter) do
        for({k, v} <- sqlcommenter, do: [Atom.to_string(k), "='", v, ?']) |> Enum.intersperse(",")
      end
    end
```

## Installation

Add `:ecto` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
      {:ecto, github: "dkuku/ecto", ref: "comments_in_query", override: true},
      {:ecto_sql, github: "dkuku/ecto_sql", ref: "comments_in_query", override: true},
      {:sqlcommenter, github: "dkuku/sqlcommenter"},
  ]
end
```

## About

Ecto is a toolkit for data mapping and language integrated query for Elixir. Here is an example:

```elixir
# In your config/config.exs file
config :my_app, ecto_repos: [Sample.Repo]

config :my_app, Sample.Repo,
  database: "ecto_simple",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: "5432"

# In your application code
defmodule Sample.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres
end

defmodule Sample.Weather do
  use Ecto.Schema

  schema "weather" do
    field :city     # Defaults to type :string
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp,    :float, default: 0.0
  end
end

defmodule Sample.App do
  import Ecto.Query
  alias Sample.{Weather, Repo}

  def keyword_query do
    query =
      from w in Weather,
           where: w.prcp > 0 or is_nil(w.prcp),
           select: w

    Repo.all(query)
  end

  def pipe_query do
    Weather
    |> where(city: "Kraków")
    |> order_by(:temp_lo)
    |> limit(10)
    |> Repo.all
  end
end
```

Ecto is commonly used to interact with databases, such as PostgreSQL and MySQL via [Ecto.Adapters.SQL](https://hexdocs.pm/ecto_sql) ([source code](https://github.com/elixir-ecto/ecto_sql)). Ecto is also commonly used to map data from any source into Elixir structs, whether they are backed by a database or not.

See the [getting started guide](https://hexdocs.pm/ecto/getting-started.html) and the [online documentation](https://hexdocs.pm/ecto) for more information. Other resources available are:

  * [Programming Ecto](https://pragprog.com/titles/wmecto/programming-ecto/), by Darin Wilson and Eric Meadows-Jönsson, which guides you from fundamentals up to advanced concepts

  * [The Little Ecto Cookbook](https://dashbit.co/ebooks/the-little-ecto-cookbook), a free ebook by Dashbit, which is a curation of the existing Ecto guides with some extra contents

## Usage

You need to add both Ecto and the database adapter as a dependency to your `mix.exs` file. The supported databases and their adapters are:

| Database   | Ecto Adapter             | Dependencies                                     |
| :--------- | :----------------------- | :----------------------------------------------- |
| PostgreSQL | Ecto.Adapters.Postgres   | [ecto_sql][ecto_sql] + [postgrex][postgrex]      |
| MySQL      | Ecto.Adapters.MyXQL      | [ecto_sql][ecto_sql] + [myxql][myxql]            |
| MSSQL      | Ecto.Adapters.Tds        | [ecto_sql][ecto_sql] + [tds][tds]                |
| SQLite3    | Ecto.Adapters.SQLite3    | [ecto_sqlite3][ecto_sqlite3]                     |
| ClickHouse | Ecto.Adapters.ClickHouse | [ecto_ch][ecto_ch]                               |
| ETS        | Etso                     | [etso][etso]                                     |

[ecto_sql]: https://github.com/elixir-ecto/ecto_sql
[postgrex]: https://github.com/elixir-ecto/postgrex
[myxql]: https://github.com/elixir-ecto/myxql
[tds]: https://github.com/livehelpnow/tds
[ecto_sqlite3]: https://github.com/elixir-sqlite/ecto_sqlite3
[etso]: https://github.com/evadne/etso
[ecto_ch]: https://github.com/plausible/ecto_ch

For example, if you want to use PostgreSQL, add to your `mix.exs` file:

```elixir
defp deps do
  [
    {:ecto_sql, "~> 3.0"},
    {:postgrex, ">= 0.0.0"}
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies. If you want to use another database, just choose the proper dependency from the table above.

Finally, in the repository definition, you will need to specify the `adapter:` respective to the chosen dependency. For PostgreSQL it is:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres,
  ...
```

### IPv6 support

If your database's host resolves to ipv6 address you should
add `socket_options: [:inet6]` to configuration block like below:

```elixir
import Mix.Config

config :my_app, MyApp.Repo,
  hostname: "db12.dc0.comp.any",
  socket_options: [:inet6],
  ...
```

## Supported Versions

| Branch            | Support                  |
| ----------------- | ------------------------ |
| v3.12             | Bug fixes                |
| v3.11             | Security patches only    |
| v3.10             | Security patches only    |
| v3.9              | Security patches only    |
| v3.8              | Security patches only    |
| v3.7 and earlier  | Unsupported              |

With version 3.0, Ecto API has become stable. Our main focus is on providing
bug fixes and incremental changes.

## Important links

  * [Documentation](https://hexdocs.pm/ecto)
  * [Mailing list](https://groups.google.com/forum/#!forum/elixir-ecto)
  * [Examples](https://github.com/elixir-ecto/ecto/tree/master/examples)

## Running tests

Clone the repo and fetch its dependencies:

    $ git clone https://github.com/elixir-ecto/ecto.git
    $ cd ecto
    $ mix deps.get
    $ mix test

Note that `mix test` does not run the tests in the `integration_test` folder. To run integration tests, you can clone `ecto_sql` in a sibling directory and then run its integration tests with the `ECTO_PATH` environment variable pointing to your Ecto checkout:

    $ cd ..
    $ git clone https://github.com/elixir-ecto/ecto_sql.git
    $ cd ecto_sql
    $ mix deps.get
    $ ECTO_PATH=../ecto mix test.all

### Running containerized tests

It is also possible to run the integration tests under a containerized environment using [earthly](https://earthly.dev/get-earthly):

    $ earthly -P +all

You can also use this to interactively debug any failing integration tests using:

    $ earthly -P -i --build-arg ELIXIR_BASE=1.8.2-erlang-21.3.8.21-alpine-3.13.1 +integration-test

Then once you enter the containerized shell, you can inspect the underlying databases with the respective commands:

    PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -d postgres ecto_test
    MYSQL_PASSWORD=root mysql -h 127.0.0.1 -uroot -proot ecto_test
    sqlcmd -U sa -P 'some!Password'

## Logo

"Ecto" and the Ecto logo are Copyright (c) 2020 Dashbit.

The Ecto logo was designed by [Dane Wesolko](https://www.danewesolko.com).

## License

Copyright (c) 2013 Plataformatec \
Copyright (c) 2020 Dashbit

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [https://www.apache.org/licenses/LICENSE-2.0](https://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
