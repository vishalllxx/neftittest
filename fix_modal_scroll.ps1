$filePath = "src\pages\Burn.tsx"
$content = Get-Content $filePath -Raw
$content = $content.Replace('overflow-visible', 'max-h-[90vh] overflow-y-auto')
Set-Content $filePath -Value $content -NoNewline
Write-Host "✅ Fixed modal scrolling - replaced overflow-visible with max-h-[90vh] overflow-y-auto"
