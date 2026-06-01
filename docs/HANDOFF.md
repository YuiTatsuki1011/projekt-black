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

## 次にやること

1. Godot 4.6.3のエディタで実際にプレイして、A/D移動、Sしゃがみ、Spaceジャンプ、マウス照準、左クリック発砲、Rリロードを確認する。
2. プレイヤー本体の仮図形を正式なスプライトシートへ差し替えるため、必要なフレームサイズと原点位置を決める。
3. 弾薬表示など、最低限のHUDを追加する。
4. 敵1種類と被弾処理へ進む。

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

## 注意点

- 入力仕様は確定済みです。A/Dで左右移動、Sでしゃがみ、Wでインタラクト、Spaceでジャンプ、マウスで照準、左クリックで発砲、Rでリロードです。
- Godotの `latest` ドキュメントは将来版の内容を含む可能性があります。実装時は4.6.3で使える機能か確認します。
- `godot` コマンドはPATHから見つかりません。現環境では `C:\Users\ui030\Downloads\Godot_v4.6.3-stable_win64_console.exe` を直接指定して検証します。
