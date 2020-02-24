@{

InputParams = @{                   
                    UpgradeDateTime = '2018-09-25 05:04' ## Time (PST) when upgrade is scheduled (Pre-QC) or happened (Post QC) 
                    BaseDirectory = '$PSScriptRoot\Config\Prod'
                                     
                }
ExpectedValues = @{
                    ExpectedClientVersion = "5.00.8692.1008" ## Change this as per upgrade release
                    ExpectedUpgradeName = "Test QC for Persistent admin entitlements remove on AU1 Site" ## Change this as per upgrade release
                    ExpectedLogScanFile = 'C:\Windows\CCM\Logs\WUAHandler.log'
                    ExpectedErrorLogDeploymentFile = 'C:\Windows\CCM\Logs\UpdatesDeployment.log'
                    ExpectedErrorPattern = "Error"
                    ExpectedScanStatus = "Successfully completed scan"
                    WindowsDefender = "C:\ProgramData\Microsoft\Windows Defender\Definition Updates"
                    }                   


}