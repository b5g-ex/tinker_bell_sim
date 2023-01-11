# TinkerBellSim

**TODO: Add description**

同一のタスクセットに関して、アルゴリズムを変更しながら繰り返し計測できます。
※試行ごとに乱数シード値を変えることはできません

1. 「iex -S mix」で起動します
2. 「FAServer.start_link(taskseed, engineseed, tasknumlimit)」でAlgoServer,Device,Relay,Engineを表すプロセスが起動します
  taskseed: タスク生成時間間隔・タスクの重さfloの乱数シード
  engineseed: engine flops, R-R Network Delay&BW の乱数シード
  tasknumlimit: 1タスクセットのタスク数
  （開発時はFAServer.start_link(100,10000,100)で起動しています）
3. 「FAServer.start_assigning()」でタスク生成を開始します
4. 応答時間・cluster利用コストのデータが「responsetime.txt, clusterfee.txt」に一時保存されていき、
その平均が「responsetime_average.txt, clusterfee_average.txt」に出力されます。
5. 「Giocci_enddevice.ex」の36~41行目 handle_cast(:set_algo) で指定された試行の終了後、「(RuntimeError) end」を吐いて終了します。

1タスクセットの割付・処理が終了すると、各種パラメータをリセットし、同じタスクセットの割付が始まります。
各試行で用いる割付アルゴリズムは、「Giocci_enddevice.ex」の36~41行目 handle_cast(:set_algo) で指定できます。

(readme updated 2023/01/11 20:42)

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

