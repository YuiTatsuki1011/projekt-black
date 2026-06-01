# Handoff

この文書は、新しいCodexセッションで作業を再開するための引き継ぎです。

## 現在の状態

- Godot 4.6.3 stable向けプロジェクト。
- ローカルパス: `D:\projekt-black`
- GitHubリポジトリ: `YuiTatsuki1011/projekt-black`
- 初期制作プロトコルを整備済み。
- 初期コミットをGitHubへpush済み。
- 操作ベース実装用ブランチ: `feature/core-controls`
- 操作ベースの初期実装を追加済み。

## 直近で完了したこと

- 初期ディレクトリ構成を作成。
- 安全な制作手順の文書を追加。
- 引き継ぎ、設計、ロードマップ、用語集、入力仕様、コンテンツ方針の文書を追加。
- Git管理を初期化。
- GitHubリモート `origin` を接続。
- 初期コミット `85ce8af` を `main` にpush。
- 入力設定を `project.godot` に追加。
- メインシーンを `scenes/levels/test_level.tscn` に設定。
- `scenes/player/player.tscn` を追加。
- `scripts/player/player_controller.gd` を追加。
- `Skeleton2D` / `Bone2D` を使う仮の腕と銃を追加。
- `scenes/weapons/projectile.tscn` と `scripts/combat/projectile.gd` を追加。
- `scenes/ui/crosshair.tscn` と `scripts/ui/crosshair.gd` を追加。
- フィードバック対応として、照準反転のデッドゾーンとカメラ補間無効化を追加。
- 弾数確認用HUD `scenes/ui/ammo_hud.tscn` と `scripts/ui/ammo_hud.gd` を追加。
- viewport解像度を1920x1080へ変更。
- カメラズームを `Vector2(2.3, 2.3)` に変更し、約30%遠くした。
- 共通HP部品 `scripts/combat/health.gd` を追加。
- 頭上HP表示 `scenes/ui/health_indicator.tscn` と `scripts/ui/health_indicator.gd` を追加。
- 静止する練習用ターゲット `scenes/enemies/training_target.tscn` を追加。
- ゆっくり接近する敵 `scenes/enemies/approach_enemy.tscn` を追加。
- Wキーで敵を出すボタン `scenes/interaction/spawn_button.tscn` を追加。
- テストレベルに `TARGET` ボタンと `ENEMY` ボタンを追加。
- 弾丸が `Health` を持つ対象へダメージを与えるように変更。
- 接近敵がプレイヤーへ接触ダメージを与える土台を追加。

## 次にやること

1. Godot 4.6.3のエディタで実際にプレイして、カメラ距離、左右移動、弾数HUD、頭上HP表示を確認する。
2. `TARGET` ボタン付近でWキーを押し、練習用ターゲットが出るか確認する。
3. `ENEMY` ボタン付近でWキーを押し、接近敵が出てプレイヤーへ近づくか確認する。
4. 弾が敵に当たり、HPが0になると敵が消えるか確認する。
5. 接近敵に触れたとき、プレイヤーHPが減るか確認する。
6. 次に血液VFX、ヒット反応、敵の攻撃表現へ進む。

## 最初の縦切り

最初の縦切りは、ゲーム全体の小さな試作品です。完成版ではなく、「このゲームの核が成立するか」を確認するためのものです。

- プレイヤー移動
- ジャンプ
- しゃがみ
- マウス照準
- 銃の向き制御
- 射撃
- 弾薬とリロード
- 敵1種類
- 被弾、死亡
- 簡単な血液VFX
- 小さなテストマップ

## 検証

以下のコマンドで、Godot 4.6.3によるヘッドレス実行を確認済みです。

```powershell
& "$env:USERPROFILE\Downloads\Godot_v4.6.3-stable_win64_console.exe" --headless --path "D:\projekt-black" --quit-after 10
```

エラーと警告は出ていません。

フィードバック対応後も同じコマンドで確認済みです。

スポーン処理は一時スモークテストでも確認済みです。`TARGET` と `ENEMY` の両ボタンから敵を1体ずつ生成し、生成物に `Health` があることを確認しました。

## 注意点

- 入力仕様は確定済みです。A/Dで左右移動、Sでしゃがみ、Wでインタラクト、Spaceでジャンプ、マウスで照準、左クリックで発砲、Rでリロードです。
- Godotの `latest` ドキュメントは将来版の内容を含む可能性があります。実装時は4.6.3で使える機能か確認します。
- `godot` コマンドはPATHから見つかりません。現環境では `C:\Users\ui030\Downloads\Godot_v4.6.3-stable_win64_console.exe` を直接指定して検証します。
