$filePath = "c:\Users\venuadmin\AppData\Roaming\MetaQuotes\Terminal\2191F4A3D14D7B4B1EBB84F924777883\MQL4\Experts\V-ScalpingBot-documentation.html"
$matches = Get-Content $filePath | Select-String -Pattern 'V100[0-9]{2}'
Write-Host "Total matches: $($matches.Count)"
$matches | Select-Object -Last 25 | ForEach-Object {
    "$($_.LineNumber): $($_.Line.Trim())"
}
