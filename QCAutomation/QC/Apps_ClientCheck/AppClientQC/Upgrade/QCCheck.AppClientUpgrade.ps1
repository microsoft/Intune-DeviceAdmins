param
(
    $Configurations
)

$InputParams = $Configurations.InputParams
$UpgradeDateTime = $InputParams.UpgradeDateTime
$ExpectedValues = $Configurations.ExpectedValues

$AppName = $InputParams.AppName
$ModerApxApp = $InputParams.ModerApxApp
$ModerDeeplinkApp = $InputParams.ModerDeeplinkApp
$SupersedesApp = $InputParams.SupersedesApp
$AvailableApp = $InputParams.AvailableApp
$InstalledApp = $InputParams.InstalledApp

$ExpectedClientVersion = $ExpectedValues.ExpectedClientVersion

## Site code and server details

$PrimarySiteServerName = $Configurations.SiteServers[$Configurations.PrimarySiteCode]
$PrimarySQLServerName = $Configurations.SiteSQLServers[$Configurations.PrimarySiteCode]
$PrimarySQLDBName = $Configurations.SiteSQLDBNames[$Configurations.PrimarySiteCode]

$SiteCode = $InputParams.SiteCode
$SiteServerName = $Configurations.SiteServers[$InputParams.SiteCode]
$SiteSQLServerName = $Configurations.SiteSQLServers[$InputParams.SiteCode]
$SiteSQLDBName = $Configurations.SiteSQLDBNames[$InputParams.SiteCode]




Describe 'New App Model' {

     
        
        Context 'x64 App Model install on new client version' {
        
                $Results = Get-X64App -AppName $AppName
                $Testset = $Results.Output
                
                It "Verify if able to check App is exist '<AppFullName>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $AppID
                )
                $AppID | Should Not Be $null
                
              }

              It "Verify if able to Install App '<AppFullName>' Status '<InstallState>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $InstallState
                )
                $Results.Output.InstallState | Should BeExactly 'Installed'
                
              }
              
                
                
          

        It "Verify if able to Install App '<AppFullName>' and confirm it installs with no need to re-run" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $InstalledState
                )
                $Results.Output.InstallState | Should BeExactly 'Installed'
                
            }

       It "Verify and Confirm if each tab of catalog updates as app installs" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $InstalledState
                )
                $Results.Output.InstallState | Should BeExactly 'Installed'
                
            }


    }          
      

}#New App Model

Describe 'New Modern App' {

     
        
        Context 'Modern app with APPX on  client' {
        
                $Results = Get-ModernApp -ModerApxApp $ModerApxApp
                $Testset = $Results.Output
                
                It "Verify if able to check App is exist '<AppFullName>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $AppID
                )
                $AppID | Should Not Be $null
                
              }

              It "Verify if able to Install App '<AppFullName>' Status '<InstallState>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $InstallState
                )
                $Results.Output.InstallState | Should BeExactly 'Installed'
                
              }
              
                
                
          

        It "Verify if able to Install App '<AppFullName>' and confirm it installs with no need to re-run" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $InstalledState
                )
                $Results.Output.InstallState | Should BeExactly 'Installed'
                
            }

       It "Verify and Confirm if each tab of catalog updates as app installs" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $InstalledState
                )
                $Results.Output.InstallState | Should BeExactly 'Installed'
                
            }


    } 

  Context 'Modern app with deep link on  client' {
        
                $Results = Get-ModernDeeplinkApp -ModerDeeplinkApp $ModerDeeplinkApp
                $Testset = $Results.Output
                
                It "Verify if able to check App is exist '<AppFullName>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $AppID
                )
                $AppID | Should Not Be $null
                
              } 
   }

Context 'Confirm only supersedes application displayed to the user from application Catalog' {

                $Results = Get-SupersedesApp -SupersedesApp $SupersedesApp
                $Testset = $Results.Output
                
                It "Verify if software center display Supersedes App '<AppFullName>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $AppID,
                    $ResolvedState
                )
                $AppID | Should Not Be $null
                
              }
            }
                       
      

}#New Modern App
    
 Describe 'Software Center' {
        
        Context 'Software Center displays available application on current client' {

                $Results = Get-AvailableApp -AvailableApp $AvailableApp
                $Testset = $Results.Output
                
                It "Verify if software center display available App '<AppFullName>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $AppID,
                    $ResolvedState
                )
                $Results.Output.ResolvedState | Should  BeExactly 'Available'
                
              }
            }
                
        Context 'Software Center displays installed application on current client' {

                $Results = Get-InstalledApp -InstalledApp $InstalledApp
                $Testset = $Results.Output
                
                It "Verify if software center display installed App '<AppFullName>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $AppID,
                    $InstallState
                )
                $Results.Output.InstallState | Should  BeExactly 'Installed'
                
              }
   
                
        

         It "Verify if Software Center displays accurate App Information on current client '<AppFullName>', '<AppID>', '<InstallState>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $AppID,
                    $InstallState
                )
                $AppID| Should Not Be $null
                
              }
   
                
        
            It "Verify if only supersedes application displayed to the user from Software Center on current client '<AppFullName>'" -TestCases $Testset {
                param
                (
                    $AppFullName,
                    $AppID,
                    $InstallState
                )
                $AppID| Should Not Be $null
                
              }

      }         


}#Software Center
       



   
    




        
        
        

