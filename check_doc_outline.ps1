$filePath = "c:\Users\venuadmin\AppData\Roaming\MetaQuotes\Terminal\2191F4A3D14D7B4B1EBB84F924777883\MQL4\Experts\V-ScalpingBot-documentation.html"
$lines = Get-Content $filePath

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '<section id="([^"]+)"') {
        Write-Host "Line $($i+1): Section ID = $($matches[1])"
    } elseif ($line -match '<nav class="sidebar-nav">') {
        Write-Host "Line $($i+1): Sidebar Nav start"
    } elseif ($line -match 'class="version-tag"') {
        Write-Host "Line $($i+1): Version Tag: $($line.Trim())"
    }
}
