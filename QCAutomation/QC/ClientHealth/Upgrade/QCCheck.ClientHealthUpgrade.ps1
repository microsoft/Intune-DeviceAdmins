param
(
    $Configurations
)

$InputParams = $Configurations.InputParams
$UpgradeDateTime = $InputParams.UpgradeDateTime
$ExpectedValues = $Configurations.ExpectedValues

$ExpectedClientVersion = $ExpectedValues.ExpectedClientVersion

## Site code and server details
$PrimarySiteCode = $Configurations.PrimarySiteCode
$PrimarySiteServerName = $Configurations.SiteServers[$Configurations.PrimarySiteCode]
$PrimarySQLServerName = $Configurations.SiteSQLServers[$Configurations.PrimarySiteCode]
$PrimarySQLDBName = $Configurations.SiteSQLDBNames[$Configurations.PrimarySiteCode]

$SiteCode = $InputParams.SiteCode
$SiteServerName = $Configurations.SiteServers[$InputParams.SiteCode]
$SiteSQLServerName = $Configurations.SiteSQLServers[$InputParams.SiteCode]
$SiteSQLDBName = $Configurations.SiteSQLDBNames[$InputParams.SiteCode]

$SQLServerClientsCollection = $Configurations.SQLServerClientsCollection

Describe 'Client Health' {

     Context 'Client Version' {
             
                $ClientVersion = Get-ClientVersion -SiteSQLServerName $SiteSQLServerName -SiteSQLDBName $SiteSQLDBName -ExpectedClientVersion $ExpectedClientVersion -SQLServerClientsCollection $SQLServerClientsCollection
                $VersionResults = $ClientVersion.Output
                
                It "Verify if CM client Version is '<ExpectedClientVersion>'" -TestCases $ExpectedValues {
                param
                (
                    $ExpectedClientVersion,
                    $VersionResult
                )
                $VersionResults| Should Be $ExpectedClientVersion
                
              }
                
           }
        
        Context 'Most recent client Inventory' {
        
                $Results = InitiatePolicies
                $Testset = $Results.Output
                
                It "Initiate HardwareInventoryCycle Policy on '<HWResult>'" -TestCases $Testset {
                param
                (
                    $HWResult
                )
                $HWResult | Should Not Be $null
                
                 }
                It "Initiate DiscoveryDataCollection Cycle Policy on '<DiscoveryDataResult>'" -TestCases $Testset {
                param
                (
                    $DiscoveryDataResult
                )
                $DiscoveryDataResult | Should Not Be $null
                
                }
                It "Initiate MachinePolicyEvaluationCycle Policy on '<MachinePolicyResult>'" -TestCases $Testset {
                param
                (
                    $MachinePolicyResult
                )
                $MachinePolicyResult | Should Not Be $null
                
              }
                
                }
       

        Context 'Confirm site attached clients are sending Inventory' {
           
                           
                $Results = Get-LastHWScan -SiteSQLServerName $SiteSQLServerName -SiteSQLDBName $SiteSQLDBName
                $Testset = $Results.Output
                
                It "Verify if Client '<ComputerName>' sending inventory on '<HWResult>'" -TestCases $Testset {
                param
                (
                    $HWResult,
                    $ComputerName
                )
                $HWResult | Should Not Be $null
                
              }

             }

}#ClientHealth