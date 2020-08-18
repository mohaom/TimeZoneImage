echo "Start Plink with Node $env:nodeIP"
$filePath = 'script.bat'
$tempFilePath = "$env:TEMP\$($filePath | Split-Path -Leaf)"
$find = '#TimeZone#'
$replace = $env:timezone

(Get-Content -Path $filePath) -replace $find, $replace | Add-Content -Path $tempFilePath

Remove-Item -Path $filePath
Move-Item -Path $tempFilePath -Destination $filePath

echo y | c:\\plink.exe $env:nodeIP -l $env:user -pw $env:pwd -m script.bat
Echo "Done Plink"
