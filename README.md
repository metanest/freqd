# freqd の設計と実装
## はじめに
freqd は、FreeBSD 標準の powerd が自分の環境でうまく働いてくれないので、
代替のために自分用に実装した CPU 周波数制御アプリです。
## 特徴
特権分離により、awk スクリプトによる柔軟で自由にカスタマイズ可能な周波数の
決定と、安全性の両方を実現しています。特権状態で動くコードは、初期設定の後は
CPU 周波数変更以外の機能を持ちません。
## インストールと実行
 $ ./configure
 $ make
 $ su
 # ./freqd
## コンポーネント
* freqd.awk - top コマンドを実行して CPU 負荷を読み取り、動作周波数の変更を決定します。変更したい周波数を標準出力に出力します。
* freqd - 内部で子プロセスとして freqd.awk を実行します。freqd.awk が標準出力に出力してくる値を読み取って、sysctl を実行します。sysctl の実行のために、システム管理特権で起動されなければなりません。freqd.awk は特権を放棄して nobody で実行します。
## powerd の問題の分析と、freqd の実装への反映
作者の手元の環境では、powerd はほぼ数秒に一度、CPU 負荷が 100% か、それに近い
高負荷を検出するために、ほとんど周波数を下げてくれません。
ソースコードを完全に解析したわけではありませんが、CPU 負荷としてたまたま自分に
観測可能なコアの状態を取得しているためではないかと予想しました。また、インターバルを
指定できますが、その間の平均負荷を得ているわけでもないようです。

freqd では top コマンドの、CPU 状態表示から、CPU のアイドル状態のパーセンテージを得て、
それを基に周波数を決定しています。powerd は、急な負荷の上昇に対して即応するようチューニング
されているようですが、作者も FreeBSD をデスクトップ環境として利用しているので、そのあたりは
考慮して実装しています。
## freqd.awk 詳説
    function min(arr)          # 配列中の最小値
    function min_index(arr)    # 配列の最小の index
    function max_index(arr)    # 配列の最大の index
    function sum(arr)          # 配列の要素の合計
    
    # awk の組込み関数 split の逆。よって index は 1, 2, 3,... 。ただし
    # セパレータを指示する引数の省略の判定方法の都合で、省略時は空文字列 "" が
    # セパレータになる。
    function join(arr, sep,    i, result) {
     	if (sep) ; else { sep = "" }
     
    	...
    }
    
    function sortn(arr)        # sort -n コマンドを利用してソートをおこなう
    function getidles(result)  # top コマンドから、CPU の（マルチコアならそれぞれの）idle パーセンテージを得る
    function getfreq()         # 現在の周波数を取得
    function getfreqlist()     # 設定可能な周波数の配列を得る
    function setfreq(freq)     # 周波数の設定（freqd から利用する時は print するだけ）
    
    BEGIN {                    # メイン
    	INFINITY = 1E+300 * 1E+300                   # 1/0 では awk ではエラーになる
   
    ...
                                                     # メインループに入る前に、2 回ぶん取得しておく
    	flag = 0
    	for (;;) {                                   # メインループ
    		load[3] = load[2] ; load[2] = load[1]
    
    		getidles(idles)
    		load[1] = (100.0 - min(idles)) / 100.0
    
    		load_now = load[1]
    		load_3 = sum(load) / 3.0             # 最近 3 秒の平均
    
                                                     # デバッグ表示などは stderr に出すこと
    		#printf("%d %f %f\n", freqlist[current], load_now, load_3) >"/dev/stderr"
    
    		if (flag == 1) {                     # 直前に変更していたら、下げない
    			flag = 0
    		} else {
    			                             # 負荷が 1 秒と 3 秒ともに 40% 未満なら、クロックを下げる
    			if ((current > low) && (load_3 < 0.4) && (load_now < 0.4)) {
    				--current
    				setfreq(freqlist[current])
    
    				flag = 1
    			}
    		}
    
    		                                     # 最近 1 秒の負荷が 80% を越えていたら、周波数を上げる
    		if ((current < high) && (load_now > 0.8)) {
    			++current
    			setfreq(freqlist[current])
    
    			flag = 1
    		}
    	}
    }
