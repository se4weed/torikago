# torikago

`torikago`は、Railsのmodular monolithでmoduleごとの実行境界を扱うためのgemです。`packwerk`や`Rails::Engine`で構造上の境界を作るだけでなく、`Ruby::Box`を使って実行時の境界も強くすることを目指しています。

`torikago`では、module間の呼び出しを`Torikago::Gateway.invoke(...)`に集約し、各moduleが公開するPackage APIのclass・methodと呼び出し可能なmoduleを事前に定義します。これによって、意図していないmodule間参照を実行時に防ぎやすくします。

![torikago architecture](docs/image.png)

## 設定例

Rails app側でmoduleを登録します。

```ruby
Torikago.configure do |config|
  config.register(
    :foo,
    root: Rails.root.join("modules/foo"),
    entrypoint: "app/package_api",    # optional
    setup: "config/box_setup.rb",     # optional
    gemfile: "Gemfile"                # optional
  )
end
```

`config.register`で指定できる主な項目は次のとおりです。

- `root`
  - moduleのルートディレクトリ
- `entrypoint`
  - public APIを探索するディレクトリ、またはその配下のファイル
  - 未指定時は`app/package_api`
- `setup`
  - Box boot前に読み込むsetup hook
  - monkey patchやbox固有の初期化処理に使う
- `gemfile`
  - そのBoxで優先したいgem require pathを解決するためのGemfile
  - Box cold boot時に、解決したrequire pathをそのBoxの`load_path`先頭側へ追加する
  - main box側のgem activationに頼らず、module codeからmodule-localなgem versionを`require`できるようにするための設定

module側では、公開するPackage APIと、どのmoduleから呼べるかを定義します。

```yaml
exports:
  Foo::ListProductsQuery:
    methods:
      - call
      - execute!
    allowed_callers:
      - baz
```

module自身からの呼び出しとmain boxからの呼び出しは許可されます。`allowed_callers`は、他moduleからの参照だけを制限します。

constructorに引数がない場合は、公開methodを直接指定します。

```ruby
Torikago::Gateway.invoke("Foo::ListProductsQuery", :call)

# method引数はmethod名より後ろへ渡す
Torikago::Gateway.invoke("Bar::SubmitOrderCommand", :execute!, title: "Book")
```

constructorに引数がある場合は`build`を使います。`build`の引数は`new`だけへ、`invoke`の引数は指定したpublic methodだけへ渡ります。

```ruby
Torikago::Gateway
  .build("Foo::ListProductsQuery", page: 2)
  .invoke(:execute!, per_page: 20)
```

対象Box内で`Foo::ListProductsQuery.new(page: 2).public_send(:execute!, per_page: 20)`を実行します。GatewayはBoxをbootする前にclass・method・callerを`package_api.yml`と照合します。private methodは呼べず、constructorや対象methodの例外は包まずそのまま伝播します。

`Gateway.call`は削除されました。`Gateway.call("Foo::Query", value)`は`Gateway.invoke("Foo::Query", :call, value)`へ変更し、manifestへ`methods: [call]`を追加してください。`update-package-api`は既存の`methods`を保持し、新規発見したentryには`methods: []`を生成するため、公開methodを明示的に選ぶ必要があります。

## Root Moduleの定数参照

Registered Moduleから、Railsアプリケーション本体（Root Module）のtop-level定数はmanifestへの宣言なしで参照できます。main boxの同じclass/module objectを共有するため、QueryやCommandの呼び出しだけでなく、継承にも利用できます。

Module namespace内から参照するときは、`::`で始まる絶対定数参照を使います。これにより、`Foo::Order`のtypoがRootの`::Order`へ暗黙にfallbackすることを防ぎます。

```ruby
# Railsアプリケーション本体
class Order
end

class CustomerQuery
  def self.call(customer_id:)
    # ...
  end
end

# config.register(:foo, ...)されたmodule内
class Foo::SpecialOrder < ::Order
end

::CustomerQuery.call(customer_id: 1)
```

ownershipはtop-level定数単位で判定します。top-level定数の定義元が`config.register(..., root:)`配下なら、その定数は別のModule Boxへ自動公開されません。Root-owned class/moduleは同じオブジェクトを共有するため、そのnamespaceをregistered rootから再オープンして子定数を追加すると、子定数だけを隔離できません。torikagoは検出可能な場合にnamespace全体の共有を拒否しますが、mixed-ownership namespace自体をサポートしません。隔離が必要な定数は、module-ownedなtop-level namespace配下へ配置してください。

Module Box内に同名定数がある場合は、そのmodule-local定数が優先されます。Root ModuleからRegistered Module、およびRegistered Module間の呼び出しには、引き続き`Torikago::Gateway`を使用してください。

## Example app

`example/rails-modular-monolith/`に、最小のRails example appが入っています。

## 使い方

### gem本体のテスト

```sh
bundle exec rake test
```

### example appのテスト

```sh
cd example/rails-modular-monolith
RUBY_BOX=1 bundle exec rails test
```

### example appの起動

```sh
cd example/rails-modular-monolith
RUBY_BOX=1 bundle exec rails s
```

`Ruby::Box`を実際に有効にするには`RUBY_BOX=1`が必要です。

## CLI

`exe/torikago`からCLIを利用できます。

```sh
bundle exec ruby exe/torikago --help
```

主なコマンド:

- `torikago init`
  - 対話式で`package_api.yml`と`config/initializers/torikago.rb`を生成する
- `torikago check`
  - `Gateway.invoke`および`Gateway.build(...).invoke(...)`とmanifestの整合性を検証する
- `torikago update-package-api [BOX]`
  - 設定済みentrypointから`package_api.yml`を更新する

`torikago check`は、`Ripper`で静的なGateway呼び出しを走査し、

- manifestにそのclassが定義されているか
- 呼び出すmethodが空でない`methods`配列に定義されているか
- 呼び出し元moduleが`allowed_callers`に含まれているか
- manifest上のclassに対応するファイルが存在するか
- 静的に確認できる場合、公開したinstance methodが実装されているか

を確認します。

## `RUBY_BOX=1`とbootについて

現状のexample appでは、`RUBY_BOX=1`下でRails bootを安定させるために、いくつか回避策を入れています。

- Bundler pluginを無効化する
- `tmpdir`を早めに読み込む
- `RUBY_BOX=1`時は`Bundler.require(*Rails.groups)`を避け、必要なgemを明示的に`require`する

これらは`torikago`の最終形というより、現時点でexampleを安定して動かすための実務的なworkaroundです。

## 現時点の制約

- 初回のBox bootは重い
  - cold boot時は数秒オーダーのコストが出ることがある
- `Ruby::Box`自体がexperimental
  - segfaultや不安定さに遭遇することがある
- Railsや一部gemとの相性問題がある
  - とくにVM全体へ影響するglobal-effect gemは、きれいに分離しきれない
- full `Rails::Engine` confinementを素直にやるのはまだ難しい

代表的な例外:

- `Torikago::DependencyError`
  - 許可されていないmodule間参照
- `Torikago::PublicApiError`
  - manifestに宣言されていないPackage API classまたはmethodの呼び出し
- `Torikago::BoxUnavailableError`
  - `RUBY_BOX=1`を指定したが対象Boxを生成・準備できなかった場合。main processへはfallbackしない
- `Torikago::GemfileOverrideError`
  - Box用Gemfileの解決やactivateに失敗したとき

そのため、現時点の`torikago`は「すぐ本番導入できる完成品」というより、modular monolithの実行境界をどこまで強くできるかを探る実装です。
