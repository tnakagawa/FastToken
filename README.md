
# Fast Token

Author: Takatoshi Nakagawa
Date: 2023/mm/dd
Version:Draft


# 要旨（Abstract）

Bitcoin の [The Bitcoin Lightning Network](https://lightning.network/lightning-network-paper.pdf) と [eltoo](https://blockstream.com/eltoo.pdf) のアイデアをEVM互換のコントラクトにしました。
前提知識としてLightningやeltooの仕組みを理解していると分かり易いと思います。

大きな特徴としてチャネルの開設（`open`）、解約（`close`）はブロックチェーンのトランザクションを利用します。（オンチェーン）
取引はブロックチェーンのトランザクションを利用しません。（オフチェーン）
したがって取引においてブロックの生成を待つ必要がなくなりスループットが向上します。

本仕様においてオフチェーンの取引は保留リクエストを交換することで取引を行います。
保留リクエストは取引回数（`count`）を保持しており、これをインクリメントしながら取引を行います。

# 操作（Operation）

## 基本操作（Basic Operation）

1. チャネル開設します。（コントラクト`open`実行）
1. 取引を行います。（オフチェーン）
1. チャネル解約します。（コントラクト`close`実行）

### 1. チャネル開設（Open Channel）

Alice と Bob がチャネルを開設します。

1. Alice が Bob にチャネル開設を要求します。
    - [`address`] Alice のアドレス
    - [`uint256`] Alice がチャネル開設時に移動するトークン量
    - [`uint256`] Bob がチャネル開設時に移動するトークン量
1. Bob は Alice に保留リクエストを送信します。
    -  保留リクエスト（HoldRequestData）
        - [`address` partner] Bob のアドレス
        - [`uint256` amount1] Alice 又は Bob のトークン量
        - [`uint256` amount2] Alice 又は Bob のトークン量
        - [`uint256` count] `1` 固定
        - [`uint256` lockterm] 保留ロック期間（UNIX秒）
        - [`bytes32` preImage] ペイメントプリイメージ
        - [`bytes` signature] Bob の署名値
1. Alice は Bob にチャネル開設リクエストと保留リクエストを送信します。
    -  開設リクエスト（OpenRequestData）
        - [`address` partner] Alice のアドレス
        - [`uint256` total] トークンの総量
        - [`uint256` amount1] Alice 又は Bob がチャネル開設時に移動するトークン量
        - [`uint256` amount2] Alice 又は Bob がチャネル開設時に移動するトークン量
        - [`uint256` deadline] 署名値の有効期限（UNIX時間秒）
        - [`bytes` signature] Alice の署名値
    -  保留リクエスト（HoldRequestData）
        - [`address` partner] Alice のアドレス
        - [`uint256` amount1] Alice 又は Bob のトークン量
        - [`uint256` amount2] Alice 又は Bob のトークン量
        - [`uint256` count] `1` 固定
        - [`uint256` lockterm] 保留ロック期間（UNIX秒）
        - [`bytes32` preImage] ペイメントプリイメージ
        - [`bytes` signature] Alice の署名値
1. Bob はコントラクトのチャネル開設（`open`）を実行します。

### 2. 取引（Transaction）

取引はオフチェーンで行います。
Alice と Bob は最新の保留リクエストを保持している必要があります。
`amount1`と`amount2`は残高であることに注意してください。
例）`amount1:1000`と`amount2:500`で`amount1`から`amount2`へ`700`支払（移動）する場合は`amount1:300`と`amount2:1200`となります。

1. Alice が Bob へ注文をします。
1. Bob はペイメントハッシュ（`payHash`）を含んだインボイスを送信します。
    - [`byte32` payHash] ペイメントハッシュ
    - [`uint256`] Alice が支払うトークン量
1. Alice がペイメントハッシュ（`payHash`）から 保留リクエストを作成します。
1. Alice が Bob に メッセージ（`preImage`を除いた保留リクエスト）を送信します。
    -  保留リクエスト（HoldRequestData）
        - [`address` partner] Alice のアドレス
        - [`uint256` amount1] Alice 又は Bob のトークン量
        - [`uint256` amount2] Alice 又は Bob のトークン量
        - [`uint256` count] 前回の保留リクエストの`count`に`1`を加算した数値
        - [`uint256` lockterm] 保留ロック期間（UNIX秒）
        - [`bytes32` preImage] 空データ（`0x00...00`）
        - [`bytes` signature] Alice の署名値
1. Bob がペイメントプリイメージ（`preImage`）を含んだメッセージ（保留リクエスト）を Alice に送信します。
    -  保留リクエスト（HoldRequestData）
        - [`address` partner] Bob のアドレス
        - [`uint256` amount1] Alice 又は Bob のトークン量
        - [`uint256` amount2] Alice 又は Bob のトークン量
        - [`uint256` count] 前回の保留リクエストの`count`に`1`を加算した数値
        - [`uint256` lockterm] 保留ロック期間（UNIX秒）
        - [`bytes32` preImage] ペイメントプリイメージ
        - [`bytes` signature] Bob の署名値
1. Alice と Bob が保持しているチャネルの保有リクエストを更新します。

### 3. チャネル解約（Close Channel）

Alice と Bob がチャネルを解約します。

1. Alice が Bob に解約リクエストを送信しチャネル解約を要求します。
    - 解約リクエスト（CloseRequestData）
        - [`address` partner] Alice のアドレス
        - [`uint256` amount1] Alice 又は Bob のトークン量
        - [`uint256` amount2] Alice 又は Bob のトークン量
        - [`uint256` deadline] 署名値の有効期限（UNIX時間秒）
        - [`bytes` signature] Alice の署名値
1. Bob はコントラクトのチャネル解約（`close`）を実行します。

## 取引ルーティング（Transaction Routing）

Alice が Chan と取引する時の手順です。
Alice と Chan はチャネルを開設していませんが、Bob は Alice と Chen の両方とチャネルを開設しています。

1. Alice が Chan へ注文をします。
1. Chan はペイメントハッシュ（`lockHash`）を含んだインボイスを送信します。
    - [`byte32` payHash] ペイメントハッシュ
    - [`uint256`] Alice が支払うトークン量
    - [`address`] Bob と Chan のチャネルアドレス
    - [`address`] Chan のアドレス
1. Alice は Bob 経由で Chan へ取引を行います。（ルーティングについては確定済みとします。）
1. Alice が Bob に メッセージ（`preImage`を除いた保留リクエスト）を送信します。
    -  保留リクエスト（HoldRequestData）
        - [`address` partner] Alice のアドレス
        - [`uint256` amount1] Alice 又は Bob のトークン量
        - [`uint256` amount2] Alice 又は Bob のトークン量
        - [`uint256` count] 前回の保留リクエストの`count`に`1`を加算した数値
        - [`uint256` lockterm] 保留ロック期間（UNIX秒）
        - [`bytes32` preImage] 空データ（`0x00...00`）
        - [`bytes` signature] Alice の署名値
    - [`byte32` payHash] Chan から受取ったペイメントハッシュ
    - [`address`] Bob と Chan のチャネルアドレス
    - [`address`] Chan のアドレス
1. Bob が Chan に メッセージ（`preImage`を除いた保留リクエスト）を送信します。
    -  保留リクエスト（HoldRequestData）
        - [`address` partner] Bob のアドレス
        - [`uint256` amount1] Bob 又は Chan のトークン量
        - [`uint256` amount2] Bob 又は Chan のトークン量
        - [`uint256` count] 前回の保留リクエストの`count`に`1`を加算した数値
        - [`uint256` lockterm] 保留ロック期間（UNIX秒）
            - **※注意※Alice と Bob 間の保留リクエストの保留ロック期間より短い値（不正に気付く十分な時間）にする必要があります。**
        - [`bytes32` preImage] 空データ（`0x00...00`）
        - [`bytes` signature] Bob の署名値
    - [`byte32` payHash] Chan から受取ったペイメントハッシュ
1. Chan がペイメントプリイメージ（`preImage`）を含んだメッセージ（保留リクエスト）を Bob に送信します。
    -  保留リクエスト（HoldRequestData）
        - [`address` partner] Chan のアドレス
        - [`uint256` amount1] Bob 又は Chan のトークン量
        - [`uint256` amount2] Bob 又は Chan のトークン量
        - [`uint256` count] 前回の保留リクエストの`count`に`1`を加算した数値
        - [`uint256` lockterm] 保留ロック期間（UNIX秒）
        - [`bytes32` preImage] ペイメントプリイメージ
        - [`bytes` signature] Chan の署名値
1. Bob と Chan がチャネルの保持しているチャネルの保有リクエストを更新します。
1. Bob がペイメントプリイメージ（`preImage`）を含んだメッセージ（保留リクエスト）を Alice に送信します。
    -  保留リクエスト（HoldRequestData）
        - [`address` partner] Bob のアドレス
        - [`uint256` amount1] Alice 又は Bob のトークン量
        - [`uint256` amount2] Alice 又は Bob のトークン量
        - [`uint256` count] 前回の保留リクエストの`count`に`1`を加算した数値
        - [`uint256` lockterm] 保留ロック期間（UNIX秒）
        - [`bytes32` preImage] ペイメントプリイメージ
        - [`bytes` signature] Bob の署名値
1. Alice と Bob がチャネルの保持しているチャネルの保有リクエストを更新します。

# 安全性（Security）

## チャネルの開設（`open`）、解約（`close`）の署名

Alice がチャネルの開設（`open`）や解約（`close`）を Bob に依頼します。
チャネルの開設（`open`）や解約（`close`）には Alice の署名値が存在します。
Alice が署名したチャネルの開設（`open`）や解約（`close`）には有効期限（`deadline`）とナンス（`nonce`）が含まれています。
有効期限内に一度だけ有効な署名値となります。
Bob が Alice から受取ったチャネルの開設（`open`）や解約（`close`）を有効期限内に実行しない場合、署名値は無効となります。
Bob が Alice から受取ったチャネルの開設（`open`）や解約（`close`）を有効期限内に実行した場合、同じ署名値で二度目の実行は出来ません。

## 強制解約（Force Close）

通常であれば双方合意の元で解約（`close`）を行いますが、なんらかの理由で合意が得られない場合、強制的にチャネルを解約（`close`）することが出来ます。
保有している最新の保留（`hold`）を実行し、保留ロック期間（UNIX秒:`lockterm`）後に解放（`release`）を実行すれば最新の残高で解約（`close`）することが出来ます。
もし、最新でない保留（`hold`）を実行した場合、最新の保留（`hold`）で上書きすることができます。
保留（`hold`）の実行は取引回数（`count`）が大きいものだけ上書きすることができます。
そのため、最新の保留（`hold`）が有効となります。

## ルーティングにおける強制解約（Force Close）

Alice -> Bob -> Chan とルーティングの時、Chan がペイメントプリイメージ（`preImage`）を Bob に返却しない場合、Bob は Alice から受取った保留リクエストを使うことができません。
この場合、Bob が保有している Bob - Chan チャネルの最新の保留リクエスト（ルーティングが行われる１つ前）を使用してチャネル保留（`hold`）を実行します。
Chan は最新の保留リクエスト（ルーティングで使用）で上書きします。（これを行わないと Chan は損をしてしまう。）
Chan のチャネル保留（`hold`）実行時にペイメントプリイメージ（`preImage`）がイベントで公開される為、Bob は Alice から受取った保留リクエストを使うことが出来るようになります。
ここで、Bob がチャネル保留（`hold`）を実行する前に Alice が保留リクエスト（ルーティングが行われる１つ前）を使用してチャネル保留（`hold`）を実行した場合、Alice が先に解放（`release`）してしまうかもしれません。
その為、Alice - Bob の保留ロック期間（UNIX秒:`lockterm`）よりも Bob - Chan　の保留ロック期間（UNIX秒:`lockterm`）を十分短くしておく必要があります。
Alice が保留リクエスト（ルーティングが行われる１つ前）を使用してチャネル保留（`hold`）を実行した場合、すぐに Bob は Bob - Chan チャネルの最新の保留リクエスト（ルーティングが行われる１つ前）を使用してチャネル保留（`hold`）を実行します。
保留ロック期間（UNIX秒:`lockterm`）は Bob - Chan の方が Alice - Bob よりも十分短い為、Alice が解放（`release`）可能となる前に Chan は保留リクエストを上書きする必要があります。
Chan が上書きしたら、Bob はペイメントプリイメージ（`preImage`）を知ることができるので、Alice - Bob で保留リクエストGiを上書きすることが出来ます。


# 仕様（Specification）

## チャネルアドレス（Channel Address）

チャネルアドレスは2つのアドレス(EOA)のうち、小さい方を`address1`、大きい方を`address2`とした時、以下のように求めます。

```sol
address(uint160(uint256(keccak256(abi.encodePacked(address1, address2)))))
```

## チャネル情報（Channel Infomation）

コントラクト内で管理するチャネル情報は以下のとおりです。


```sol
    // Channel Info Status
    uint8 internal constant _STATUS_NONE = 0;
    uint8 internal constant _STATUS_OPEN = 1;
    uint8 internal constant _STATUS_HOLD = 2;
    uint8 internal constant _STATUS_CLOSE = 3;

    struct ChannelInfo {
        uint8 status;
        uint256 index;
        uint256 amount1;
        uint256 amount2;
        uint256 count;
        uint256 locktime;
    }
```

**status**
ステータス
0:None（チャネルが開設されていない状態）
1:Open（チャネルが開設されている状態）
2:Hold（チャネルが保留されている状態）
3:Close（チャネルが解約されている状態）

**index**
インデックス
チャネルのインデックス、解約（`Close`）または解放（`Release`）された場合に `1` インクリメントされます。

**amount1**
チャネルのアドレス2つのうち、非負整数で小さい方のアドレスに支払うトークン量
チャネルが保留されている時に設定されます。
チャネルの保留が解除（`Release`）される時にチャネルのアドレス2つのうち、非負整数で小さい方のアドレスに支払われます。

**amount2**
チャネルのアドレス2つのうち、非負整数で大きい方のアドレスに支払うトークン量
チャネルが保留されている時に設定されます。
チャネルの保留が解除（`Release`）される時にチャネルのアドレス2つのうち、非負整数で大きい方のアドレスに支払われます。

**count**
取引回数
チャネルが保留されている時に設定されます。
オフラインで取引した回数です。

**locktime**
ロック時間
この時間（UNIX時間秒）まで保留から解放（`Release`）することはできません。

---

## チャネル開設（Open Channel）

```sol
    function open(OpenRequestData calldata request) external;
```

### 開設リクエスト（Open Request Data）

コントラクトの`open`メソッドのパラメータです。

```sol
    struct OpenRequestData {
        address partner;
        uint256 total;
        uint256 amount1;
        uint256 amount2;
        uint256 deadline;
        bytes signature;
    }
```

**partner**
`address`型
送信者と`partner`でチャネルアドレスを計算します。

**total**
`uint256`型
チャネルのトークン総額です。

**amount1**
`uint256`型
チャネル開設時にチャネルのアドレス2つのうち、非負整数で小さい方のアドレスからチャネルに移動するトークンの量です。

**amount2**
`uint256`型
チャネル開設時にチャネルのアドレス2つのうち、非負整数で大きい方のからチャネルに移動するトークンの量です。

**deadline**
`uint256`型
署名値の有効期限（UNIX時間秒）です。

**signature**
`bytes`型
`partner`の署名値です。

### 開設リクエスト署名タイプ（Open Request Types）

EIP-712で署名するデータタイプです。

```sol
    bytes32 internal constant _OPEN_REQUEST_TYPEHASH =
        keccak256(
            "OpenRequest(address channel,uint256 index,uint256 total,uint256 amount1,uint256 amount2,uint256 nonce,uint256 deadline)"
        );
```

**channel**
`address`型
チャネルのアドレスです。

**index**
`uint256`型
チャネルアドレスのインデックスです。

**total**
`uint256`型
チャネルのトークン総額です。

**amount1**
`uint256`型
チャネル開設時にチャネルのアドレス2つのうち、非負整数で小さい方のアドレスからチャネルに移動するトークンの量です。

**amount2**
`uint256`型
チャネル開設時にチャネルのアドレス2つのうち、非負整数で大きい方のアドレスからチャネルに移動するトークンの量です。

**nonce**
`uint256`型
コントラクトの`nonces(＜署名者のアドレス＞)`メソッドで得られるナンスです。

**deadline**
`uint256`型
署名値の有効期限（UNIX時間秒）です。

### 開設バリデーション（Open Validation）

**channel**
チャネルアドレス

**address1**
チャネルのアドレス2つのうち、非負整数で小さい方のアドレス

**address2**
チャネルのアドレス2つのうち、非負整数で大きい方のアドレス

**checkTotal**
チャネルのトークン総数チェック
開設リクエストの `total` が開設リクエストの `amount1` と `amount2` とチャネルのトークン量（`balanceOf(channel)`）の和と等しい場合 `true` となります。

**checkStatus**
チャネルステータスチェック
チャネルスのテータスが `None:0` か `Close:3` の場合 `true` となります。

**isActive**
署名有効チェック
開設リクエストの「署名値の有効期限」（UNIX時間秒）が `block.timestamp` 以降の場合 `true` となります。

**checkSign**
署名値チェック
署名値が有効（リカバリーアドレスが開設リクエストの `partner` と一致）な場合 `true` となります。

### 開設処理（Open Logic）

開設バリデーションが全て `true` の場合処理を行う。

1. 開設リクエストの `amount1` が `0` より大きい場合 `address1` から `channel` へ `amount1` を移動します。
1. 開設リクエストの `amount2` が `0` より大きい場合 `address2` から `channel` へ `amount2` を移動します。
1. チャネル情報の `status` を `Open:1` に設定します。
1. 署名者（開設リクエストの `partner`）のNonceを消費します。
1. `OpenChannel` イベント（チャネルアドレスとインデックス）を発行します。

```sol
    event OpenChannel(address indexed channel, uint256 indexed index);
```

---

## チャネル解約（Close Channel）

```sol
    function close(CloseRequestData calldata request) external;
```

### 解約リクエスト（Close Request Data）

コントラクトの`close`メソッドのパラメータです。

```sol
    struct CloseRequestData {
        address partner;
        uint256 amount1;
        uint256 amount2;
        uint256 deadline;
        bytes signature;
    }
```

**partner**
`address`型
送信者と`partner`でチャネルアドレスを計算します。

**amount1**
`uint256`型
チャネル解約時にチャネルからチャネルのアドレス2つのうち、非負整数で小さい方のアドレスに移動するトークンの量です。

**amount2**
`uint256`型
チャネル解約時にチャネルからチャネルのアドレス2つのうち、非負整数で大きい方のアドレスに移動するトークンの量です。

**deadline**
`uint256`型
署名値の有効期限（UNIX秒）です。

**signature**
`bytes`型
`partner`の署名値です。

### 解約リクエスト署名タイプ（Close Request Types）

EIP-712で署名するデータタイプです。

```sol
    bytes32 internal constant _CLOSE_REQUEST_TYPEHASH =
        keccak256(
            "CloseRequest(address channel,uint256 index,uint256 amount1,uint256 amount2,uint256 nonce,uint256 deadline)"
        );
```

**channel**
`address`型
チャネルのアドレスです。

**index**
`uint256`型
チャネルアドレスのインデックスです。

**amount1**
`uint256`型
チャネル解約時にチャネルからチャネルのアドレス2つのうち、非負整数で小さい方のアドレスに移動するトークンの量です。

**amount2**
`uint256`型
チャネル解約時にチャネルからチャネルのアドレス2つのうち、非負整数で大きい方のアドレスに移動するトークンの量です。

**nonce**
`uint256`型
コントラクトの`nonces(＜署名者のアドレス＞)`メソッドで得られるナンスです。

**deadline**
`uint256`型
署名値の有効期限（UNIX秒）です。

### 解約バリデーション（Close Validation）

**channel**
チャネルアドレス

**address1**
チャネルのアドレス2つのうち、非負整数で小さい方のアドレス

**address2**
チャネルのアドレス2つのうち、非負整数で大きい方のアドレス

**checkTotal**
チャネルのトークン数チェック
解約リクエストの `amount1` と `amount2` の和とチャネルのトークン量（`balanceOf(channel)`）が等しい場合 `true` となります。

**checkStatus**
チャネルステータスチェック
チャネルスのテータスが `Open:0` か `Hold:2` の場合 `true` となります。

**isActive**
署名有効チェック
解約リクエストの「署名値の有効期限」（UNIX時間秒）が `block.timestamp` 以降の場合 `true` となります。

**checkSign**
署名値チェック
署名値が有効（リカバリーアドレスが解約リクエストの `partner` と一致）な場合 `true` となります。

### 解約処理（Close Logic）

解約バリデーションが全て `true` の場合処理を行う。

1. 解約リクエストの `amount1` が `0` より大きい場合 `channel` から `address1` へ `amount1` を移動します。
1. 開設リクエストの `amount2` が `0` より大きい場合 `channel` から `address2` へ `amount2` を移動します。
1. チャネル情報の `status` が `Hold:2` の場合以下を設定します。
    - チャネル情報の `amount1` を `0` に設定します。
    - チャネル情報の `amount2` を `0` に設定します。
    - チャネル情報の `count` を `0` に設定します。
    - チャネル情報の `locktime` を `0` に設定します。
    - チャネル情報の `status` を `Close:3` に設定します。
1. 署名者（解約リクエストの `partner`）のNonceを消費します。
1. `CloseChannel` イベント（チャネルアドレスとインデックス）を発行します。
1. チャネル情報の `index` をインクリメント（+1）します。

```sol
    event CloseChannel(address indexed channel, uint256 indexed index);
```

---

## チャネル保留（Hold Channel）

```sol
    function hold(HoldRequestData calldata request) external;
```

### 保留リクエスト（Hold Request Data）

コントラクトの`hold`メソッドのパラメータです。

```sol
    struct HoldRequestData {
        address partner;
        uint256 amount1;
        uint256 amount2;
        uint256 count;
        uint256 lockterm;
        bytes32 preImage;
        bytes signature;
    }
```

**partner**
`address`型
送信者と`partner`でチャネルアドレスを計算します。

**amount1**
`uint256`型
リリース時にチャネルからチャネルのアドレス2つのうち、非負整数で小さい方のアドレスに移動するトークンの量です。

**amount2**
`uint256`型
リリース時にチャネルからチャネルのアドレス2つのうち、非負整数で大きい方のアドレスに移動するトークンの量です。

**count**
`uint256`型
オフチェーンでの取引カウンターです。

**lockterm**
`uint256`型
リリースするまでの保留期間です。

**preImage**
`bytes32`型
ペイメントプリイメージです。

**signature**
`bytes`型
`partner`の署名値です。

### 保留リクエスト署名タイプ（Hold Request Types）

EIP-712で署名するデータタイプです。

```sol
    bytes32 internal constant _HOLD_REQUEST_TYPEHASH =
        keccak256(
            "HoldRequest(address channel,uint256 index,uint256 amount1,uint256 amount2,uint256 count,uint256 lockterm,bytes32 payHash)"
        );
```

**channel**
`address`型
チャネルのアドレスです。

**index**
`uint256`型
チャネルアドレスのインデックスです。

**amount1**
`uint256`型
リリース時にチャネルからチャネルのアドレス2つのうち、非負整数で小さい方のアドレスに移動するトークンの量です。

**amount2**
`uint256`型
リリース時にチャネルからチャネルのアドレス2つのうち、非負整数で大きい方のアドレスに移動するトークンの量です。

**count**
`uint256`型
オフチェーンでの取引カウンターです。

**lockterm**
`uint256`型
リリースするまでの保留期間です。

**payHash**
`bytes32`型
`preImage`のハッシュ値（`keccak256`）です。

### 保留バリデーション（Hold Validation）

**channel**
チャネルアドレス

**checkTotal**
チャネルのトークン数チェック
保留リクエストの `amount1` と `amount2` の和とチャネルのトークン量（`balanceOf(channel)`）が等しい場合 `true` となります。

**checkStatus**
チャネルステータスチェック
チャネルスのテータスが `Open:0` か `Hold:2` の場合 `true` となります。

**overCount**
カウントチェック
保留リクエストの `count` がチャネル情報の `count` より大きい場合 `true` となります。

**validLockTerm**
ロック期間チェック
保留リクエストの `lockterm` が最小値（`0`）以上、最大値（3週間`3600 * 24 * 21`）以下の場合 `true` となります。

**checkSign**
署名値チェック
署名値が有効（リカバリーアドレスが保留リクエストの `partner` と一致）な場合 `true` となります。

### 保留処理（Hold Logic）

保留バリデーションが全て `true` の場合処理を行う。

1. チャネル情報に以下を設定します。
    - チャネル情報の `status` を `Hold:2` に設定します。
    - チャネル情報の `amount1` を保留リクエストの `amount1` に設定します。
    - チャネル情報の `amount2` を保留リクエストの `amount2` に設定します。
    - チャネル情報の `count` を保留リクエストの `count` に設定します。
    - チャネル情報の `locktime` を保留リクエストの `locktime` と `block.timestamp` の和に設定します。
1. `HoldChannel` イベント（チャネルアドレス、インデックス、カウント、ペイメントプリイメージ）を発行します。

```sol
    event HoldChannel(
        address indexed channel,
        uint256 indexed index,
        uint256 count,
        bytes32 preImage
    );
```

---

## チャネル解放（Release Channel）

```sol
    function release(address partner) external;
```

**channel**
`address`型
解放するチャネルアドレスです。

### 解放バリデーション（Release Validation）

**checkStatus**
チャネルステータスチェック
チャネルスのテータスが `Hold:2` の場合 `true` となります。

**noLock**
ロックチェック
チャネル情報の `locktime` が `block.timestamp` 以下の場合 `true` となります。

### 解放処理（Release Logic）

解放バリデーションが全て `true` の場合処理を行う。

1. チャネル情報の `amount1` が `0` より大きい場合 `channel` から `address1` へ `amount1` を移動します。
1. チャネル情報の `amount2` が `0` より大きい場合 `channel` から `address2` へ `amount2` を移動します。
1. `ReleaseChannel` イベント（チャネルアドレスとインデックス）を発行します。
1. チャネル情報の以下を設定します。
    - チャネル情報の `amount1` を `0` に設定します。
    - チャネル情報の `amount2` を `0` に設定します。
    - チャネル情報の `count` を `0` に設定します。
    - チャネル情報の `locktime` を `0` に設定します。
    - チャネル情報の `status` を `Close:3` に設定します。
1. `CloseChannel` イベント（チャネルアドレスとインデックス）を発行します。
1. チャネル情報の `index` をインクリメント（+1）します。

```sol
    event ReleaseChannel(address indexed channel, uint256 indexed index);
```


---

## チャネル増資（Increase Channel）

```sol
    function increase(IncreaseRequestData calldata request) external;
```

### 増資リクエスト（Increase Request Data）

コントラクトの`increase`メソッドのパラメータです。

```sol
    struct IncreaseRequestData {
        address partner;
        uint256 amount1;
        uint256 amount2;
        uint256 deadline;
        bytes signature;
    }
```

**partner**
`address`型
送信者と`partner`でチャネルアドレスを計算します。

**amount1**
`uint256`型
チャネル増資時にチャネルのアドレス2つのうち、非負整数で小さい方のアドレスからチャネルに移動するトークンの量です。

**amount2**
`uint256`型
チャネル増資時にチャネルのアドレス2つのうち、非負整数で大きい方のアドレスからチャネルに移動するトークンの量です。

**deadline**
`uint256`型
署名値の有効期限（UNIX秒）です。

**signature**
`bytes`型
`partner`の署名値です。

### 増資リクエスト署名タイプ（Increase Request Types）

EIP-712で署名するデータタイプです。

```sol
    bytes32 internal constant _INCREASE_REQUEST_TYPEHASH =
        keccak256(
            "IncreaseRequest(address channel,uint256 index,uint256 amount1,uint256 amount2,uint256 nonce,uint256 deadline)"
        );
```

**channel**
`address`型
チャネルのアドレスです。

**index**
`uint256`型
チャネルアドレスのインデックスです。

**amount1**
`uint256`型
チャネル増資時にチャネルのアドレス2つのうち、非負整数で小さい方のアドレスからチャネルに移動するトークンの量です。

**amount2**
`uint256`型
チャネル増資時にチャネルのアドレス2つのうち、非負整数で大きい方のアドレスからチャネルに移動するトークンの量です。

**nonce**
`uint256`型
コントラクトの`nonces(＜署名者のアドレス＞)`メソッドで得られるナンスです。

**deadline**
`uint256`型
署名値の有効期限（UNIX秒）です。

### 増資バリデーション（Increase Validation）

**channel**
チャネルアドレス

**address1**
チャネルのアドレス2つのうち、非負整数で小さい方のアドレス

**address2**
チャネルのアドレス2つのうち、非負整数で大きい方のアドレス

**checkStatus**
チャネルステータスチェック
チャネルスのテータスが `Open:1` の場合 `true` となります。

**isActive**
署名有効チェック
増資リクエストの「署名値の有効期限」（UNIX時間秒）が `block.timestamp` 以降の場合 `true` となります。

**checkSign**
署名値チェック
署名値が有効（リカバリーアドレスが増資リクエストの `partner` と一致）な場合 `true` となります。

### 増資処理（Increase Logic）

増資バリデーションが全て `true` の場合処理を行う。

1. チャネル情報の `status` を `None:0` に設定します。
1. 増資リクエストの `amount1` が `0` より大きい場合 `address1` から `channel` へ `amount1` を移動します。
1. 増資リクエストの `amount2` が `0` より大きい場合 `address2` から `channel` へ `amount2` を移動します。
1. チャネル情報の `status` を `Open:1` に設定します。
1. 署名者（開設リクエストの `partner`）のNonceを消費します。
1. `IncreaseChannel` イベント（チャネルアドレスとインデックス）を発行します。

```sol
    event IncreaseChannel(address indexed channel, uint256 indexed index);
```

---

## チャネル減資（Decrease Channel）

```sol
    function decrease(DecreaseRequestData calldata request) external;
```

### 減資リクエスト（Decrease Request Data）

コントラクトの`decrease`メソッドのパラメータです。

```sol
    struct DecreaseRequestData {
        address partner;
        uint256 amount1;
        uint256 amount2;
        uint256 deadline;
        bytes signature;
    }
```

**partner**
`address`型
送信者と`partner`でチャネルアドレスを計算します。

**amount1**
`uint256`型
チャネル減資時にチャネルからチャネルのアドレス2つのうち、非負整数で小さい方のアドレスに移動するトークンの量です。

**amount2**
`uint256`型
チャネル減資時にチャネルからチャネルのアドレス2つのうち、非負整数で大きい方のアドレスに移動するトークンの量です。

**deadline**
`uint256`型
署名値の有効期限（UNIX秒）です。

**signature**
`bytes`型
`partner`の署名値です。

### 減資リクエスト署名タイプ（Decrease Request Types）

EIP-712で署名するデータタイプです。

```sol
    bytes32 internal constant _DECREASE_REQUEST_TYPEHASH =
        keccak256(
            "DecreaseRequest(address channel,uint256 index,uint256 amount1,uint256 amount2,uint256 nonce,uint256 deadline)"
        );
```

**channel**
`address`型
チャネルのアドレスです。

**index**
`uint256`型
チャネルアドレスのインデックスです。

**amount1**
`uint256`型
チャネル減資時にチャネルからチャネルのアドレス2つのうち、非負整数で小さい方のアドレスに移動するトークンの量です。

**amount2**
`uint256`型
チャネル減資時にチャネルからチャネルのアドレス2つのうち、非負整数で大きい方のアドレスに移動するトークンの量です。

**nonce**
`uint256`型
コントラクトの`nonces(＜署名者のアドレス＞)`メソッドで得られるナンスです。

**deadline**
`uint256`型
署名値の有効期限（UNIX秒）です。

### 減資バリデーション（Decrease Validation）

**channel**
チャネルアドレス

**address1**
チャネルのアドレス2つのうち、非負整数で小さい方のアドレス

**address2**
チャネルのアドレス2つのうち、非負整数で大きい方のアドレス

**checkTotal**
チャネルのトークン数チェック
減資リクエストの `amount1` と `amount2` の和とチャネルのトークン量（`balanceOf(channel)`）より少ない場合 `true` となります。

**checkStatus**
チャネルステータスチェック
チャネルスのテータスが `Open:0` の場合 `true` となります。

**isActive**
署名有効チェック
解約リクエストの「署名値の有効期限」（UNIX時間秒）が `block.timestamp` 以降の場合 `true` となります。

**checkSign**
署名値チェック
署名値が有効（リカバリーアドレスが解約リクエストの `partner` と一致）な場合 `true` となります。

### 減資処理（Decrease Logic）

減資バリデーションが全て `true` の場合処理を行う。

1. 解約リクエストの `amount1` が `0` より大きい場合 `channel` から `address1` へ `amount1` を移動します。
1. 開設リクエストの `amount2` が `0` より大きい場合 `channel` から `address2` へ `amount2` を移動します。
1. 署名者（解約リクエストの `partner`）のNonceを消費します。
1. `DecreaseChannel` イベント（チャネルアドレスとインデックス）を発行します。

```sol
    event DecreaseChannel(address indexed channel, uint256 indexed index);
```

# 課題

## 保留イベントの監視

チャネル開設後は自身のチャンネルアドレスに関してチャネル保留イベントを監視をする必要があります。
取引が正常に完了している場合はリリースするまでの時間（`lockterm`）以内に確認する必要があります。
ルーティングを利用した取引が正常に終わらない場合は双方のチャネルを監視する必要があります。

## チャネル開設前のトークン

チャネル開始後はERC20のチャネルアドレスへのトークン移動を不可能にしていますが、チャネル開設前にはトークンの移動が可能です。
その為チャネル開設（`open`）にはトークン総量（`total`）が含まれています。

```sol
    // ERC20 _update override
    // Disable _update to channel
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (_channelInfo[to].status != _STATUS_NONE) {
            revert ChannelAddress(to);
        }
        super._update(from, to, value);
    }
```

# 謝辞（Acknowledgements）

この文章の作成に際し、適切な助言を賜りました[@KuwaharaIchiro](https://twitter.com/KuwaharaIchiro)さんに心より感謝申し上げます。

# 参考文献（References）

- The Bitcoin Lightning Network: Scalable Off-Chain Instant Payments<br>https://lightning.network/lightning-network-paper.pdf

- Lightning Network In-Progress Specifications<br>https://github.com/lightning/bolts

- eltoo: A Simple Layer2 Protocol for Bitcoin<br>https://blockstream.com/eltoo.pdf

- マスタリング・ライトニングネットワーク<br>ISBN: 978-4-8144-0014-0<br>https://www.oreilly.co.jp/books/9784814400140/

