# MONAKA

集中タイムにiPhoneを触らなかった時間を記録するiOSアプリ。

- 業務要件定義書・システム要件定義書：claude.ai のドキュメント
- 画面デザイン：claude.ai の「MONAKA デザイン」キャンバス

## 構成

| フォルダ | ターゲット | 役割 |
| --- | --- | --- |
| `Monaka/` | Monaka（アプリ本体） | 設定、監視の登録、「今日」画面、初回セットアップ |
| `MonakaMonitor/` | MonakaMonitor（Device Activity Monitor 拡張） | 使用の検知、使用ログの記録、通知の予約 |
| `MonakaWidget/` | MonakaWidget（ウィジェット拡張） | ロック画面ウィジェット（横長） |
| `Shared/` | 上の3つすべて | 設定、使用ログ、未使用時間の計算、通知、時間の表記 |
| `MonakaTests/` | MonakaTests | 未使用時間の計算などの単体テスト（Swift Testing） |
| `Config/` | ― | xcconfig、entitlements、Info.plist |

フォルダは Xcode 16 以降の「フォルダ同期」で取り込んでいるので、ファイルを追加すると自動でターゲットに入る。

## はじめに

1. `Config/Base.xcconfig` の `BUNDLE_ID_PREFIX` と `DEVELOPMENT_TEAM` を書き換える
2. `Monaka.xcodeproj` を Xcode 26 以降で開く
3. 各ターゲットの Signing & Capabilities で、Family Controls と App Groups が有効になっていることを確認する
   （App Group ID は `group.<BUNDLE_ID_PREFIX>.monaka`）
4. 実機で実行する。スクリーンタイムの検知はシミュレーターでは確認できない

App Store で配布するには、Family Controls の配布用権限を Apple に申請する必要がある（アプリ本体と MonakaMonitor の両方）。

## 対応範囲

- iOS 18 以上、iPhone のみ、縦向き
- 言語は日本語のみ。文字列はすべて `Localizable.xcstrings` に集まるので、後から多言語化できる
- 外部通信なし・サーバーなし

## 実装済み / 未実装

実装済み

- 監視の登録（対象区間ごとに 1分〜N分 の閾値を一括登録）
- 使用の検知と使用ログの記録、重複通知の無視
- 未使用時間・最長連続未使用・使用回数の計算（テストあり）
- 6時間のリセット通知、目標達成通知の予約と組み替え
- ロック画面ウィジェット（集中タイム中・フリータイム中・次の集中タイム・なし）
- 「今日」画面（花形の進み具合）、初回セットアップ（許可の取得と標準設定での開始）

未実装（TODO）

- 日次記録の保存（SwiftData）、履歴・分析画面、連続達成日数
- 設定の編集画面（曜日ごとの編集、目標時間、記録しない日）
- 終了時サマリー通知、区切り通知
- 初回セットアップ3/3で曜日・時刻・目標を選ぶUI

## 実機検証（PoC）で確かめること

システム要件定義書 9.1 を参照。主なもの：

- [ ] ロック解除して1分使うと MonakaMonitor が呼ばれるか、遅れは何分か
- [ ] ロック画面を見るだけでは呼ばれないか
- [ ] 1区間に登録できるイベント数の上限（`MonitorNames.maxEventsPerInterval`）
- [ ] 検知からロック画面ウィジェットのリセット反映まで5分以内か（合格基準）
- [ ] ウィジェットの経過時間を「0:47」の h:mm 表記にできるか（今は `Text(_:style: .timer)`）
- [ ] 拡張機能から通知の取り消し・再予約ができるか
- [ ] App Group のデータが iPhone のバックアップに含まれるか
