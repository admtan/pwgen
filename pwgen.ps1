# パラメーター定義
param(
	[int]$len = 20, # 生成する文字列の長さ
	[switch]$num, # 数字のみを使用するかどうか
	[switch]$port, # エフェメラルポート番号を生成するかどうか
	[switch]$sym, # 記号を含むかどうか
	[switch]$date, # 時刻を生成するかどうか
	[switch]$uuid, # UUID を生成するかどうか
	[switch]$uupw, # UUID ベースのパスワードを生成するかどうか
	[switch]$tinyurl, # tinyurl 用の文字列を生成するかどうか
	[switch]$vgd, # v.gd 用の文字列を生成するかどうか
	[switch]$help # ヘルプメッセージを表示するかどうか
)

# 乱数生成の初期化
try {
	$random = New-Object -TypeName System.Security.Cryptography.RNGCryptoServiceProvider
} catch {
	Write-Error "乱数生成の初期化中にエラーが発生しました。エラー詳細: $_"
	exit 1
}

# ランダム文字列生成のための関数
function GenerateRandomString {
	param(
		[int]$length, # 生成する文字列の長さ
		[string]$characterSet # 使用する文字セット
	)

	# ランダム文字列を格納する配列を初期化
	$randomString = New-Object -TypeName char[] -ArgumentList $length

	for ($i = 0; $i -lt $length; $i++) {
		# ランダムバイトを生成
		$byteArray = New-Object -TypeName byte[] -ArgumentList 1
		$random.GetBytes($byteArray)
		# バイト値を文字セットの範囲にマッピング
		$index = $byteArray[0] % $characterSet.Length
		# 対応する文字をランダム文字列に追加
		$randomString[$i] = $characterSet[$index]
	}

	# 配列の要素を結合して文字列にして返却
	return -join $randomString
}

# ポート生成のための関数
function GenerateRandomPort {
	param(
		[int]$portMin, # 最小ポート番号
		[int]$portMax # 最大ポート番号
	)

	# ポート番号の範囲を計算
	$portRange = $portMax - $portMin + 1

	# ランダムなポート番号を生成
	$portBytes = New-Object -TypeName byte[] -ArgumentList 2
	$random.GetBytes($portBytes)
	$portNumber = [BitConverter]::ToUInt16($portBytes, 0) % $portRange + $portMin

	return $portNumber
}

# 日付生成のための関数
function GenerateRandomDate {
	param(
		[int]$daysInFuture = 14 # 未来の日付範囲 (既定値は 14 日間)
	)

	# 現在の日付を取得
	$currentDate = Get-Date
	# 0 から指定された日数の範囲でランダムな日数を生成
	$daysToAdd = Get-Random -Minimum 1 -Maximum $daysInFuture
	# 現在の日付にランダムな日数を加算
	$randomDate = $currentDate.AddDays($daysToAdd)
	# 日付文字列をフォーマットして返却 (時刻部分は除去)
	return $randomDate.ToString("yyyy-MM-dd")
}

# 時刻生成のための関数
function GenerateRandomTime {
	$timeBytes = New-Object -TypeName byte[] -ArgumentList 4
	$random.GetBytes($timeBytes)

	# 時を 0 から 23 の範囲で生成
	$hour = $timeBytes[0] % 24
	# 分を 0 から 59 の範囲で生成
	$minute = $timeBytes[1] % 60
	# 秒を 0 から 59 の範囲で生成
	$second = $timeBytes[2] % 60

	# 時刻文字列をフォーマットして返却
	return "{0:D2}:{1:D2}:{2:D2}" -f $hour, $minute, $second
}

# カスタム UUID 生成関数
function GenerateCustomUUID {
	$uuidBytes = New-Object -TypeName byte[] -ArgumentList 16
	$random.GetBytes($uuidBytes)
	$uuidString = New-Object -TypeName Guid -ArgumentList (,$uuidBytes)

	# UUID の特定部分をカスタマイズ
	$uuidChar = $uuidString.ToString()

	# Version 4 (ランダム)
	$uuidChar = $uuidChar.Remove(14, 1)
	$uuidChar = $uuidChar.Insert(14, "4").Substring(0, 36)

	# Variant 8, 9, a および b (ISO/IEC 11578:1996)
	$randomVariant = "89ab"
	$randomVariantBytes = New-Object -TypeName "System.Byte[]" 4
	$random.GetBytes($randomVariantBytes)
	$randomVariantInt = [BitConverter]::ToUInt32($randomVariantBytes, 0)
	$randomVariantChar = $randomVariant[$randomVariantInt % $randomVariant.Length]
	$uuidChar = $uuidChar.Remove(19, 1)
	$uuidChar = $uuidChar.Insert(19, $randomVariantChar).Substring(0, 36)

	# 自分で生成した UUID であることを識別するための文字列 (0-9, a-f で任意の 3 桁)
	$uuidChar = $uuidChar.Remove(24, 3)
	$uuidChar = $uuidChar.Insert(24, "ada").Substring(0, 36)

	return $uuidChar
}

