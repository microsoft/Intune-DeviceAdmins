param
(
    $Configurations
)

$InputParams = $Configurations.InputParams
$ExpectedValues = $Configurations.ExpectedValues
$ExpectedLogScanFile = $ExpectedValues.ExpectedLogScanFile
$ExpectedErrorLogDeploymentFile = $ExpectedValues.ExpectedErrorLogDeploymentFile
$ExpectedErrorPattern = $ExpectedValues.ExpectedLogScanFile
$ExpectedScanStatus = $ExpectedValues.ExpectedScanStatus
$WindowsDefender = $ExpectedValues.WindowsDefender

$UpgradeDateTime = $InputParams.UpgradeDateTime
$ExpectedClientVersion = $ExpectedValues.ExpectedClientVersion


Describe 'Security & Compliance' {
        
        Context 'Scan and Evaluation' {
        
                $Results = InitiateSecurityPolicies
                $Testset = $Results.Output
                
                It "Initiate Software Updates Assignments Evaluation Cycle Policy on '<SoftwareEvaluationCycleResult>'" -TestCases $Testset {
                param
                (
                    $SoftwareEvaluationCycleResult
                )
                $SoftwareEvaluationCycleResult | Should Not Be $null
                
              }
              It "Initiate Software Update Scan Cycle Policy on '<SoftwareUpdateScanCycleResult>'" -TestCases $Testset {
                param
                (
                    $SoftwareUpdateScanCycleResult
                )
                $SoftwareUpdateScanCycleResult | Should Not Be $null
                
              }
              
                
          }
 
 Context 'Validate that machines are able to successfully run scan and evaluation without error' {
         
         $FileLogData = Get-SoftwareUpdateLogs -ExpectedErrorLogDeploymentFile $ExpectedErrorLogDeploymentFile -ExpectedErrorPattern $ExpectedErrorPattern
         $Testset = $FileLogData.Output
                
          It "Verify if machines are able to successfully run scan and evaluation without error" -TestCases $Testset {
                param
                (
                    $LogData
                   
                )
                $LogData | Should Be $null
                
              }
        
        }

Context 'Validate that applicable updates are listed in the logs' {
         
         $FileLogData = Get-ScanLogs -ExpectedLogScanFile $ExpectedLogScanFile -ExpectedScanStatus $ExpectedScanStatus
         $Testset = $FileLogData.Output
                
          It "Validate that applicable updates are listed in the logs" -TestCases $Testset {
                param
                (
                    $Log
                   
                )
                $Log | Should Not Be $null
                
              }
        
        }

Context 'Verify the Policy applied to Clients' {
         
         $FileLogData = Get_EPAgentGeneratedPolicies 
         $Testset = $FileLogData.Output
                
          It "Verify the Policy applied to Clients, Genereated Policies are '<EPAgentGeneratedPolicies>'" -TestCases $Testset {
                param
                (
                    $EPAgentGeneratedPolicies
                   
                )
                $EPAgentGeneratedPolicies | Should Not Be $null
                
              }
        
        }
Context 'Verify that no new signature is downloaded and re-applied and the original signature is retained after the migration.' {
         
         $FileData = Get_GuidFolder -WindowsDefender $WindowsDefender 
         $Testset = $FileData.Output
                
          It "Verify that no new signature is downloaded and re-applied and the original signature is retained after the migration,GuidFolderName is '<GuidFolderName>' and Datetime '<GuidFolderDateTime>'" -TestCases $Testset {
                param
                (
                    $GuidFolderName,
                    $GuidFolderDateTime
                   
                )
                $GuidFolderName | Should Not Be $null
                
              }
        
        }


}#Security & Compliance

    
        



   
    




        
        
        

