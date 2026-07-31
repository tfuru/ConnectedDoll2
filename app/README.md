# ConnectedDoll2 BLE Controller App

BLE接続を通じて、「オーディオストリーミングスタンド開発ボード ver.2 (ConnectedDoll2)」への音声ファイル書き込み（転送）および日時アラーム設定を行うための Flutter モバイルアプリケーションです。

---

## 機能概要

1. **BLE デバイス検索 & 接続**
   - 近くにある `ConnectedDoll2` デバイスをスキャン・検出し、ワンタップで双方向BLE接続を確立します。
2. **推奨フォーマットへの音声自動変換 (トランスコード機能)**
   - ユーザーが選択した任意の音声ファイル（MP3など）を、ファームウェア側で最も安定してノイズなく再生できる推奨フォーマット（**16 kHz / 16-bit / モノラル WAV**）へアプリ内で自動変換します。
3. **WAVファイル書き込み (BLEファイル転送)**
   - 変換したWAVデータを、BLEのカスタムプロトコル（分割送信）を用いてデバイスのSDカードへ直接書き込みます。
   - `trigger.wav`（スイッチ再生用）および `alarm0.wav` 〜 `alarm4.wav`（アラーム用）の転送に対応。
4. **日時アラーム設定とファイル指定**
   - アラームスケジュール（最大5件、インデックス0〜4）の登録・削除・状態一覧表示。
   - アラームごとに異なる音源（`alarm0` 〜 `alarm4`）が自動で紐付けられます。

---

## 開発・ビルド環境

- **フレームワーク**: [Flutter](https://flutter.dev/) (3.x 系統推奨)
- **主要依存パッケージ**:
  - `universal_ble`: `^2.1.0` (クロスプラットフォーム対応のBLE通信ライブラリ)
  - `ffmpeg_kit_flutter_audio`: `^6.0.3` (音声ファイルの推奨フォーマット変換用)

---

## ビルド & 実行手順

### 1. 共通手順（依存関係の解決）
アプリディレクトリ内で以下のコマンドを実行し、パッケージをインストールします。
```bash
flutter pub get
```

### 2. Android での実行・ビルド

#### 実機 / エミュレータでの開発実行
Android端末をPCに接続（またはエミュレータを起動）し、以下のコマンドを実行します。
```bash
adb pair 192.168.10.110:35903

flutter run
```

#### リリース用 APK のビルド
```bash
flutter build apk --release
```
ビルド完了後、`build/app/outputs/flutter-apk/app-release.apk` にAPKファイルが生成されます。

#### 🛠 Android 開発時のトラブルシューティング
* **「ADB server didn't ACK」または adb の起動失敗エラーが出た場合**:
  ADBサーバー（Android Debug Bridge）が別のプロセスによってロックされている可能性があります。以下のコマンドでサーバーをリセットしてください。
  ```bash
  # ADBサーバーの強制終了と再起動
  adb kill-server
  adb start-server
  ```
  もし `adb` コマンド自体が見つからない場合は、パス（`/Users/t_furu/Library/Android/sdk/platform-tools` 等）を環境変数に追加するか、Android Studio からデバイス接続をリフレッシュしてください。

---

### 3. iOS での実行・ビルド

iOSアプリをビルド・実行するためには、Mac環境および以下のセットアップが必要です。

#### CocoaPods のインストール
iOSのネイティブプラグインを管理するため、CocoaPodsが必須です。
```bash
sudo gem install cocoapods
# または Homebrew を使用している場合:
brew install cocoapods
```

#### ポッドファイルのインストール
```bash
cd ios
pod install
cd ..
```

#### Xcode での署名（Signing）の設定
実機でBLE機能を使用するためには、Xcodeでのプロビジョニング署名が必要です。
1. Macで `ios/Runner.xcworkspace` を Xcode で開きます。
2. 左のプロジェクトツリーから最上部の `Runner` を選択します。
3. `Signing & Capabilities` タブを選択します。
4. `Team` でご自身のApple Developerアカウント（無料のPersonal Teamでも可）を選択し、`Bundle Identifier` を競合しないユニークなものに変更します。

#### iOS 実機での実行
```bash
flutter run
```

#### リリース用 IPA のビルド
```bash
flutter build ipa
```

---

### 4. CI/CD (GitHub Actions) での自動デバッグビルド

GitHub Actions を利用して、クラウド上で自動的に Android デバッグ APK をビルドして成果物を取得することができます。

#### 起動トリガー

1. **`debug-*` タグの Push**
   `debug-` から始まるタグを付与してリポジトリに push すると、自動的にデバッグビルドのワークフローが開始されます。
   ```bash
   git tag debug-v1.0.0
   git push origin debug-v1.0.0
   ```

2. **手動実行 (`workflow_dispatch`)**
   GitHub リポジトリの **Actions** タブ -> **Build App Debug** ワークフローを選択し、「Run workflow」ボタンから手動で起動することも可能です。

#### 成果物 (APK) の取得方法

ビルド完了後、GitHub の該当ワークフロー実行結果ページ下部にある **Artifacts** セクションから `app-debug-apk` (zip形式) をダウンロードできます。解凍すると Android 実機等にインストール可能な `app-debug.apk` が取得できます。


---

## BLE 通信仕様 (通信プロトコル)

アプリがデバイスと通信する際に使用する主要なUUIDおよびコマンド仕様です。

### 1. サービス & キャラクタリスティック UUID

| 項目 | UUID | プロパティ | 用途 |
| :--- | :--- | :---: | :--- |
| **Service (サービス)** | `e82d0000-fbc6-4b95-a22a-28d88b409600` | - | 本機専用BLEサービス |
| **Alarm Config (アラーム設定)** | `e82d0001-fbc6-4b95-a22a-28d88b409600` | Write / Read / Notify | アラーム日時の設定・削除・読出 |
| **File Transfer TX (データ送信)** | `e82d0002-fbc6-4b95-a22a-28d88b409600` | Write | 音声ファイルのバイナリ転送用 |
| **File Transfer RX (状態通知)** | `e82d0003-fbc6-4b95-a22a-28d88b409600` | Notify | 転送進捗・成否ステータスの受信用 |

### 2. アラーム設定プロトコル (`Alarm Config`)

このキャラクタリスティックを通じて、以下の文字列コマンドを送受信します。

* **アラーム設定 (Write)**: `SET:index,YYYY-MM-DD HH:MM` (例: `SET:0,2026-07-23 07:00`)
* **アラーム削除 (Write)**: `DEL:index` (例: `DEL:0`)
* **ステータス読出 (Read/Notify)**: デバイスから現在の全スロットの状態が返されます。
  * 返却形式: `index:0/1,YYYY-MM-DD HH:MM;...` (0=無効、1=有効)

### 3. ファイル転送プロトコル (`File Transfer`)

音声ファイルのバイナリデータを分割転送する際のヘッダープロトコルです。

* **ファイル転送開始ヘッダー (Write)**: `START:filename,filesize` (例: `START:trigger.wav,102400`)
* **データパケット (Write)**: ファイルの純粋なバイナリデータを一定サイズ（MTUサイズ以下）に分割して送信します。
* **終了ヘッダー (Write)**: `END` を送信して転送を完了します。
