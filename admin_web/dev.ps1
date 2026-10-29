$env:Path = "C:\Program Files\nodejs;$env:LOCALAPPDATA\Programs\nodejs;$env:Path"
Set-Location -Path $PSScriptRoot
Write-Host "🚀 Menjalankan DPOS Admin Web dev server di http://localhost:3000 ..." -ForegroundColor Cyan
cmd.exe /c npm run dev

