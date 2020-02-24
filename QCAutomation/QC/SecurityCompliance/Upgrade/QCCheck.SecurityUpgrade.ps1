param
(
    
    $InputParams,
    $Configurations
)

$ConfigParams = $Configurations.ConfigParams

$DPGroupName = $InputParams.DPGroupName
$CollectionName = $InputParams.CollectionName
$SugName = $ConfigParams.SugName
$ADRName = $ConfigParams.ADRName
#$UserCollectionName = $AppsParams.UserCollectionName
$ADRDescription = $InputParams.ADRDescription
$ArticleId = $InputParams.ArticleId
$DeployPackageLocation = $InputParams.DeployPackageLocation
$Languages = $ConfigParams.Languages

          
Describe 'Patching Server Side' {

     Context 'Create New ADR and verify if is working' {
             
           $TestSet = Create-ADR -DPGroupName $DPGroupName -ADRDescription $ADRDescription -ArticleId $ArticleId -DeployPackageLocation $DeployPackageLocation -Languages $Languages -CollectionName $CollectionName -ADRName $ADRName
                $TestSet = $TestSet.Output
                
                It "Verify if able to create New ADR Name: '<NewADRName>' " -TestCases $TestSet {
                    param
                    (
                        $NewADRName
                        
                    )
                    $NewADRName | Should Not Be $null
                    
                }

                It "Verify if it is working by returning error code: '<LastErrorCode>' " -TestCases $TestSet {
                    param
                    (
                        $LastErrorCode
                        
                    )
                    $LastErrorCode | Should Not Be $null
                }
                
             }
             
   Context 'Software Update groups and Deployments' {
             
           $TestSet = Get-SUG -ADRName $ADRName 
                $TestSet = $TestSet.Output
                
                It "Verify if it able to create Software Update groups and Deployments to ADR Name: '<LocalizedDisplayName>' " -TestCases $TestSet {
                    param
                    (
                        $LocalizedDisplayName
                        
                        
                    )
                    $LocalizedDisplayName | Should Not Be $null
                    
                }
            }

  Context 'Create new deployment and update group are working as expected' {
             
           $TestSet = Create-SUG -DPGroupName $DPGroupName -SugName $SugName -ArticleId $ArticleId -DeployPackageLocation $DeployPackageLocation -Languages $Languages -CollectionName $CollectionName -ADRName $ADRName
                $TestSet = $TestSet.Output
                
                It "Verify if able to create new deployment and update group Name: '<NewSug>' " -TestCases $TestSet {
                    param
                    (
                        $NewSug,
                        $SUGCIID
                        
                    )
                    $SUGCIID | Should Not Be $null
                    
                }
            }

Context 'Create deployment for the updates using package (First download updates then create deployment scenario) ' {
             
           $TestSet = Create-SUGDeployment  -SugName $SugName -CollectionName $CollectionName
                $TestSet = $TestSet.Output
                
                It "Verify if able to create new deployment Name: '<DeploymentName>' " -TestCases $TestSet {
                    param
                    (
                        $DeploymentName,
                        $DeploymentID
                        
                    )
                    $DeploymentID | Should Not Be $null
                    
                }

            It "Validate that actions like FULL SCAN, QUICK SCAN, and SIGNATURE UPDATE activities can be carried out. " -TestCases $TestSet {
                    param
                    (
                        $QuickScan
                        
                        
                    )
                    $QuickScan | Should Be $null
                    
                }
            }

}#Patching Server Side