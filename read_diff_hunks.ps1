$lines = Get-Content "mq4_diff_since_v10051.txt"
$hunks = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^@@') {
        $hunks += [PSCustomObject]@{
            LineNum = $i + 1
            Header = $lines[$i]
            Context = ($lines[($i+1)..([Math]::Min($i+8, $lines.Count-1))] -join "`n")
        }
    }
}
Write-Host "Total hunks: $($hunks.Count)"
$hunks | ForEach-Object {
    Write-Host "--- $($_.Header) ---"
    Write-Host $_.Context
}
