# MyBackup (personal backup script)
# 暗号バックアップスクリプト for Ubuntu Linux

Copyright:
MyBackup.sh Version 0.20250410
(C)2025 quawaz,watanabe
Lisense:
This project is licensed under the MIT License

2025/6, Ubuntu 24.04LTS, bash ver.5.2.21

## Usage:
定期＆手動お手軽暗号バックアップスクリプト
Tar/Zipで丸め暗号化、偽ファイル生成、外部ストレージや
他ホストへアップロード、レポート報告、動的マウントなど
普段のバックアップ用途でも手軽に使えるように配慮しました
本ファイル、Config:欄 にて、事前設定しご利用ください
貴方お好みに改修してお使いください
Ubuntu24.04LTS及びWSL2にて、動作確認しております
パスワードが記載されるため権限設定は確実に！
chmod 0700 ./MyBackup.sh

* cronでの定期実行
    crontab -e
    (super user) sudoedit /etc/cron. (daily,monthry..)
* logoff時の自動実行
    .bashrc:trap '/home/user/MyBackup.sh' EXIT
* クイックバックアップ
    好きなタイミングで適当なDirをバックアップ
    MyBackup.sh ./pictures
* 簡単解凍
    解凍も同じスクリプトで簡単
    MyBackup.sh ./buckup20250701.tar.gzc

## 注意
通常、表示は行いませんので、実運用に移行する前は、
“-v"オプションを付けて、テストしてください
(_DEBUGフラグもtrueを推奨。後述)

一部機能の利用には、別途パッケージ導入が必要になります
必要な場合、事前に導入ください
mailutils、smbclient、curl、特殊なmount関連 など

各部の動作テスト用のオプションを用意しています
–test-upload など

利用による結果には責任を負いません
利用者様の自己責任において、十分に留意の上ご利用ください

## flow / 処理内容
以下、処理の流れになります

    -モード切替

        -マウント

        -空き容量確認

        -古いバックアップ削除

        -Tar又はZip丸め

        -Tar又はZip丸め(ユーザー定義*1)

            -暗号化

            -Tar又はZip生成ファイル削除

        -他ホストへアップロード(scp/samba/ユーザー定義*2他)

            -生成ファイル削除

        -偽ファイル生成(default:off)


    *trap:EXIT

    -後処理

        -書込フラッシュ

        -アンマウント

        -レポート(syslog/chat/mail/ユーザー定義*3他)

        -ユーザー定義*4


    *trap:ERR

        -エラー表示（DEBUG情報）


    ※ 各工程のON/OFF可

    ※ 途中でエラー時は終了(DEBUGモードによる)

    ユーザー定義

    *1:fn_ex_build_balls()

    *2:fn_ex_upload()

    *3:fn_ex_report()

    *4:fn_ex_exit()

—
## mount / マウント

様々な保存先があるかと想定、セキュリティ的にも？
マウント関連も制御出来るように致しました
一般ユーザーで利用される場合は、予め /etc/fstab に設定が必要になります
マウント後、空き容量確認などが行われます(ON/OFF可)
後述のアップロード機能で、他ホストへ転送される場合は、これらは不要になります

—
## output / 出力ファイル

    [prefix][target dir name][time stamp][ext]

    例) Backup_Document_20250101.tar.gzc
    ※ 各部位変更可

—
## decode / 手動による解凍

生成したファイルを展開するには、先に復号化が必要になります
(デフォルト設定の場合は以下)
-in 対象のファイル名
-out 出力ファイル名
openssl enc -d -aes-256-cbc -pbkdf2 -in xxx.tar.gzc -out xxx.tar.gz
(パスワード入力)

その後、Tar又はZipにて展開します
カレントに、ディレクトリが生成され、その中に展開されます
(Tarは標準的な gzip 圧縮限定となります)
tar -xvf xxx.tar.gz
unzip xxx.zip

*デフォルト設定は標準的な暗号化(AES/256bit)となります

—
## 簡単解凍

