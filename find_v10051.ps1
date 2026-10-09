$filePath = "c:\Users\venuadmin\AppData\Roaming\MetaQuotes\Terminal\2191F4A3D14D7B4B1EBB84F924777883\MQL4\Experts\V-ScalpingBot-documentation.html"
$matches = Get-Content $filePath | Select-String -Pattern 'V10051'
foreach ($m in $matches) {
    Write-Host "$($m.LineNumber): $($m.Line.Trim())"
}
