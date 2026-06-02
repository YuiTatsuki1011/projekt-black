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
    vfx/
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
- `scenes/interaction/`: ボタン、ドア、アイテムなど、Fキーで操作できる部品。
- `scenes/levels/`: テストマップや部屋。
- `scenes/ui/`: HUD、メニュー、インベントリ画面。
- `scenes/vfx/`: 命中、死亡、煙、火花などの演出。

## Scripts

`Script` はシーンに動きを与えるコードです。

- `scripts/core/`: 共通処理。
- `scripts/player/`: プレイヤーの移動、照準、入力処理。
- `scripts/enemies/`: 敵の移動、攻撃、死亡処理。
- `scripts/combat/`: ダメージ、弾、武器、命中処理。
- `scripts/ui/`: 照準、HUD、メニューなどの表示処理。
- `scripts/inventory/`: アイテム所持、弾薬所持、装備スロット。
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

現在は `resources/weapons/basic_pistol.tres` と `resources/weapons/field_knife.tres` を初期装備データとして使います。
インベントリ上の名前、サイズ、色、スタック数は `resources/items/*.tres` の `InventoryItemData` Resourceで管理します。

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
- Layer 5 `interaction`: Fキーで操作できるボタンなど。
- Layer 6 `enemy_projectile`: 敵の弾。

## Combat Feedback

戦闘の反応は、まず仮素材で分かりやすく作ります。

- `Health`: HP管理と、HP変化、被ダメージ、死亡の通知。
- `Projectile`: 命中した相手の `Health` を探してダメージを与える。
- `EnemyProjectile`: プレイヤーや床、壁に当たる敵弾。プレイヤーに当たると `Health` へダメージを与える。
- `PlayerController`: 移動、照準、射撃、近接攻撃、ステップ、スタミナを扱う。
- 敵スクリプト: 命中時の点滅、ノックバック、VFX生成、死亡処理を担当する。
- `BurstVfx`: 仮の赤い破片演出。正式な血液スプライトに差し替える前の確認用。

## Player Combat Actions

プレイヤーの攻撃手段は、いまは銃火器とサブ武器の2つです。

- 銃火器: 左クリックでマウス照準へ撃つ。装備中の銃データからダメージ、装弾数、リロード時間、対応弾薬を読む。
- サブ武器: 右クリックホールドで構え、構え中の左クリックで使用する。現在の初期サブ武器はナイフ。
- サブ武器構え中は、移動速度が少し下がる。
- ステップ: Shiftキーで発動する。短距離移動と短時間無敵を持つが、地上でしか使えない。

スタミナはプレイヤー側の資源です。3回ナイフを振ると0になり、最大まで戻るまで近接攻撃できません。

## Equipment

`Equipment` は、プレイヤーが今なにを装備しているかを持つ部品です。
現在はプレイヤーの `Equipment` ノードに、銃火器スロット `firearm_slot_1`〜`firearm_slot_4` とサブ武器スロット `melee_weapon` があります。

- 銃火器1番スロット: 初期値は `basic_pistol.tres`。
- 銃火器2〜4番スロット: 初期値は空。
- サブ武器スロット: 初期値は `field_knife.tres`。
- `active_firearm_slot` が現在選択中の銃火器枠です。1〜4キーで切り替えます。
- `PlayerController` は起動時、装備変更時、銃火器切り替え時に、装備データを読み込んで射撃と近接攻撃の数値へ反映します。
- 銃火器の現在装弾数は、スロットごとに `PlayerController` が保持します。
- `InventoryScreen` は装備欄を表示し、武器アイテムと装備枠のドラッグ&ドロップを処理します。
- 対応する装備枠が空の場合のみ、インベントリ内武器アイテムの右クリックで即装備します。
- 装備中アイテムは右クリック、または装備枠からグリッドへのドラッグ&ドロップでインベントリへ戻せます。空きがない場合は警告して中断します。
- 銃火器スロットが空になると、プレイヤーは発砲とリロードができず、仮銃の見た目も非表示になります。
- アイテムや装備枠へマウスを乗せた時の詳細パネルも `InventoryScreen` が生成します。武器詳細は `resources/weapons/` のResourceから読み、選択中アイテムと装備中の同種武器を2枚のカードとして並べて比較します。

Q/Eキーは、スキルや背面武器など、手持ちの銃火器と同時に扱う補助装備用に予約しています。

これにより、あとで武器ドロップ、装備変更UI、ランダム性能、レアリティを追加しやすくします。

## Inventory

