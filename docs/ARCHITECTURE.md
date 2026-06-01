# Architecture

この文書は、プロジェクトの構造とコードの分け方を説明します。

## 基本方針

このゲームは要素が多いため、最初から巨大な万能スクリプトを作りません。プレイヤー、武器、弾、敵、アイテム、UIなどを分けます。

## ディレクトリ

```text
res://
  scenes/
    player/
    enemies/
    weapons/
    interaction/
    levels/
    ui/
  scripts/
    player/
    enemies/
    core/
    combat/
    ui/
    inventory/
    interaction/
    generation/
  resources/
    weapons/
    enemies/
    items/
    skills/
  assets/
    sprites/
    audio/
    vfx/
    fonts/
  docs/
  tools/
```

## Scenes

`Scene` はGodotで使う「ゲーム内の部品」です。プレイヤー、敵、弾、UI、部屋などをシーンにできます。

- `scenes/player/`: プレイヤー本体と関連部品。
- `scenes/enemies/`: 敵キャラクター。
- `scenes/weapons/`: 銃や近接武器の見た目、発射位置。
- `scenes/interaction/`: ボタン、ドア、アイテムなど、Wキーで操作できる部品。
- `scenes/levels/`: テストマップや部屋。
- `scenes/ui/`: HUD、メニュー、インベントリ画面。

## Scripts

`Script` はシーンに動きを与えるコードです。

- `scripts/core/`: 共通処理。
- `scripts/player/`: プレイヤーの移動、照準、入力処理。
- `scripts/enemies/`: 敵の移動、攻撃、死亡処理。
- `scripts/combat/`: ダメージ、弾、武器、命中処理。
- `scripts/ui/`: 照準、HUD、メニューなどの表示処理。
- `scripts/inventory/`: アイテム所持、装備。
- `scripts/interaction/`: ドア、アイテム取得、会話など。
- `scripts/generation/`: ランダムマップ生成。

## Resources

`Resource` はGodotのデータファイルです。武器や敵の数値をコードから分離するために使います。

例:

- 武器名
- ダメージ
- 装弾数
- リロード時間
- 発射間隔
- レアリティ

## Autoload

`Autoload` は、どのシーンからでも使える常駐スクリプトです。便利ですが、増やしすぎると依存関係が見えにくくなります。

使う候補:

- `GameState`: 現在のゲーム状態。
- `SaveManager`: セーブとロード。
- `EventBus`: 離れたシステム同士の通知。

最初の縦切りでは、必要になるまでAutoloadを増やしません。

## Collision Layers

`Collision Layer` は「その物体が何者か」、`Collision Mask` は「何に当たるか」を表す設定です。

- Layer 1 `world`: 床、壁。
- Layer 2 `player`: プレイヤー。
- Layer 3 `player_projectile`: プレイヤーの弾。
- Layer 4 `enemy`: 敵。
- Layer 5 `interaction`: Wキーで操作できるボタンなど。
