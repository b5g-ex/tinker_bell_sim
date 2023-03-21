# TinkerBellSim

**TODO: Add description**

使い方
1. 「iex -S mix」で起動します
2. 「FAServer.start_link(taskseed, engineseed, tasknumlimit)」でAlgoServer,Device,Relay,Engineを表すプロセスが起動します
  taskseed: タスク生成時間間隔・タスクの重さflo の乱数シード
  engineseed: engine flops, R-R Network Delay&BW の乱数シード
  tasknumlimit: 1タスクセットのタスク数
  （開発時はFAServer.start_link(100,10000,100)で起動しています）
3. 「FAServer.start_assigning()」でタスク生成を開始します
4. 応答時間・cluster利用コスト・Rela間通信遅延のデータが「responsetime.txt, clusterfee.txt, RtRDelay.txt」に保存されていき、
各タスクセットの平均が「responsetime_average.txt, clusterfee_average.txt, RtRDela_average.txt」に出力されます。
5. 「Giocci_enddevice.ex」の handle_cast(:set_algo) で指定された試行の終了後、「(RuntimeError) end」を吐いて終了します。

1タスクセットの割付・処理が終了すると、各種パラメータをリセットし、同じタスクセットの割付が始まります。
各試行で用いる割付アルゴリズムは、「Giocci_enddevice.ex」の36~41行目 handle_cast(:set_algo) で指定できます。

各種パラメータ設定
relay間通信遅延 fairly_algorithm_server 31行目
計算資源利用コスト定義に用いる変数a,b fairly_algorithm_server 570行目
device, relay, engine の数 fairly_algorithm_server 573行目

fairly_algorithm_server (module FAServer)
  API関数
    start_link(taskseed, engineseed, tasknumlimit)
      AlgoServer,Device,Relay,Engineを表すプロセスを起動する
      taskseed: タスク生成時間間隔・タスクの重さflo の乱数シード
      engineseed: engine flops, R-R Network Delay&BW の乱数シード
      tasknumlimit: 1タスクセットのタスク数
    start_assigning()
      タスクの生成・割付・処理を開始する
    stop_assigning()
      タスクの生成・割付・処理を終了する
      通常は指定された数のタスクを処理して自動終了するため、この関数を使う必要はない。
  内部関数
    handle_call :get_relaymap
    handle_call {:append_relayinfo, pid, relayinfo}
    handle_call {:append_relaynetwork_feature_table, relaynetworkseed}
    handle_cast :initialize_tasknum
    handle_call {:append_tasknumlimit, tasknumlimit}
    handle_cast {:initialize_creating_task_flag, initial_flag}
    handle_call {:assign_algorithm, device_connected_relaypid, task}
    handle_cast {:relay_finish_handling_task, relaypid}
    handle_cast :wait_for_tasklists
    handle_cast :initialize_parameters
    handle_cast {:update_relaymap, relaypid, new_relayinfo}

giocci_enddevice (module EndDevice)
  API関数
    start_link(deviceinfo)
      FAServer.start_link()内で自動的に呼ばれるため、通常この関数を使う必要はない。
  内部関数
    handle_cast :taskflag_true
    handle_cast :taskflag_false
    handle_cast {:set_randomseed, seed}
    handle_cast {:set_algo, algonum}
    handle_cast :create_task

giocci_relay_server (module GRServer)
  API関数
    start_link(randomseed, costmodel)
      FAServer.start_link()内で自動的に呼ばれるため、通常この関数を使う必要はない。
  内部関数

giocci_engine_server (GEServer)
  API関数
    start_link(engineinfo)
      FAServer.start_link()内で自動的に呼ばれるため、通常この関数を使う必要はない。
  内部関数


(readme updated 2023/03/21)

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