解凍も当スクリプトにて簡単に行う事が出来ます
パスワードや、コマンドの引数などを再度調べ直す手間が省けます
Tarデフォルト設定という条件で、その場に簡単に解凍出来ます
(既に設定済みのもので解凍を試みます、途中で変更された場合は不可能)
複数指定が可能、オプション指定はありません
_ez_decodeというディレクトリが作られ、その中に展開されます

    例) ./MyBackup.sh ./xxxx.tar.gzc
    例) ./MyBackup.sh ./*.tar.gzc

—
## クイックバックアップ

直接ディレクトリを指定して、バックアップを行えます
予め設定された場所に保存されます
複数指定が可能、オプション指定はありません
ディレクトリ毎に１ファイル生成されます

    例) ./MyBackup.sh ./work
    例) ./MyBackup.sh ./dir*

—
## アップロード

生成ファイルを他ホストなどへ転送（冗長）を行えます
方法は以下の種類、他、ユーザー定義も指定できます
アップロード後、ローカル生成ファイルを削除する事ができます
通信経路上のセキュリティや、通信負荷も考慮してください
事前にセキュリティ設定やコマンド導入が必要になります
–test-upload にて動作テストが行えます

    scp
        SSHファイル転送(scp)
    samba
        Windowsファイル送信(smbclient)
    http
        HTTPによるアップロード(curl)
    ftp
        FTPによるファイル転送(curl)
    sftp
        SFTPによるファイル転送(sftp)
    rsync
        ファイル同期(rsync)
    mail
        メール添付による送信(mail)
    user
        ユーザー定義(fn_ex_upload)

    * 括弧内は利用するコマンド

—
## レポート

バックアップ結果を報告する事が出来ます
方法は以下の種類、他、ユーザー定義も指定できます
事前にセキュリティ設定やコマンド導入が必要になります
通常バックアップ動作モードのみ動作します
–test-report にて動作テストが行えます

    chat
        現在ログイン中のユーザーに報告(wall)
    log
        syslogに記録(logger)
    mail
        メールによる送信
    http
        HTTPアクセス(apiなどに)(curl)
    user
        ユーザー定義(fn_ex_report)(curl)

—
## 運用前・改造・ユーザー定義関数他

複雑なコードは御座いませんので、ご自由に改変ください
十分なデバッグを行っておりますが、複数の環境想定、全パターンでの確認は実施しておりません
バグは含んでいるものとして、お考えください
本運用に入る前に、十分なテストを行ってください
_DEBUG に true を設定する事で、その場で動作を停止する事ができます
エラー内容や場所、グローバル変数値が表示されます
テスト完了後には、_DEBUG に、false を設定してください
テスト時のパスワード情報の削除なども忘れず（history -c など）

ユーザー定義関数は以下になります
独自の処理を導入されたい場合に、記述ください

バックアップファイル生成
    fn_ex_build_balls
アップロード
    fn_ex_upload
リポート
    fn_ex_report
終了時(通常バックアップモード時)
    fn_ex_exit

ライセンスは、広く利用されている MITライセンス となります
商用、改変なども自由に利用頂けます
配布の際、著作権表記が必要になります

一見、プログラミング言語の様に見えるのは罠ですのでご注意ください
シェル上で動作しているイメージを忘れずコーディングください

もともとサーバのバックアップ用にと、数行のスクリプトでしたが、
こつこつと機能を加え続け、現在のような形になって行き
公開するに当たって、ドキュメント含め、全体的な見直しを幾度も行い、
より肥大化してしまいました
シェルに不慣れな方のために、コメントも多めに追加致しました
当初は、SSH上(Ubuntu24.04LTS実機)+Vimで、後半はWSL2(同24.04)+VSCodeで書きました
 Bashやシェルコードの記事を公開して頂いている多くの先人様に感謝申し上げます
—
## arguments / 引数

    通常バックアップ
    (規定場所のバックアップ)
    例) ./MyBackup.sh
    バックアップ、進捗表示、偽ファイル生成
    例) ./MyBackup.sh -v -f
    暗号化生成までで終わり、進捗表示
    例) ./MyBackup.sh -v -e

    mode:簡単解凍
    例) ./MyBackup.sh backup_20250401.tar.gzc
    mode:クイックバックアップ
    例) ./MyBackup.sh ./work

### options:
-b|–ball
    build tar/zip only
    Tar/Zip生成のみで終了します
-e|–encrypt
  exit after encrypted
    暗号化生成までで終了します
-g|–organize
    do not remove older-backups
    古いバックアップ削除を行いません
-h|man|–help|info|usage|ver
    this document
    ドキュメントを表示します
-v|–verbose
    reporting
    処理情報を表示します
    *通常モード外では強制ONとなる場合有り
-f|–fake
    added fake-file
    偽バックアップファイルを追加生成

### quick-modes:
*自動で、-vが付与されます

[filename] [filename] …
    mode:簡単解凍、カレントの"_ez_decode"ディレクトリ内に解凍
    他のオプションは機能しません
    (Tar/Gzip関連デフォルト値限定)

[directory] [directory] …
    mode:簡単クイックバックアップ
    設定値で、対象をバックアップし保存します
    他のオプションは機能しません

### test-modes:
*自動で、-vが付与されます
–test-file
    mode:動作テスト用のファイルを生成します
–remove-test-file
    mode:動作テスト用のファイルを削除します
–test-mount
    mode:マウントの動作テストを行います
–test-available
    mode:ディスクチェックの動作テストを行います
–test-upload
    mode:アップロードの動作テストを行います
    ダミーファイルが用いられます
–test-report
    mode:レポートの動作テストを行います

### ???-modes:
no|none|pass|null|nurupo|hoge*|fuga*
    mode:何もしません
color|colors|ansi
    mode:設定用カラーサンプル表示
–fuck|*fuck*
    mode:気分転換にご利用ください
–poop|*poop*|*shit*|*ass*|*unko*|*kuso*
    mode:１つだけ何か混じってます
sl|ls
    mode:special animation. *require “sl"

Zz. (¦3[▓▓]
