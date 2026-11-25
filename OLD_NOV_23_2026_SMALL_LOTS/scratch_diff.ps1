$diff = git diff 3dc63b8 HEAD --stat --patch-with-stat
$diff | Select-Object -First 200 | ForEach-Object { Write-Host $_ }
