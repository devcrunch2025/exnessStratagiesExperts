$filePath = "c:\Users\venuadmin\AppData\Roaming\MetaQuotes\Terminal\2191F4A3D14D7B4B1EBB84F924777883\MQL4\Experts\V-ScalpingBot-documentation.html"
$lines = Get-Content $filePath
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'V100(3[3-9]|4[0-9]|5[0-9])') {
        Write-Host "$($i+1): $($lines[$i].Trim())"
    }
}
