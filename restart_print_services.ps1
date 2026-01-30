Get-Service | Where-Object { $_.Name -match "print" -or $_.DisplayName -match "print" } | Restart-Service -Force