`Inventory` は、アイテムID、所持数、グリッド上の配置を記録する部品です。
現在はプレイヤーの `Inventory` ノードで10x8マスのグリッドを管理し、`pistol_ammo` を2x1マスのアイテムとして配置します。
アイテム定義は `resources/items/` に置いた `.tres` を起動時に読み込みます。武器アイテムとして `basic_pistol`、`heavy_pistol`、`field_knife` も定義済みです。
グリッド上の各アイテムは、標準サイズとは別に現在の向きのサイズを持ちます。ドラッグ中にRキーで回転すると、置けた時だけその向きが保存されます。
リロード時はグリッド上の `pistol_ammo` から弾薬を消費します。

- `get_quantity(item_id)`: 指定アイテムの所持数を返す。
- `add_item(item_id, quantity)`: アイテムを増やす。
- `remove_item(item_id, quantity)`: 持っている分だけ減らし、実際に減らせた数を返す。
- `move_entry(entry_id, position, size_override)`: グリッド上のアイテムを移動し、必要なら向きも保存する。
- `can_place(entry_id, position, size_override)`: 指定位置と向きで置けるかを確認する。
- `can_add_item(item_id, quantity)`: 指定アイテムを収納する空きがあるかを確認する。
- `add_item_at(item_id, quantity, position, size_override)`: 指定グリッド位置と向きで新しいアイテムを追加する。

`InventoryScreen` はTabキーで開くUIです。グリッドの描画とドラッグ移動を担当し、実際の配置判定は `Inventory` に任せます。
インベントリを開いても `SceneTree.paused` は使わず、ゲーム時間は流れたままにします。
開いている間は `PlayerController.set_inventory_open(true)` を呼び、プレイヤーの移動、射撃、リロード、ステップ、サブ武器使用を止めます。
カメラはプレイヤーを画面左へ寄せる強めのズームへ短く遷移し、背景をぼかした中央寄せUIとして表示します。
通常のTabメニューでは上段にプレイヤーの装備/ステータス、下段にバックパックを配置します。開いている間は照準を非表示にします。
外部コンテナ表示は、将来のアイテムコンテナ側から `open_external_inventory()` を呼んだ時だけ使い、上段にコンテナ、下段にプレイヤーのバックパックを配置します。
プレイヤーの `damage_feedback` シグナルを受けた時は、デフォルトでインベントリを閉じ、攻撃方向に応じて画面端を赤く点滅させます。
現在は弾薬と武器アイテムに使っていますが、同じ入口を回復アイテム、素材、クエスト品へ広げられます。
インベントリ枠外へドラッグして離したアイテムは `DroppedItem` としてマップへ生成され、Fキーで拾い直せます。
武器アイテムは対応する装備枠へドラッグして装備します。装備枠が空の場合だけ右クリック即装備もできます。
詳細パネルは固定ノードではなく、`InventoryScreen` が必要時に `Root` 直下へ作ります。比較がある武器では選択中カードと現装備カードを横並びにし、弾薬や素材など比較対象がないアイテムでは選択中カードだけを表示します。

`ItemContainer` はFキーで開ける外部インベントリです。
コンテナ本体は `Area2D` として `scenes/interaction/item_container.tscn` に置き、子ノードに通常の `Inventory` を持ちます。
`ItemContainer.interact()` は `InventoryScreen.open_external_inventory(self)` を呼び、UIは上段にコンテナのグリッド、下段にプレイヤーのバックパックを表示します。
コンテナとバックパックの間の移動も、同じ `Inventory.add_item_at()` / `remove_entry()` を使って処理します。

アイテムの追加・編集手順は `docs/ITEM_AUTHORING.md` に記録します。

## Enemy Melee Attacks

接近敵の近接攻撃は、範囲予兆を表示しません。敵自身の停止、構え、攻撃、硬直で読み取れるようにします。

- `CHASE`: プレイヤーへ近づく。
- `WINDUP`: 一瞬止まり、構える。
- `ACTIVE`: 短い攻撃判定を出す。
- `RECOVERY`: 攻撃後に硬直する。

遠距離攻撃やAOEは、将来的に弾道や範囲表示を出せる設計にします。

## Enemy Ranged Attacks

遠距離攻撃の最初の土台として、`RangedEnemy` と `EnemyProjectile` を追加しています。

- `RangedEnemy`: プレイヤーを狙い、発射前に赤い射線を表示する。
- `WINDUP`: 射線を表示し、狙いを固定する。プレイヤーはこの間に移動やステップで回避できる。
- `FIRE`: 固定した方向へ `EnemyProjectile` を撃つ。
- `RECOVERY`: 次弾まで硬直する。

敵弾は `enemy_projectile` レイヤーに置き、`world` と `player` にだけ当たります。
近接攻撃とは異なり、遠距離攻撃は弾道や範囲を見せて回避判断を作る方針です。
