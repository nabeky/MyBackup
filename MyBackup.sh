#!/bin/bash

# MyBackup.sh (personal backup script), Japanese
# dev. Bash5/Ubuntu24.04LTS,WSL2 Watanabe@quawaz
set -uo pipefail -o errtrace
declare -gr _PROGNAME='MyBackup'
declare -gr _PROGFILE=${0##*/}
declare -gr _PROGNAME_EXT=${0##*.}
declare -gr _CURDIR=$(pwd)
declare -gr _SAVE_IFS="${IFS}"
# global var.
declare -g _MODE=''
declare -g _PROGFASE='init'
declare -gi _CNT_PRINT=1
declare -g _LOG_MSG=''
declare -g _ERROR=''
declare -ga _LS_BALLS=()
declare -ga _LS_CRYPTS=()
declare -gr _LINE=$(yes '-' | head -n 48 | tr -d '\n')
declare -gir _TIME_BEGIN=${SECONDS}
## Include(opt.)
#source bug_fravor.sh
#source my_wetpants.sh
#source dynamite_shikoku.sh
##============================================================-
##
## [[ Config !! ]]
## 
## 注意)
##	= の前後に、空白を入れず続けて記述ください
## 	余計な空白やタブ等も避けてください
## 	全てシェル上で解釈される事をご留意ください
##	色が付くエディタで編集される事をオススメします
##
##	* "_ARGS" で終わる項目は、コマンドへの引数
##	* "_FLAG" で終わる項目は、true 又は、false
##	* true/false はフラグの意味、小文字で記述
##	* declare -gr 等は、変数を定義するコマンド
##	* "#" で始まる行は、コメント
##
##	当ファイルのパーミッション設定は確実に行ってください
##
##============================================================-
## [Config:Debug]
## 実運用時はfalseにしてください
declare -gr _DEBUG=false
${_DEBUG} || set +eEx

## [Config:Secure]
## 表示内容(ホスト名など)など制限
declare -gr _SECURE=false

## [Config:esc seq.(color)]
## 主にテキスト色
#* 当スクリプト引数に color で、色コードを確認出来ます
declare -gr _AE_TITLE1='\e[1;97;104m'
declare -gr _AE_TITLE2='\e[1;97;44m'
declare -gr _AE_TITLE3='\e[1;37;44m'
declare -gr _AE_SUB1='\e[30;107m'
declare -gr _AE_SUB2='\e[30;47m'
declare -gr _AE_SUB3='\e[40;97m'
declare -gr _AE_DESC='\e[97m'
declare -gr _AE_MODE='\e[42;97m'
declare -gr _AE_INFO='\e[33;49m'
declare -gr _AE_STRONG='\e[43;31m'
declare -gr _AE_NO='\e[37;44m'
declare -gr _AE_LIST='\e[96m'
declare -gr _AE_INPUT='\e[97;44m'
declare -gr _AE_WARN='\e[33;45m'
declare -gr _AE_ALERT='\e[31m'
declare -gr _AE_CONFIG='\e[93;49m'
declare -gr _AE_ERROR='\e[93;41m'
declare -gr _AE_ERRORMSG='\e[91;49m'
declare -gr _AE_SYMBOL='\e[40;31m'
declare -gr _AE_LINE='\e[95m'
declare -gr _AE_JOKE='\e[6;93;45m'
declare -gr _AE_DEF='\e[39;49m'	# default
declare -gr _AE_RST='\e[0m'
#
declare -gr _AE_BLACK='\e[30m'
declare -gr _AE_RED='\e[31m'
declare -gr _AE_GREEN='\e[32m'
declare -gr _AE_YELLOW='\e[33m'
declare -gr _AE_BLUE='\e[34m'
declare -gr _AE_PURPLE='\e[35m'
declare -gr _AE_CYAN='\e[36m'
declare -gr _AE_WHITE='\e[37m'
#
declare -gr _AE_BG_BLACK='\e[40m'
declare -gr _AE_BG_RED='\e[41m'
declare -gr _AE_BG_GREEN='\e[42m'
declare -gr _AE_BG_YELLOW='\e[43m'
declare -gr _AE_BG_BLUE='\e[44m'
declare -gr _AE_BG_PURPLE='\e[45m'
declare -gr _AE_BG_CYAN='\e[46m'
declare -gr _AE_BG_WHITE='\e[47m'

##------------------------------------------------------------.
## [Config:ez decode]
## 簡単解凍 出力先(カレント上)
#* 解凍時、この名称でディレクトリが生成されます
declare -gr _EZ_OUTDIR='_ez_decode/'

##------------------------------------------------------------.
## [Config:Storage device]
## 保存先デバイス

#* 動的な mount を行う場合に true にて設定してください
#* (一般ユーザーで行う場合は、予め /etc/fstab に、user 記述)
#* 例) /dev/sdb1 /mnt/backup ext4 noauto,user,rw 0 0
declare -gr _DEV_MOUNT_F=false
# unmount
declare -gr _DEV_UNMOUNT_F=false

# mount command
#* ファイルシステム種類(-t) *s.user
#* vfat/fat/ntfs/msdos : メモリカードやWindows系
#* xfs/ext2,3,4/nfs : Linux系
#* iso9660/udf : CD,DVD,Bluray
#* cifs : Windowsファイル共有(要cifs-utils)
#* 例) -t cifs //192.168.1.1/share -o username=user,password=pw,uid=user,vers=3.1
declare -gr _DEV_ARGS='-t ext4'
# マウント先(一般ユーザーで行う場合、空設定)
declare -gr _DEV_MNT_PATH=''

# device
#* 保存先デバイス
#* 処理前に空き容量を確認します
#* 空の場合、確認しません(保存先がネットワーク先など)
declare -gr _DEV_STORAGE='/dev/sda'
#declare -gr _DEV_STORAGE='/dev/sr0'	# CD/DVD/Blueray
#declare -gr _DEV_STORAGE='/dev/st0'	# Tape
#declare -gr _DEV_STORAGE='/dev/rmt/0'	# Tape

#* 空き容量確認（単位MiB）
#* 指定より空き容量が少ない場合エラー
declare -gri _DEV_MIN=512

##------------------------------------------------------------.
## [Config:Backup storage]
## バックアップ保存先(又は、書出ディレクトリ)
#* WSLの場合は、/mnt/c 以下でWindows側に出力できます
declare -gr _DIR_STORAGE_BACKUPS='/var/tmp'
#declare -gr _DIR_STORAGE_BACKUPS='/mnt/backup'
#declare -gr _DIR_STORAGE_BACKUPS='/media/backup'
#declare -gr _DIR_STORAGE_BACKUPS='/mnt/c/Users/USERNAME/OneDrive/Documents'

##------------------------------------------------------------.
## [Config:Backup targets]
## バックアップ対象リスト(デフォルト)
#* テスト時は、'./_bktest/'をお使い頂けます
#* --test-file でテスト用ファイル一式を生成できます(_bktest)
declare -gra _DIR_TARGETS=(
#	'./_bktest/'
	'/home/user/Documents/'
	'/home/user/Pictures/'
	'/home/user/Music/'
	'/home/user/Desktop/'
#	'/usr/share/nginx/html/'
#	'/var/lib/mysql/'
#	'/var/samba/'
#	'/etc/'
#	'/var/log/'
)
# 除外ファイル/ディレクトリ
#* Samba:ゴミ箱(.recycle)等(複数可)
#* ワイルドカード等が使えます
declare -gra _EXCLUDES=(
	'.recycle/'
	'.ssh/'
	'.ero_pictures/'
#	'*.jpg'
)

##------------------------------------------------------------.
## [Config:Build tar/zip]
## ファイル丸める設定
declare -gr _BALL_TYPE='tar'	# tar/zip
declare -gr _BALL_PREFIX='backup_'
declare -gr _FILE_PERMIT='0600'
declare -gr _FILE_OWNER=''
declare -gr _TIMESTAMP=$(date +'%Y%m%d_%H%M')

# tar command の場合
#* gzip圧縮のみ("z"指定は不要)
declare -gr _TAR_ARGS='-cf'
declare -gr _TAR_EXT='.tar.gz'
# tar/gzip引数
# 圧縮率(-1:low -9:high)
declare -gr _GZIP_ARGS='-c'

# zip command の場合
#* -r:dir -P:zip-password
#* 圧縮率(-1:low -9:high)
declare -gr _ZIP_ARGS='-r'

##------------------------------------------------------------.
## [Config:Encrypt(openssl)]
## 暗号化設定(true/false)
declare -gr _ENCRY_FLAG=true
# password
declare -gr _ENCRY_PW='Atari2600_ET_100Yen'
#declare -gr _ENCRY_PW='Action52_Cheetahmen_20Yen'
#declare -gr _ENCRY_PW='Takeshi_Challenge_10Yen'
#declare -gr _ENCRY_PW='Raid_on_Bungeling_Bay_Free'

# openssl command
#* ciphers list 'openssl enc -list'
declare -gr _ENCRY_ARGS="-aes-256-cbc -pbkdf2 -salt -pass pass:${_ENCRY_PW}"
declare -gr _ENCRY_EXT='.tar.gzc'

##------------------------------------------------------------.
## [Config:Remove older backups]
## 古バックアップ削除設定
#* days / 単位日(経過) +730=2years(365*2)
declare -gr _RM_MTIME='+730'

##------------------------------------------------------------.
## [Config:Upload]
## 他ホストにアップロードする場合の設定(true/false)
declare -gr _UPLOAD_FLAG=false
# タイプ
#* (scp/samba/http/ftp/sftp/rsync/mail/user)
#* 他の方法は、fn_ex_upload にてユーザー定義できます
declare -gr _UPLOAD_TYPE='samba'
# アップロード後生成ファイルを削除(true/false)
declare -gr _UPLOAD_DELETE_ORG_F=true

#* scp(tcp/port 22) -P:port -i:keyfile
declare -gr _SCP_ARGS='-P 22 -i ~/.ssh/id_rsa'
declare -gr _SCP_DEST='user@192.168.1.200:~/backup/'
#* sftp(tcp/port 22)
declare -gr _SFTP_ARGS='-q -i ~/.ssh/id_rsa user@host:backup/'

#* samba/smbclient -D:dest-curdir -W:domain -m:protcol -A:config -q:quiet
#* -m:SMB3_11 (windows11)
declare -gr _SMB_ARGS='"//192.168.1.100/holder" -U user%password -q'
#declare -gr _SMB_ARGS='"//192.168.1.100/holder" -D "/backup" -W "WORKGROUP" -U user%password -q'

#* http/ftp(port 443,80/20,21) using "curl" -F:parameter
declare -gr _HTTP_ARGS='-X PUT https://moj.go.jp/api -F egg=muffin -F zunda=mochi'
declare -gr _FTP_ARGS='-u user:pw ftp://192.168.0.100/backup'

#* rsync(tcp/port 873 or 22)
#* --exclude --delete
declare -gr _RSYNC_ARGS='-arzu -e ssh'
declare -gr _RSYNC_DEST='user@host:~/backup/'

#* mail address
declare -gr _UPLOAD_MAILADR='user@host.jp'

##------------------------------------------------------------.
## [Config:Report]
## レポート
# タイプ (chat/log/mail/http/user)
#* 他の方法は、fn_ex_report にてユーザー定義が出来ます
declare -gra _REPORT_ACTS=(
#	'log'
#	'mail'
#	'user'
)
#* chat:wall command
declare -gr _REPORT_CHAT='Done, backups!'
#* log:logger command
declare -gr _REPORT_LOGARG="-t ${_PROGNAME} done."
#* mail:mail command(メール送信の設定が必要)
#* 本文以降にログが追加されます
declare -gr _REPORT_MAIL=$(cat << EOL
succeeded backup jobs.
maybe
.
EOL
)
declare -gr _REPORT_MAILADR='user@host.jp'
#* http:curl command
#* 指定アドレスにHTTPアクセスする(それだけ)
declare -gr _REPORT_HTTP='https://5ch.net/?age'

##------------------------------------------------------------.
## [Config:Fakefile]
## 偽ファイル生成(random bin.)生成ファイル名
#* リスト分生成されます
#* 中身はランダムなバイナリとなります
#* 他のバックアップと似たようなファイル名になります
declare -gra _FAKEFILE_LIST=(
	'BitCoins_'
	'CryptoCurrency_'
	'IdPasswords_'
	'Accounts_'
	'Finance_'
	'Members_'
)
# ファイルサイズ(KiB,x + random(x / 13))
declare -gri _FAKEFILE_SIZE=10

##------------------------------------------------------------.
## [Config:user extend functions]
## build:user custom
## 個別にビルドする必要がある場合
##* 例) MySQL/MariaDBのダンプバックアップ
function fn_ex_build_balls() {
	return 0	# <<-

	fn_print "user: in ${_AE_INFO}fn_ex_build_balls"
	local _host='localhost'
	local _cnf_file='/home/user/mysql_backup.cnf'
	local _db_name='ur_database_name'
	local _output=${_DIR_STORAGE_BACKUPS%/}/mysql.sql

	# mysql/mariadbダンプ
	#例) --all-databases,--lock-all-tables
	#*mysql_backup.cnf < id/password
	mysqldump --defaults-extra-file="${_cnf_file}" \
		-h "${_host}" --flush-logs --databases "${_db_name}" > "${_output}"
	[[ $? -ne 0 ]] && {
		fn_print 'mysql-dump error'
		return 1
	}

	# build tar/gzip
	fn_build_balls '_output' ${_BALL_TYPE}

	fn_print "user: out ${_AE_INFO}fn_ex_build_balls"
	return 0
}

## upload:user custom
##*type "user"
## 独自のUploadが必要な場合
## 1:files(ref)
function fn_ex_upload() {
	fn_print "user: in ${_AE_INFO}fn_ex_upload"
	local _ref=$1
	declare -n _files=${_ref}
	local _output

	# send to blackhole
	_output='/dev/null'
	cp ${_files[@]} ${_output}
	if [[ $? -eq 0 ]];then
		:
	else
		:
	fi

	fn_print "user: out ${_AE_INFO}fn_ex_upload"
	return 0
}

## report:user custom
## 独自のReportが必要な場合*type "user"
## 1:exit-code
function fn_ex_report() {
	local _result=$1
	fn_print "user: in ${_AE_INFO}fn_ex_report"

	# ${_LOG_MSG}: fn_print() log(raw text)
	# ${_LS_BALLS}: tar/zip files(array)
	# ${_LS_CRYPTS}: encrypted files(array)
	# ${_DIR_STORAGE}: storage
	# ${_DEV_STORAGE}: device
	# ${_ERROR}: error info
	echo 'fxck u!!' > /dev/null

	fn_print "user: out ${_AE_INFO}fn_ex_report"
	return 0
}

## exit:user custom
## 後処理が必要な場合(終了時必ず呼ばれます)
## 1:exit-code
function fn_ex_exit() {
	return 0	# <<-

	local _result=$1
	fn_print "user: in ${_AE_INFO}fn_ex_exit"
	if [[ $1 -eq 0 ]];then
		:
	else
		:
	fi
	fn_print "user: out ${_AE_INFO}fn_ex_exit"
	return 0
}
##------------------------------------------------------------.
## [ Config !! end ] Z z .(¦3[▓▓]
##------------------------------------------------------------.
# .:empty-line --:line []:color
readonly _USAGE=$(cat <<"EOL"
[_AE_TITLE1]
MyBackup (personal backup script)
暗号バックアップスクリプト for Ubuntu Linux
[_AE_DEF]
（上下左右にスクロール出来ます）
.
Copyright:
[_AE_DEF]
MyBackup.sh Version 0.20250621
(C)2025 quawaz,Watanabe
Lisense:
[_AE_DEF]
This project is licensed under the MIT License
https://licenses.opensource.jp/MIT/MIT.html
.
2025/6, Ubuntu 24.04LTS, bash ver.5.2.21
--
[_AE_STRONG]
Usage:
[_AE_DESC]
定期＆手動お手軽暗号バックアップスクリプト
Tar/Zipで丸め暗号化、偽ファイル生成、外部ストレージや
他ホストへアップロード、レポート報告、動的マウントなど
普段のバックアップ用途でも手軽に使えるように配慮しました
本ファイル、Config:欄 にて、事前設定しご利用ください
貴方お好みに改修してお使いください
Ubuntu24.04LTS及びWSL2にて、動作確認しております
.
[_AE_INFO]
パスワードが記載されるため権限設定は確実に！
chmod 0700 ./MyBackup.sh
.
[_AE_LIST]
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
.
--
[_AE_TITLE2]
 注意 
[_AE_DEF]
.
[_AE_INFO]
通常、表示は行いませんので、実運用に移行する前は、
"-v"オプションを付けて、テストしてください
(_DEBUGフラグもtrueを推奨。後述)
.
一部機能の利用には、別途パッケージ導入が必要になります
必要な場合、事前に導入ください
mailutils、smbclient、curl、特殊なmount関連 など
.
各部の動作テスト用のオプションを用意しています
--test-upload など
.
利用による結果には責任を負いません
利用者様の自己責任において、十分に留意の上ご利用ください
--
[_AE_TITLE2]
 flow / 処理内容
[_AE_DEF]
.
以下、処理の流れになります
.
[_AE_LIST]
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
.
	*trap:EXIT
	-後処理
		-書込フラッシュ
		-アンマウント
		-レポート(syslog/chat/mail/ユーザー定義*3他)
		-ユーザー定義*4
.
	*trap:ERR
		-エラー表示（DEBUG情報）
.
[_AE_DEF]
	※ 各工程のON/OFF可
	※ 途中でエラー時は終了(DEBUGモードによる)
	ユーザー定義
	*1:fn_ex_build_balls()
	*2:fn_ex_upload() 
	*3:fn_ex_report()
	*4:fn_ex_exit()
.
--
[_AE_TITLE2]
 mount / マウント
[_AE_DEF]
.
様々な保存先があるかと想定、セキュリティ的にも？
マウント関連も制御出来るように致しました
一般ユーザーで利用される場合は、予め /etc/fstab に設定が必要になります
マウント後、空き容量確認などが行われます(ON/OFF可)
後述のアップロード機能で、他ホストへ転送される場合は、これらは不要になります
.
--
[_AE_TITLE2]
 output / 出力ファイル 
[_AE_DEF]
.
	[prefix][target dir name][time stamp][ext]
.
[_AE_LIST]
	例) Backup_Document_20250101.tar.gzc
	※ 各部位変更可
.
--
[_AE_TITLE2]
 decode / 手動による解凍 
[_AE_DEF]
.
生成したファイルを展開するには、先に復号化が必要になります
(デフォルト設定の場合は以下)
[_AE_LIST]
-in 対象のファイル名
-out 出力ファイル名
openssl enc -d -aes-256-cbc -pbkdf2 -in xxx.tar.gzc -out xxx.tar.gz
(パスワード入力)
.
[_AE_DEF]
その後、Tar又はZipにて展開します
カレントに、ディレクトリが生成され、その中に展開されます
(Tarは標準的な gzip 圧縮限定となります)
[_AE_LIST]
tar -xvf xxx.tar.gz
unzip xxx.zip
[_AE_DEF]
.
*デフォルト設定は標準的な暗号化(AES/256bit)となります
.
--
[_AE_TITLE2]
 簡単解凍 
[_AE_DEF]
.
解凍も当スクリプトにて簡単に行う事が出来ます
パスワードや、コマンドの引数などを再度調べ直す手間が省けます
Tarデフォルト設定という条件で、その場に簡単に解凍出来ます
(既に設定済みのもので解凍を試みます、途中で変更された場合は不可能)
複数指定が可能、オプション指定はありません
_ez_decodeというディレクトリが作られ、その中に展開されます
.
[_AE_LIST]
	例) ./MyBackup.sh ./xxxx.tar.gzc
	例) ./MyBackup.sh ./*.tar.gzc
.
--
[_AE_TITLE2]
 クイックバックアップ 
[_AE_DEF]
.
直接ディレクトリを指定して、バックアップを行えます
予め設定された場所に保存されます
複数指定が可能、オプション指定はありません
ディレクトリ毎に１ファイル生成されます
.
[_AE_LIST]
	例) ./MyBackup.sh ./work
	例) ./MyBackup.sh ./dir*
.
--
[_AE_TITLE2]
 アップロード
[_AE_DEF]
.
生成ファイルを他ホストなどへ転送（冗長）を行えます
方法は以下の種類、他、ユーザー定義も指定できます
アップロード後、ローカル生成ファイルを削除する事ができます
通信経路上のセキュリティや、通信負荷も考慮してください
事前にセキュリティ設定やコマンド導入が必要になります
--test-upload にて動作テストが行えます
.
[_AE_LIST]
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
.
	* 括弧内は利用するコマンド
.
--
[_AE_TITLE2]
 レポート
[_AE_DEF]
.
バックアップ結果を報告する事が出来ます
方法は以下の種類、他、ユーザー定義も指定できます
事前にセキュリティ設定やコマンド導入が必要になります
通常バックアップ動作モードのみ動作します
--test-report にて動作テストが行えます
.
[_AE_LIST]
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
.
--
[_AE_TITLE2]
 運用前・改造・ユーザー定義関数他
[_AE_DEF]
.
複雑なコードは御座いませんので、ご自由に改変ください
十分なデバッグを行っておりますが、複数の環境想定、全パターンでの確認は実施しておりません
バグは含んでいるものとして、お考えください
本運用に入る前に、十分なテストを行ってください
_DEBUG に true を設定する事で、その場で動作を停止する事ができます
エラー内容や場所、グローバル変数値が表示されます
テスト完了後には、_DEBUG に、false を設定してください
テスト時のパスワード情報の削除なども忘れず（history -c など）
.
ユーザー定義関数は以下になります
独自の処理を導入されたい場合に、記述ください
.
[_AE_LIST]
バックアップファイル生成
	fn_ex_build_balls
アップロード
	fn_ex_upload
リポート
	fn_ex_report
終了時(通常バックアップモード時)
	fn_ex_exit
[_AE_DEF]
.
ライセンスは、広く利用されている MITライセンス となります
商用、改変なども自由に利用頂けます
配布の際、著作権表記が必要になります
.
一見、プログラミング言語の様に見えるのは罠ですのでご注意ください
シェル上で動作しているイメージを忘れずコーディングください
.
もともとサーバのバックアップ用にと、数行のスクリプトでしたが、
こつこつと機能を加え続け、現在のような形になって行き
公開するに当たって、ドキュメント含め、全体的な見直しを幾度も行い、
より肥大化してしまいました
シェルに不慣れな方のために、コメントも多めに追加致しました
当初は、SSH上(Ubuntu24.04LTS実機)+Vimで、後半はWSL2(同24.04)+VSCodeで書きました
Bashやシェルコードの記事を公開して頂いている多くの先人様に感謝申し上げます
--
EOL
);readonly _USAGE_OPT=$(cat <<"EOL"
[_AE_TITLE2]
arguments / 引数
[_AE_DEF]
.
	通常バックアップ
	(規定場所のバックアップ)
[_AE_LIST]
	例) ./MyBackup.sh
[_AE_DEF]
	バックアップ、進捗表示、偽ファイル生成
[_AE_LIST]
	例) ./MyBackup.sh -v -f
[_AE_DEF]
	暗号化生成までで終わり、進捗表示
[_AE_LIST]
	例) ./MyBackup.sh -v -e
[_AE_DEF]
.
	mode:簡単解凍
[_AE_LIST]
	例) ./MyBackup.sh backup_20250401.tar.gzc
[_AE_DEF]
	mode:クイックバックアップ
[_AE_LIST]
	例) ./MyBackup.sh ./work
.
options:
[_AE_LIST]
.
-b|--ball
	build tar/zip only
	Tar/Zip生成のみで終了します
-e|--encrypt
  exit after encrypted 
	暗号化生成までで終了します
-g|--organize
	do not remove older-backups
	古いバックアップ削除を行いません
-h|man|--help|info|usage|ver
	this document
	ドキュメントを表示します
-v|--verbose
	reporting
	処理情報を表示します
	*通常モード外では強制ONとなる場合有り
-f|--fake
	added fake-file
	偽バックアップファイルを追加生成
.
quick-modes:
[_AE_DEF]
*自動で、-vが付与されます
.
[_AE_LIST]
[filename] [filename] ...
	mode:簡単解凍、カレントの"_ez_decode"ディレクトリ内に解凍
	他のオプションは機能しません
	(Tar/Gzip関連デフォルト値限定)
.
[directory] [directory] ...
	mode:簡単クイックバックアップ
	設定値で、対象をバックアップし保存します
	他のオプションは機能しません
.
test-modes:
[_AE_DEF]
*自動で、-vが付与されます
.
[_AE_LIST]
--test-file
	mode:動作テスト用のファイルを生成します
--remove-test-file
	mode:動作テスト用のファイルを削除します
--test-mount
	mode:マウントの動作テストを行います
--test-available
	mode:ディスクチェックの動作テストを行います
--test-upload
	mode:アップロードの動作テストを行います
	ダミーファイルが用いられます
--test-report
	mode:レポートの動作テストを行います
.
???-modes:
[_AE_DEF]
.
[_AE_LIST]
no|none|pass|null|nurupo|hoge*|fuga*
	mode:何もしません
color|colors|ansi
	mode:設定用カラーサンプル表示
--fuck|*fuck*
	mode:気分転換にご利用ください
--poop|*poop*|*shit*|*ass*|*unko*|*kuso*
	mode:１つだけ何か混じってます
sl|ls
	mode:special animation. *require "sl"
.
[_AE_DEF]
Zz. (¦3[▓▓] press "Q" to exit
EOL
)
## build usage
## 1:text(ref)
function fn_build_usage() {
	declare -n _text="$1"
	local _buf=''
	local _color=''
	local _ref=''
	for _X in ${_text[@]};do
		if [[ ${_X} =~ ^\.$ ]];then
			_X=''
		fi
		if [[ ${_X} =~ .+:$ ]];then
			declare -n _ref='_AE_STRONG'
		fi
		if [[ ${_X} =~ ^--$ ]];then
			_buf+="${_AE_LINE}${_LINE}\n"
			continue
		fi
		if [[ ${_X} =~ ^\[(\_[_A-Z1-9]+)\]$ ]];then
			declare -n _ref=${BASH_REMATCH[1]}
			continue
		fi
		_buf+="${_AE_LINE}|${_ref} ${_X:- } ${_AE_DEF}\n"
	done
	echo -en ${_AE_RST}
	echo -en ${_buf}
}
## usage
function fn_usage() {
	local _usage=${_USAGE[@]}
	IFS=$'\n'
	_usage+=(${_USAGE_OPT[@]})
	fn_build_usage '_usage' | less -mMNRSx4#2 --use-color;
	return 0
}

## trap:Error
function on_error() {
	local _a _type _var
	_ERROR="${BASH_SOURCE[1]} (Fase: \"${_PROGFASE}\" Line: ${BASH_LINENO}) ${BASH_COMMAND}"
	echo -e "\n${_AE_ERROR}[DEBUG] ${BASH_SOURCE[1]} (Fase: \"${_PROGFASE}\" Line: ${BASH_LINENO}) ${_AE_DEF}\n${_AE_ERRORMSG}${BASH_COMMAND}${_AE_DEF}">&2
	echo -e ${_AE_ERROR}"[DEBUG] global vars: ${_AE_DEF}"
	IFS=$' ';while read _a _type _var;do
		[[ $_type =~ ^(--|-i|-a|-A|-n)$ && $_var =~ ^_[_A-Z0-9]+ ]] && \
			echo -e "${_AE_ERRORMSG}$_var${_AE_DEF}"
	done < <(declare -p);echo ' ';exit 1
}
${_DEBUG} && trap on_error ERR
## trap:Finally
function on_finally() {
	local _result=$?
	_PROGFASE='finally'
	[[ "${_MODE}" = *"M"* ]] && {
		# user ex.
		fn_ex_exit ${_result}
		# unmount device
		if ${_DEV_UNMOUNT_F}; then
			fn_unmount_storage "${_DEV_STORAGE}" "${_DEV_MNT_PATH}"
		fi
		# last log
		fn_print "$(date +'%Y/%m/%d %H:%M:%S') ( $((${SECONDS}-${_TIME_BEGIN})) sec.)"
		# report
		fn_do_report '_REPORT_ACTS' ${_result}
		fn_print "exit: ${_AE_INFO}${_result}"
	}

	# delete functions
	unset fn_ex_build_balls fn_ex_upload fn_ex_report fn_ex_exit
	unset fn_mount_storage
	unset fn_check_available
	unset fn_excludes
	unset fn_build_balls
	unset fn_to_encrypt
	unset fn_remove_balls
	unset fn_remove_older_backups
	unset fn_upload
	unset fn_unmount_storage
	unset fn_do_report
	unset fn_makefake
	unset fn_print
	unset fn_backup
	unset ez_decode
	unset fn_mode
	unset fn_check_config
	unset fn_test_files
	unset fn_remove_test_files
	unset main
	# delete global-vars
	unset _MODE _PROGFASE _CNT_PRINT _LOG_MSG _ERROR
	unset _LS_BALLS _LS_CRYPTS
	IFS="${_SAVE_IFS}"
	return ${_result}
}
trap on_finally EXIT

## [1] Mount backup-storage
## 1:device 2:mount path
function fn_mount_storage() {
	local _dev="$1"
	local _mpath="$2"
	if [[ -z ${_dev} ]];then
		fn_print ${_AE_ERROR}'mount: device undefine (config: _DEV_STORAGE)'
		return 1
	fi
	if [[ ! -e ${_dev} ]];then
		fn_print 'device not found: '${_AE_INFO}${_dev}
		return 1
	fi
	if [[ -z ${_mpath} ]];then
		# user
		mount ${_dev}
		if [[ $? -eq 0 ]];then
			fn_print 'mounted device: '${_AE_INFO}${_dev}
		fi
	else
		# s.user
		if ! mountpoint -q ${_mpath};then
			mount ${_DEV_ARGS} ${_dev} ${_mpath}
			if [[ $? -eq 0 ]];then
				fn_print 'mounted device: '${_AE_INFO}${_dev}
			else
				fn_print 'canot mount device: '${_AE_ERROR}${_dev}
				return 1
			fi
		fi
	fi
	return 0
}
## 1:device 2:avail.size 3:storage-dir
function fn_check_available() {
	local _dev="$1"
	local _size="$2"
	local _dir="$3"
	local _available=0
	[[ -z "${_dev}" || ! -e "${_dev}" ]] && {
		fn_print ${_AE_INFO}'device check canceled'
		return 0
	}
	if [[ -b "${_dev}" ]];then
		_available=$(df --sync -PB1 ${_dev} | grep -v ^Filesystem | awk '{sum += $4} END { print sum }')
		if [[ ${_available:-0} -lt $((${_size}*1024*1024)) ]];then
			fn_print ${_AE_ERROR}'not enough disk space'
			return 1
		fi
	fi
	fn_print "device available: ${_AE_INFO}${_dev} ($(numfmt --to=iec ${_available}))"

	if [[ -d "${_dir}" && -w "${_dir}" ]];then
		fn_print 'backup-storage: '${_AE_INFO}${_dir}
	else
		fn_print 'canot use backup-storage: '${_AE_INFO}${_dir}
		return 1
	fi
	return 0
}

## [2] Build balls
## 1:type r:var
function fn_excludes() {
	local _type="$1"
	local _excludes=''
	if [[ ${#_EXCLUDES[@]} -gt 0 ]];then
		if [[ "${_type:-tar}" = 'tar' ]];then
			_excludes=$(printf -- '--exclude "%s" ' ${_EXCLUDES[@]})
		else
			_excludes='-x '
			_excludes=${_excludes}$(printf '"%s" ' ${_EXCLUDES[@]})
		fi
	fi
	echo ${_excludes}
}

## 1:targets(ref)
## 2:type
function fn_build_balls() {
	local _ref="$1"
	local _type="$2"
	declare -n _targets=${_ref}
	local _excludes=$(fn_excludes ${_type})
	local _file
	local _dir
	local _output
	local _size
	local _X
	# builds
	for _X in "${_targets[@]}";do
		[[ -z ${_X%/} || ${_X%/} == '.' || ${_X%/} == ${_DIR_STORAGE_BACKUPS%/} ]] && continue
		if [[ -e "${_X}" && -r "${_X}" ]];then
			# dir.
			_dir=$(realpath ${_X} | xargs dirname)
			_file=$(basename ${_X})
			_output=${_DIR_STORAGE_BACKUPS%/}/
			_output=${_output}"${_BALL_PREFIX}${_file//./_}_${_TIMESTAMP}"
			if [[ "${_type:-tar}" = 'tar' ]];then
				_output=${_output}${_TAR_EXT}
				tar -C "${_dir}" ${_excludes} ${_TAR_ARGS} - \
					"$(basename ${_X})" | \
					gzip ${_GZIP_ARGS} > "${_output}"
			else
				_output=${_output}'.zip'
				zip ${_ZIP_ARGS} "${_output}" ${_X} ${_excludes}
			fi
			if [[ $? -eq 0 ]];then
				[[ -n "${_FILE_PERMIT}" ]] && chmod ${_FILE_PERMIT} ${_output}
				[[ -n "${_FILE_OWNER}" ]] && chown ${_FILE_OWNER} ${_output}
				_LS_BALLS+=(${_output})
				_size=$(stat -c "%s" "${_output}")
				fn_print "balled: ${_AE_INFO}$(basename ${_output}) ($(numfmt --to=iec ${_size}))"
			fi
		else
			fn_print "not found : ${_AE_ERRORMSG}${_X}"
		fi
	done
	return 0
}

## [3] to Encrypt
## 1:files(ref)
function fn_to_encrypt() {
	local _ref="$1"
	declare -n _files=${_ref}
	local _output
	local _size
	local _X
	for _X in "${_files[@]}"; do
		if [[ -f "${_X}" ]]; then
			_output=${_DIR_STORAGE_BACKUPS%/}/
			if [[ "${_BALL_TYPE:-tar}" = 'tar' ]]; then
				_output=${_output}"$(basename ${_X} ${_TAR_EXT})${_ENCRY_EXT}"
			else
				_output=${_output}"$(basename ${_X} '.zip')${_ENCRY_EXT}"
			fi
			openssl enc ${_ENCRY_ARGS} -in "${_X}" -out "${_output}"
			if [[ $? -eq 0 ]]; then
				[[ -n "${_FILE_PERMIT}" ]] && chmod ${_FILE_PERMIT} ${_output}
				[[ -n "${_FILE_OWNER}" ]] && chown ${_FILE_OWNER} ${_output}
				_LS_CRYPTS+=(${_output})
				_size=$(stat -c "%s" "${_output}")
				fn_print "encrypted: ${_AE_INFO}$(basename ${_output}) ($(numfmt --to=iec ${_size}))"
			fi
		fi
	done
	return 0
}

## [4] Remove balls(files)
## 1:files(ref)
function fn_remove_balls() {
	local _ref="$1"
	declare -n _files=${_ref}
	local _X
	for _X in ${_files[@]};do
		if [[ -f "${_X}" ]];then
			if rm -f ${_X};then
				:
			fi
		fi
	done
	fn_print 'removed balls'
	return 0
}

## [5] Remove older-backups
# 1:dir-path
function fn_remove_older_backups() {
	local _dir="$1"
	local _output
	[[ -e ${_dir} && -w ${_dir} ]] || {
		fn_print ${_AE_ERROR}'not found backup-storage'
		return 1
	}
	if ${_ENCRY_FLAG};then
		_output="${_BALL_PREFIX}*${_ENCRY_EXT}"
	else
		_output="${_BALL_PREFIX}*${_TAR_EXT}"
	fi
	find ${_dir} -maxdepth 1 -type f -name "${_output}" -mtime ${_RM_MTIME} -delete
	fn_print "removed older backups: ${_AE_INFO}${_output} (${_RM_MTIME} days)"
	return 0
}

## [6] Upload other-hosts
## 1:type 2:files(ref)
function fn_upload() {
	local _type="$1"
	local _ref="$2"
	declare -n _files=${_ref}
	local _X
	local _attach
	local _errcnt=0
	fn_print "upload: ${_AE_INFO}${_type} (${#_files[@]} files)"
	case ${_type} in
		scp)
			scp ${_SCP_ARGS} "${_files[@]}" "${_SCP_DEST}"
			[[ $? -ne 0 ]] && {((_errcnt++));fn_print 'error';};;
		samba)
			for _X in ${_files[@]};do
				smbclient ${_SMB_ARGS} -c "put ${_X} $(basename ${_X})"
				[[ $? -ne 0 ]] && {((_errcnt++));fn_print 'error: '${_X};}
			done;;
		http)
			for _X in ${_files[@]};do
				curl -o /dev/null ${_HTTP_ARGS} -F "file=@${_X};type=application/octet-stream"
				[[ $? -ne 0 ]] && {((_errcnt++));fn_print 'error: '${_X};}
			done;;
		ftp)
			for _X in ${_files[@]};do
				curl -T "${_X}" ${_FTP_ARGS}
				[[ $? -ne 0 ]] && {((_errcnt++));fn_print 'error: '${_X};}
			done;;
		sftp)
			for _X in ${_files[@]};do
				echo 'put ${_X}' | sftp ${_SFTP_ARGS}
				[[ $? -ne 0 ]] && {((_errcnt++));fn_print 'error: '${_X};}
			done;;
		rsync)
			rsync ${_RSYNC_ARGS} "${DIR_STORAGE_BACKUPS%/}/" ${_RSYNC_DEST}
			[[ $? -ne 0 ]] && {((_errcnt++));fn_print 'error';};;
		mail)
			_attach='';for _X in ${_files[@]};do _attach+="-A ${_X} ";done
			echo -e "${_PROGNAME}" | mail ${_attach} -s "${_PROGNAME}:upload" ${_UPLOAD_MAILADR}
			[[ $? -ne 0 ]] && {((_errcnt++));fn_print 'error';};;
		user)
			fn_ex_upload ${_ref}
			[[ $? -ne 0 ]] && {((_errcnt++));fn_print 'error';};;
		*)
			return 0;;
	esac
	fn_print "upload: ${_AE_INFO}(error: ${_errcnt} / ${#_files[@]})"
	return 0
}

## [7] Unmount backup-storage
## 1:device 2:path
function fn_unmount_storage() {
	local _dev="$1"
	local _mpath="$2"
	if [[ -z ${_dev} || ! -e ${_dev} ]];then
		return 1
	fi
	sync
	if [[ -n ${_mpath} ]];then
		if mountpoint -q "${_mpath}"; then
			# s.user
			hdparm -fF ${_dev}
			umount ${_dev}
		fi
	else
		# user
		umount ${_dev}
	fi
	[[ $? -eq 0 ]] && \
		fn_print 'unmounted device' || \
		fn_print 'error unmount'
	return 0
}
## [8] Report
## 1:types 2:exit-code
function fn_do_report() {
	local _ref="$1"
	local _result="$2"
	declare -n _types=${_ref}
	local _X
	[[ ${#_types[@]} -le 0 ]] && return 0
	for _X in "${_types[@]}";do
		case ${_X} in
			chat)
				wall "${_REPORT_CHAT}";;
			log)
				logger ${_REPORT_LOGARG};;
			mail)
				echo -e "${_REPORT_MAIL}\nlog:\n${_LOG_MSG}" | mail -s "${_PROGNAME}:report" ${_REPORT_MAILADR};;
			http)
				curl -s ${_REPORT_HTTP} -o /dev/null;;
			user)
				fn_ex_report ${_result};;
			*)
				:;;
		esac
	done
	fn_print 'reported: '${_AE_INFO}"${_types[*]}"
	return 0
}

## build fake-file
## 1:list(ref) 2:size
function fn_makefake() {
	local _ref="$1"
	declare -n _list=${_ref}
	local _size=$(($2 * 1024))
	local _output
	local _X
	for _X in ${_list[@]};do
		_output=${_DIR_STORAGE_BACKUPS%/}/
		_output=${_output}"${_BALL_PREFIX}${_X}${_TIMESTAMP}${_ENCRY_EXT}"
		# random binary
		dd if=/dev/urandom of=${_output} bs=$((RANDOM % (${_size} / 13) + ${_size})) count=1 2>/dev/null
	done
	fn_print 'maked fake-files'
	return 0
}

## verbose
## 1:text
function fn_print() {
	local _text="$1"
	local _output
	_output=$(printf "${_AE_NO}|%2d:${_AE_DEF} ${_text}${_AE_DEF}\n" ${_CNT_PRINT})
	_LOG_MSG+=$(echo -n "$_output" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")"\n"
	((_CNT_PRINT++))
	[[ ${_MODE} == *"v"* ]] || return 0
	echo -e ${_output}
	return 0
}

## backup
## 1:target(ref)
function fn_backup() {
	local _ref="$1"
	declare -n _targets=${_ref}
	local _size=0
	local _X
	${_SECURE} || {
		fn_print "${_PROGNAME}"
		fn_print "host: ${_AE_INFO}$(uname -oprn)"
		fn_print "os: ${_AE_INFO}$(lsb_release -d | cut -c 14-) ($(lsb_release -c | cut -c 11-))"
		fn_print "mem.free: ${_AE_INFO}$(free -h | awk -e '/^Mem:/ { print $4}')"
		fn_print "swap.used: ${_AE_INFO}$(free -h | awk -e '/^Swap:/ { print $3}')"
		fn_print "uptime: ${_AE_INFO}$(uptime -p)"
		fn_print ${_AE_LINE}${_LINE}
	}
	fn_print "$(date +'%Y/%m/%d %H:%M:%S')"

	# init
	_PROGFASE='mount'
	if ${_DEV_MOUNT_F};then
		fn_mount_storage "${_DEV_STORAGE}" "${_DEV_MNT_PATH}" || return 1
	fi
	_PROGFASE='available'
	fn_check_available "${_DEV_STORAGE}" ${_DEV_MIN} ${_DIR_STORAGE_BACKUPS} || return 1
	[[ ${_MODE} != *"g"* ]] && {
		fn_remove_older_backups ${_DIR_STORAGE_BACKUPS} || return 1
	}

	# build
	_PROGFASE='build'
	fn_print "backup targets : ${_AE_INFO}${_targets[*]}"
	fn_build_balls $_ref ${_BALL_TYPE}
	fn_ex_build_balls
	[[ "${_MODE}" = *"b"* ]] && return 0
	[ ${#_LS_BALLS[@]} -le 0 ] && {
		 fn_print ${_AE_WARN}'no targets'
		 return 1
	}
	if ${_ENCRY_FLAG};then
		fn_to_encrypt '_LS_BALLS'
		fn_remove_balls '_LS_BALLS'
	else
		_LS_CRYPTS=${_LS_BALLS}
	fi

	# totalsize
	for _X in ${_LS_CRYPTS[@]};do
		((_size=_size+$(stat -c "%s" "${_X}")))
	done
	fn_print "total size: ${_AE_INFO}${#_LS_CRYPTS[@]} files ($(numfmt --to=iec ${_size}))"
	if ${_ENCRY_FLAG};then
		fn_print 'backup files: '${_AE_INFO}$(ls -1 ${_DIR_STORAGE_BACKUPS%/}/*${_ENCRY_EXT} | wc -l)
	else
		fn_print 'backup files: '${_AE_INFO}$(ls -1 ${_DIR_STORAGE_BACKUPS%/}/* | wc -l)
	fi

	[[ "${_MODE}" = *"c"* ]] && return 0

	# upload
	if ${_UPLOAD_FLAG};then
		_PROGFASE='upload'
		fn_upload "${_UPLOAD_TYPE}" '_LS_CRYPTS'
		${_UPLOAD_DELETE_ORG_F} && fn_remove_balls '_LS_CRYPTS'
	fi
	_PROGFASE='fakefile'
	[[ "${_MODE}" = *"f"* ]] && fn_makefake '_FAKEFILE_LIST' ${_FAKEFILE_SIZE}

	fn_print 'successed'
	return 0
}

## ez-decode
## 1:target(ref)
function fn_ez_decode() {
	local _ref="$1"
	declare -n _files=${_ref}
	local _X
	local _out
	fn_print 'store dir: '${_AE_INFO}${_EZ_OUTDIR}
	_out=$(mktemp)
	for _X in "${_files[@]}";do
		if openssl enc -d ${_ENCRY_ARGS} -in ${_X} -out ${_out} -pass pass:${_ENCRY_PW};then
			if mkdir -p ${_CURDIR}/${_EZ_OUTDIR};then
				if tar -xf ${_out} -C ${_CURDIR}/${_EZ_OUTDIR};then
					rm -f ${_out}
					fn_print 'decoded: '${_AE_INFO}${_X}
				fi
			fi
		fi
	done
	return 0
}

## change mode
## 1:mode
function fn_mode() {
	local _mode="$1"
	_PROGFASE="$1"
	fn_print "mode: ${_AE_MODE} ${_PROGFASE} "
	fn_print "${_AE_LINE}${_LINE}"
	return 0
}

## check config
function fn_check_config() {
	local _msg=()
	local _X
	[[ -n ${_DEV_STORAGE} && ! -e ${_DEV_STORAGE} ]] && \
		_msg+=("\"_DEV_STORAGE\": not exist device (${_DEV_STORAGE})")
	if ${_DEV_MOUNT_F};then
		[[ -n ${_DEV_MNT_PATH} ]] && \
			_msg+=("\"_DEV_MNT_PATH\": not found (${_DEV_MNT_PATH})")
	fi
	[[ ! -e ${_DIR_STORAGE_BACKUPS} ]] && \
		_msg+=("\"_DIR_STORAGE_BACKUPS\": not found storage (${_DIR_STORAGE_BACKUPS})")
	[[ ${#_DIR_TARGETS[@]} -le 0 ]] && \
		_msg+=('"_DIR_TARGETS": none backup targets')

	if ${_UPLOAD_FLAG};then
		case ${_UPLOAD_TYPE} in
			'samba')
				type sambclient > /dev/null;;
			'http' | 'ftp')
				type curl > /dev/null;;
			'sftp')
				type sftp > /dev/null;;
			'mail')
				type mail > /dev/null;;
		esac
		[[ $? -eq 1 ]] && _msg+=('"_UPLOAD_TYPE": not installed, '${_UPLOAD_TYPE})
	fi

	for _X in ${_REPORT_ACTS[@]};do
		case ${_X} in
			'chat')
				type wall > /dev/null 2>&1;;
			'log')
				type logger > /dev/null 2>&1;;
			'mail')
				type mail > /dev/null 2>&1;;
			'http')
				type curl > /dev/null 2>&1;;
		esac
		[[ $? -eq 1 ]] && _msg+=('"_REPORT_ACTS": not installed, '"${_X}")
	done

	# message
	[[ ${#_msg[@]} -eq 0 ]] && return 0
	echo -e "${_AE_TITLE2}check config:${_AE_DEF}"
	echo -e ${_AE_LINE}${_LINE}
	IFS=$'\n'
	for _X in ${_msg[@]};do
		echo -e "${_AE_LIST}config: ${_AE_CONFIG}${_X}${_AE_DEF}"
	done
	IFS="${_SAVE_IFS}"
	return 1
}

## test files
function fn_test_files() {
	local _yesno
	local _dir='./_bktest'
	fn_print ${_AE_INPUT}'動作テスト用のファイルを作成しますか？'
	fn_print ${_AE_INPUT}"カレント(${_CURDIR})に、${_dir}(1MiB/3files) を生成"
	read -r -p '(y/n): ' _yesno
	[[ -z ${_yesno} || ${_yesno} != 'y' ]] && return 0
	# make
	[[ ! -e ${_dir} ]] && mkdir -m 0700 ${_dir}
	dd if=/dev/zero of=${_dir}/test1.bin bs=1M count=1 2>/dev/null
	dd if=/dev/zero of=${_dir}/test2.bin bs=1M count=1 2>/dev/null
	dd if=/dev/zero of=${_dir}/test3.bin bs=1M count=1 2>/dev/null
	chmod -f 0600 ${_dir}/test{1,2,3}.bin
	ls -lhQv ${_dir}
	fn_print 'generated: '${_AE_INFO}${_dir}
	fn_print ${_AE_STRONG}'"_DIR_TARGETS" を '${_dir}' に設定して試用ください'
	fn_print ${_AE_STRONG}'これら、--remove-test-file で、まとめて削除できます'
}

## remove test files
function fn_remove_test_files() {
	local _yesno
	local _dir='./_bktest'
	[[ ! -e ${_dir} ]] && {
		fn_print ${_AE_ERROR}'not found test-files'
		return 0
	}
	fn_print ${_AE_INPUT}'動作テスト用のファイルを削除しますか？'
	fn_print ${_AE_INPUT}"カレント(${_CURDIR})の、${_dir} (in 1MiB/3files) を削除"
	read -r -p '(y/n): ' _yesno
	[[ -z ${_yesno} || ${_yesno} != 'y' ]] && return 0
	# remove
	rm -rf ${_dir} && fn_print 'removed: '${_AE_INFO}${_dir}
}

## main:backup my docs.
function main() {
	_PROGFASE='main'
	local _tmp;
	local _X;
	# check config
	fn_check_config || {
		echo -e ${_AE_ERROR}'config error / 上記、設定を確認してください'${_AE_DEF};return 1
	}

	# mode:ez-decode
	_tmp=0
	for _X in $@; do
		[[ -e ${_X} && -r ${_X} && ${_X} =~ ^.+${_ENCRY_EXT}$ ]] && ((_tmp++)) || break;
	done
	if [[ $# > 0 && $# -eq ${_tmp} ]]; then
		_MODE+='v'
		fn_mode 'ez-decode'
		_tmp=$@
		fn_ez_decode '_tmp';return $?
	fi

	# mode:quick-backup
	_tmp=0
	for _X in $@; do
		[[ -e ${_X} && -r ${_X} && -d ${_X} ]] && ((_tmp++)) || break;
	done
	if [[ $# > 0 && $# -eq ${_tmp} ]]; then
		_MODE+='vM'
		fn_mode 'quick-backup'
		_tmp=$@
		fn_backup '_tmp';return $?
	fi

	# backup options
	_PROGFASE='options'
	while [[ $# -gt 0 ]]; do
		case "$1" in
			# options
			-v|--verbose)
				_MODE+='v';;
			-b|--ball)
				_MODE+='b';;
			-e|--encrypt)
				_MODE+='c';;
			-g|--organize)
				_MODE+='g';;
			-f|--fake)
				_MODE+='f';;
			# modes
			no|none|pass|null|nurupo|hoge*|fuga*)
				return 0;;
			-h|-?|--?|--help|help|man|info|usage|--ver|--version)
				fn_usage;return 0;;
			--test-mount)
				_MODE+='v';
				fn_mode 'test mount'
				fn_mount_storage "${_DEV_STORAGE}" ${_DIR_STORAGE_BACKUPS};return 0;;
			--test-available)
				_MODE+='v';
				fn_mode 'test available'
				fn_check_available "${_DEV_STORAGE}" ${_DEV_MIN} ${_DIR_STORAGE_BACKUPS};return 0;;
			--test-upload)
				_MODE+='v';
				fn_mode 'test upload'
				_tmp=();_tmp+=$(mktemp);fn_print 'maked test file: '${_AE_INFO}${_tmp}
				fn_upload "${_UPLOAD_TYPE}" '_tmp';
				fn_print ${_AE_WARN}'Check the [Config:Upload]'
				return 0;;
			--test-report)
				_MODE+='v';
				fn_mode 'test report'
				fn_do_report '_REPORT_ACTS' 0;return 0;;
			--test-file)
				_MODE+='v';
				fn_mode 'test files'
				fn_test_files;return 0;;
			--remove-test-file)
				_MODE+='v';
				fn_mode 'remove test files'
				fn_remove_test_files;return 0;;
			sl|ls)
				sl -alFe;return 0;;
			--fuck|*fuck*|aa)
				_tmp=('~~' 'www' '.w,.' '.v' '"' '💩' '＿__' '*' '...' 'Ω' 'ω' '井' '^~' '(*´ｪ`*)' '(^ω^)' '(:3 )<' '(¦3[ ]=' '( ･ω･)y-~' '(´Д`)' '(´;ω;`)' '(´∀｀)' '(*･ω･)b' '< ;`Д´>' '(#`д´#)' "(o'д'o)")
				for _X in {1..1024};do echo -en ${_AE_JOKE}${_tmp[$((RANDOM % ${#_tmp[@]}))]}'        '${_AE_DEF};done;tput cup 0 0;return 0;;
			--poop|*poop*|*shit*|*ass*|*unko*|*unti*|*kuso*)
				set $(cat /proc/uptime);_tmp=$(($(printf "%.0f" $1) % 100))
				clear;_X=$(($(tput lines)*3+1));while [[ ${_X} -gt 0 ]];do
				tput cup $((RANDOM % $(tput lines))) $((RANDOM % $(tput cols)))
				[[ ${_X} -eq ${_tmp} ]] && echo -en '\U1F4B0' || echo -en '\U1F4A9'
				((_X--));done;tput cup 0 0;return 0;;
			--color|color|colors|ansi)
				clear;echo -e ${_AE_DEF}'ANSI basic 8 color codes(fore/back)'
				for _X in {30..37};do printf "\e[${_X}m  %3d  " $_X;done;echo -e ${_AE_DEF}
				for _X in {40..47};do printf "\e[${_X}m  %3d  " $_X;done;echo -e "${_AE_DEF}\n\nblight 8 color codes(fore/back)"
				for _X in {90..97};do printf "\e[${_X}m  %3d  " $_X;done;echo -e ${_AE_DEF}
				for _X in {100..107};do printf "\e[${_X}m  %3d  " $_X;done
				echo -e "${_AE_DEF}\n\n256 color codes(base:0-15,16-231,gray:232-255)\nfore: [esc]e[38;5;(code)m  back: [esc]e[48;5;(code)m"
				for _X in {0..255};do printf "\e[48;5;${_X}m  %3d  " $_X;[ $((${_X} % 8)) -eq 7 ] && echo -e ${_AE_DEF};done
				return 0;;
			*)
				IFS=$'\n';echo -e "unknown option: ${_AE_INFO}$1${_AE_DEF}";fn_build_usage '_USAGE_OPT';return 1;;
		esac
		shift
	done
	# normal backup job
	_MODE+='M';
	fn_backup '_DIR_TARGETS'
}
[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@";exit $?