# 文字セット定義
$alphabetCapital = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" # 大文字アルファベット
$alphabetSmall = "abcdefghijklmnopqrstuvwxyz" # 小文字アルファベット
$numbers = "0123456789" # 数字
$symbols = "!@#$%^&*()-=+`~[]{};\':,.<>?/|_" # 記号
$characters = $alphabetSmall + $alphabetCapital # 初期文字セットは大文字と小文字

# 数字のみ、または記号を含むかどうかの判定
if ($num) {
	$characters = $numbers
} else {
	$characters += $numbers
	if ($sym) {
		$characters += $symbols
	}
}

# パラメータ $len の検証
if ($len -le 0) {
	Write-Error "指定された長さ `'$len`' は無効です。長さは正の整数である必要があります。"
	exit 1
}

# ヘルプメッセージ
if ($help) {
	@"
【概要】
    パスワードやランダムな文字列を生成するスクリプトです。

【使用法】
    pwgen [-len <長さ>] [-sym] [-num] [-uuid] [-port] [-tinyurl] [-vgd] [-help]

【引数】
    -len <長さ>
        - パスワードの長さを指定します。既定値は 20 です。
    -num
        - 数字を使用する場合に指定します。
    -port
        - プライベートポート用にエフェメラルポート番号を生成する場合に指定します。(範囲 49152 - 65535)
    -sym
        - 記号を使用する場合に指定します。
    -date
        - ランダムな日付と時刻を生成する場合に指定します。
    -uuid
        - UUID を生成する場合に指定します。
    -uupw
        - UUID を元にした 16 進数のパスワードを生成します。長さは 32 文字固定です。
    -tinyurl
        - tinyurl.com 用にハイフンを含むランダムな文字列を生成する場合に指定します。
    -vgd
        - v.gd 用にアンダースコアを含むランダムな文字列を生成する場合に指定します。
    -help
        - ヘルプを表示します。

【例】
    pwgen
        - パスワードを生成します。
    pwgen -len 16
        - 16 文字のパスワードを生成します。
    pwgen -len 16 -sym
        - 記号を含む 16 文字のパスワードを生成します。
    pwgen -len 4 -num
        - 数字の 4 桁のランダムな文字列を生成します。
    pwgen -date
        - ランダムな日付と時刻を生成します。
    pwgen -port
        - エフェメラルポート番号を生成します。
    pwgen -uuid
        - UUID を生成します。
    pwgen -uupw
        - UUID を元にした 16 進数のパスワードを生成します。
    pwgen -tinyurl
        - tinyurl.com 用のランダムな文字列を生成します。
    pwgen -vgd
        - v.gd 用のランダムな文字列を生成します。
"@
	return
}

# 各オプションに応じた文字列の生成
if ($port) {
	$ephemeralPort = GenerateRandomPort -portMin 49152 -portMax 65535
	Write-Output $ephemeralPort
} elseif ($date) {
	$randomDate = GenerateRandomDate -daysInFuture 14
	$randomTime = GenerateRandomTime
	Write-Output "$randomDate $randomTime"
} elseif ($uuid -or $uupw) {
	$uuidString = GenerateCustomUUID
	if ($uupw) {
		$password = $uuidString -replace '-', ''
		Write-Output $password
	} else { Write-Output $uuidString }
} elseif ($tinyurl -or $vgd) {
	$separator = if ($tinyurl) { "-" } else { "_" }
	$sectionLengths = if ($tinyurl) { @(4, 10, 12) } else { @(4, 12, 14) }
	$url = for ($i = 0; $i -lt $sectionLengths.Length; $i++) {
		GenerateRandomString -length $sectionLengths[$i] -characterSet $alphabetSmall
	}
	$url = $url -join $separator
	Write-Output $url
} else {
	$password = GenerateRandomString -length $len -characterSet $characters
	Write-Output $password
}
