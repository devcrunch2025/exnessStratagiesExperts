$diff = git diff 3dc63b8 HEAD -- V-ScalpingBot.mq4
$diff | Set-Content "mq4_diff_since_v10051.txt"
Write-Host "Wrote diff to mq4_diff_since_v10051.txt. Total lines: $($diff.Count)"
