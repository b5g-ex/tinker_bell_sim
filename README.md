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

各種パラメータ設定箇所
relay間通信遅延 fairly_algorithm_server 31行目
計算資源利用コスト定義に用いる変数a,b   fairly_algorithm_server 570行目 (costmodel)
device, relay, engine の数    fairly_algorithm_server 573行目 (relayrandomseed)
各試行で用いる割付アルゴリズム    Giocci_enddevice.ex :set_algo
タスク生成間隔時間・タスクの重さ    Giocci_enddevice.ex :create_task
応答時間予測値の計算方法・応答時間予測値の計算におけるパラメータr   Giocci_relay_server.ex :initialize_clusterinfo
engine flops    Giocci_engine_server.ex :initialize_engineinfo

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
      fairly-algorithm serverの状態変数mapを返す
    handle_call {:append_relayinfo, pid, relayinfo}
      fairly-algorithm serverの状態変数mapに（key:新規relayのPID, val:新規relayの状態変数）を追加
    handle_call {:append_relaynetwork_feature_table, relaynetworkseed}
      relay間通信路の通信遅延（・帯域幅）を乱数生成し、fairly-algorithm serverの状態変数mapに保存
    handle_cast :initialize_tasknum
      生成されたタスク数のカウンターを初期化
    handle_call {:append_tasknumlimit, tasknumlimit}
      FAServer起動時の第3引数で与えられた、1タスクセット当たりのタスク数をfairly-algorithm serverの状態変数mapに保存
    handle_cast {:initialize_creating_task_flag, initial_flag}
      fairly-algorithm serverでは各Deviceがタスクを生成する状態にあるかどうか（true/false）を、Deviceが接続しているRelay単位で管理している。本関数は、Deviceが存在するrelayに対し、そのタスク生成状態（true/false）をinitial_flagに設定する。
    handle_call {:assign_algorithm, device_connected_relaypid, task}
      relayからの問い合わせに応じて、タスクの割付先Clusterを決定する。
    handle_cast {:relay_finish_handling_task, relaypid}
      あるrelayに接続する全てのDeviceでタスク生成が終了したときに、relayから自動的に呼び出される。そのrelayがタスク生成状態にあるかどうか（true/false）を示すfairly-algorithm server内の情報をfalseに設定する。その後、:wait_for_tasklistsを呼び出す。
    handle_cast :wait_for_tasklists
      全てのClusterで処理待ちタスクがなくなるまで待機する。その後:initialize_parametersを呼び出す。
    handle_cast :initialize_parameters
      各種変数の初期化処理を行い、次のタスクセットのシミュレーションを開始する。
    handle_cast {:update_relaymap, relaypid, new_relayinfo}
      各Cluster単位の計算資源情報をfairly-algorithm server上の状態変数へ更新する。ここでは処理の簡単化のため、relayの状態変数をまるごとコピーしているが、本来Cluster単位の情報だけでよい。

giocci_enddevice (module EndDevice)
  API関数
    start_link(deviceinfo)
      FAServer.start_link()内で自動的に呼ばれるため、通常この関数を使う必要はない。
  内部関数
    handle_cast :taskflag_true
      Deviceのタスク生成状態をtrueにする。
    handle_cast :taskflag_false
      Deviceのタスク生成状態をfalseにする。
    handle_cast {:set_randomseed, seed}
      Device内の処理に用いるランダムシードを設定する。
    handle_cast {:set_algo, algonum}
      n回目のシミュレーションでどの資源配分手法を用いるかを設定する。
    handle_cast :create_task
    　タスクを生成する。

giocci_relay_server (module GRServer)
  API関数
    start_link(randomseed, costmodel)
      FAServer.start_link()内で自動的に呼ばれるため、通常この関数を使う必要はない。
  内部関数
    handle_call {:append_engineinfo, pid, engineinfo}
      relayの状態変数に、新規engineの情報を追加する。
    handle_call {:append_deviceinfo, pid, deviceinfo}
      relayの状態変数に、新規deviceの情報を追加する。
    handle_cast :initialize_clusterinfo
      cluster単位の計算資源情報clusterinfoを初期化する。
    handle_call :update_clusterinfo
      cluster単位の計算資源情報clusterinfoを更新する。
    handle_cast {:send_task_response_time_in_cluster, processed_task, task_response_time_in_cluster}
      cluster内処理時間の実測値・発生した計算資源利用コストをファイルへ記録する。
      その後、cluster内処理時間の実測値を用いて、cluster内処理時間の予測値を更新する。
    handle_cast {:record_responsetime, processed_task}
      応答時間を測定し、記録する。
    handle_call :get_relayinfo
      relayの状態変数を返す。
    handle_cast :start_assigning
      各Deviceのtaskflagを変更し、タスクを生成する状態にする。
    handle_cast :stop_assigning
      各Deviceのtaskflagを変更し、タスクを生成しない状態にする。
    handle_call {:assign_request, task}
      Deviceからタスクのオフロード依頼を受け、割付先Clusterを資源配分サーバに問い合わせる。
    handle_cast {:assign_task_in_cluster, task, rtr_delay}
      自分のClusterに割り付けられてきたタスクについて、その割付先Engineを決定し、割り付ける。
    handle_cast {:update_engine_taskque_in_enginemap, task, assigned_engine_pid}
      relayが持っている、Engine上のタスクキュー情報を更新する。
    handle_cast {:update_enginemap, enginepid, new_engineinfo}
      engineの状態変数を受け取り、relayの状態変数内に記録する。
    handle_cast {:device_finish_creating_task, devicepid}
      Deviceから、そのDeviceがタスクを生成しない状態になった（taskflagがfalseになった）という通知を受け、relayの状態変数内の情報を更新する。自Relayに接続する全てのDeviceでタスクを生成しない状態になったとき、:relay_finish_handling_taskを呼び出す。
    handle_call :initialize_clusterinfo_and_taskseed
      clusterinfoやランダムシード値を初期化し、次のシミュレーションで同じタスクセットを再現できるようにする。

giocci_engine_server (GEServer)
  API関数
    start_link(engineinfo)
      FAServer.start_link()内で自動的に呼ばれるため、通常この関数を使う必要はない。
  内部関数
    handle_call :get_engineinfo
      engineの状態変数を返す。
    handle_call :initialize_engineinfo
      engineの状態変数を初期化する。
    handle_cast :update_engineinfo
      engineの計算資源情報をRelayへ送信する。ここでは簡単のため、engineの状態変数を丸ごと渡している。
    handle_cast {:assign_task_to_engine, task, rtr_delay}
      Relayからタスクを引き受け、engineのタスクキューへ格納する。
    handle_cast :process_a_task
      タスクを処理する。タスクキューが空でない場合、再帰的に実行される。


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

