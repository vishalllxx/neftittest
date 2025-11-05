$filePath = "src\services\EnhancedHybridBurnService.ts"
$content = Get-Content $filePath -Raw

# Add toast at start of checkBalanceOnAllChains
$content = $content.Replace(
  '  ): Promise<{ success: boolean; insufficientChains: string[] }> {
    console.log(`💰 Checking balance on all chains before burning...`);',
  '  ): Promise<{ success: boolean; insufficientChains: string[] }> {
    console.log(`💰 Checking balance on all chains before burning...`);
    toast.loading(`Checking gas balance on ${Object.keys(nftsByChain).length} chain(s)...`, { id: ''balance-check'' });'
)

# Add toast before returning success
$content = $content.Replace(
  '    return {
      success: insufficientChains.length === 0,
      insufficientChains
    };
  }',
  '    if (insufficientChains.length === 0) {
      toast.success(''✅ Balance verified on all chains!'', { id: ''balance-check'' });
    } else {
      toast.dismiss(''balance-check'');
    }
    
    return {
      success: insufficientChains.length === 0,
      insufficientChains
    };
  }'
)

Set-Content $filePath -Value $content -NoNewline
Write-Host "✅ Added balance check toast notifications"
