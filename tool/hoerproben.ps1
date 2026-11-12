# Erzeugt Hörproben der japanischen Frauenstimmen, damit Leoni ihre Stimme wählen kann.
#
# Aufruf:  powershell -ExecutionPolicy Bypass -File tool\hoerproben.ps1
# Schlüssel: werkstatt\azure-aufbau.env (AZURE_SPEECH_KEY, AZURE_SPEECH_REGION)
# Ausgabe:  werkstatt\hoerproben\<stimme>.mp3 (wird nicht veröffentlicht)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root 'werkstatt\azure-aufbau.env'
if (-not (Test-Path $envFile)) { throw "Schlüsseldatei fehlt: $envFile" }

$cfg = @{}
foreach ($line in Get-Content $envFile -Encoding UTF8) {
  if ($line -match '^\s*([A-Z_]+)\s*=\s*(.*)\s*$') { $cfg[$Matches[1]] = $Matches[2] }
}
$key = $cfg['AZURE_SPEECH_KEY']
$region = $cfg['AZURE_SPEECH_REGION']
if (-not $key -or -not $region) { throw 'AZURE_SPEECH_KEY oder AZURE_SPEECH_REGION fehlt.' }

# Ein kurzer Text auf etwa N4-Niveau zum Thema Tee.
$text = 'おはようございます。今日は、日本のお茶について話します。静岡は、お茶の産地として有名です。' +
        '春になると、新しい葉をつんで、新茶を作ります。新茶は香りがよくて、少しあまい味がします。'

$voices = @(
  'ja-JP-NanamiNeural',
  'ja-JP-MayuNeural',
  'ja-JP-ShioriNeural',
  'ja-JP-AoiNeural',
  'ja-JP-Nanami:DragonHDLatestNeural'
)

$outDir = Join-Path $root 'werkstatt\hoerproben'
New-Item -ItemType Directory -Force $outDir | Out-Null
$url = "https://$region.tts.speech.microsoft.com/cognitiveservices/v1"
$headers = @{
  'Ocp-Apim-Subscription-Key' = $key
  'X-Microsoft-OutputFormat'  = 'audio-24khz-48kbitrate-mono-mp3'
  'User-Agent'                = 'yomicha-hoerproben'
}

$billed = 0
foreach ($voice in $voices) {
  $ssml = "<speak version='1.0' xml:lang='ja-JP' xmlns='http://www.w3.org/2001/10/synthesis'>" +
          "<voice name='$voice'>$text</voice></speak>"
  $file = Join-Path $outDir (($voice -replace '[:]', '-') + '.mp3')
  try {
    Invoke-WebRequest -Method Post -Uri $url -Headers $headers -ContentType 'application/ssml+xml; charset=utf-8' `
      -Body ([System.Text.Encoding]::UTF8.GetBytes($ssml)) -OutFile $file -UseBasicParsing
    $billed += $text.Length * 2
    "OK      $voice -> $file"
  } catch {
    "FEHLER  $voice : $($_.Exception.Message)"
  }
}
"Ungefähr abgerechnete Zeichen: $billed (japanische Zeichen zählen bei Azure teilweise doppelt)"
