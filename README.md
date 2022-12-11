# TinkerBellSim

**TODO: Add description**

1. 「iex -S mix」で起動します
2. 「FAServer.start_link()」でAlgoServer,Device,Relay,Engineを表すプロセスが起動します
3. 「FAServer.start_assigning()」でタスク生成を開始します
4. 「FAServer.stop_assigning()」でタスク生成を開始します（現在、このコマンドから数秒経ってから停止する状態になっています）

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tinker_bell_sim` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tinker_bell_sim, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tinker_bell_sim>.

