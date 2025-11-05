$file = "src\services\EnhancedHybridBurnService.ts"
$content = Get-Content $file -Raw

# Fix 1: Remove web3 = null during balance check chain switching (line 467-471)
$content = $content -replace "this\.currentChain = chainManager\.getCurrentChain\(\);[\r\n\s]+this\.web3 = null;[\r\n\s]+this\.nftContract = null;", "this.currentChain = chainManager.getCurrentChain();`n          this.nftContract = null;"

# Fix 2: Remove web3 = null when switching back to original chain (line 498-502)
$content = $content -replace "this\.currentChain = chainManager\.getCurrentChain\(\);[\r\n\s]+this\.web3 = null;[\r\n\s]+this\.nftContract = null;[\r\n\s]+await this\.initializeContracts", "this.currentChain = chainManager.getCurrentChain();`n          this.nftContract = null;`n          await this.initializeContracts"

Set-Content $file -Value $content -NoNewline
Write-Host "✅ Fixed web3 null bug by removing unnecessary web3 = null assignments during chain switching"
Write-Host "   This prevents 'Cannot read properties of null' errors during multi-chain balance checks"
