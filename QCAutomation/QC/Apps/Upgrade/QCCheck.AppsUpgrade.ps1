param
(
    
    $InputParams,
    $Configurations
)

$AppsParams = $Configurations.AppsParams

$DistributionPointGroupName = $AppsParams.DistributionPointGroupName
$DistributionPointName = $AppsParams.DistributionPointName
$DeployCollectionName = $InputParams.DeployCollectionName
$UserCollectionName = $AppsParams.UserCollectionName
$SourcePath = $InputParams.SourcePath
$AppSourcePath = $InputParams.AppSourcePath
$AppxAppSourcePath = $InputParams.AppxAppSourcePath
$DependencySource = $AppsParams.DependencySource
$SupersedSource = $InputParams.SupersedSource
$SupersedAppSource = $InputParams.SupersedAppSource
$GlobalConditionName = $AppsParams.GlobalConditionName
$GlobalCondFileName = $AppsParams.GlobalCondFileName
$GlobalCondWqlName = $AppsParams.GlobalCondWqlName
$ComputerName1 = $InputParams.ComputerName1
$ComputerName2 = $InputParams.ComputerName2
$CollectionFolderName = $AppsParams.CollectionFolderName
$PackageFolderName = $AppsParams.PackageFolderName
$ApplicationFolderName = $AppsParams.ApplicationFolderName
$LimitingCollectionName = $InputParams.LimitingCollectionName
$IncludeCollectionName = $AppsParams.IncludeCollectionName
$ConfigurationItemName = $AppsParams.ConfigurationItemName
$BaselineName = $AppsParams.BaselineName
$DPMachineNameSubstring = $AppsParams.DPMachineNameSubstring

$CollectionFolderPath = $AppsParams.CollectionFolderPath
$ApplicationFolderPath = $AppsParams.ApplicationFolderPath
$PackageFolderPath = $AppsParams.PackageFolderPath

Describe 'Application Deployment' {

     Context 'Create a collection at Central Site with direct membership' {
             $Computers = $ComputerName1, $ComputerName2
           $colResult = Create-DirectMembershipCollection -Computers $Computers -LimitingCollectionName $LimitingCollectionName -CollectionFolderName $CollectionFolderName -CollectionFolderPath $CollectionFolderPath
                $Testset = $colResult.Output
                
                It "Verify if able to create collection with Direct Memebership Name: '<CollectionName>' Id: '<CollectionId>' " -TestCases $TestSet {
                    param
                    (
                        $CollectionName,
                        $CollectionId,
                        $DeviceCollectionDirectMembershipRule
                    )
                    $CollectionId | Should Not Be $null
                    $DeviceCollectionDirectMembershipRule | Should Not Be $null
                }
                
                }
        
        Context 'Create a collection at Central Site with query rule membership' {
        
            $colResult = Create-CollectionWithQueryMembership -LimitingCollectionName $LimitingCollectionName -DPMachineNameSubstring $DPMachineNameSubstring
                $Testset = $colResult.Output
                
                It "Verify able to create collection with query rule membership Name: '<CollectionName>' Id: '<CollectionId>' " -TestCases $TestSet {
                    param
                    (
                        $CollectionName,
                        $CollectionId
                    )
                    $CollectionId | Should Not Be $null
                }
                It "Verify if able to delete query collection Name: '<CollectionName>' Id: '<CollectionId>' " -TestCases $TestSet {
                    param
                    (
                        $CollectionName,
                        $CollectionId,
                        $Id
                    )
                    $Id | Should Be $null
                }
                }

            Context 'Create a collection at Central Site with Include rule membership ' {
        
                $colResult = Create-CollectionWithInculdeMembership -LimitingCollectionName $LimitingCollectionName -IncludeCollectionName $IncludeCollectionName -CollectionFolderName $CollectionFolderName -CollectionFolderPath $CollectionFolderPath
                $Testset = $colResult.Output
                
                It "Verify able to create collection with Include rule membership Name: '<CollectionName>' Id: '<CollectionId>' " -TestCases $TestSet {
                    param
                    (
                        $CollectionName,
                        $CollectionId
                    )
                    $CollectionId | Should Not Be $null
                }
                }
              
       

        Context 'Create a package with program at Central Site with Source files ' {
            
                              
                $Testset = Get-AppsPackage -DistributionPointName $DistributionPointName -DistributionPointGroupName $DistributionPointGroupName -DeployCollectionName $DeployCollectionName -SourcePath $SourcePath -PackageFolderName $PackageFolderName -PackageFolderPath $PackageFolderPath
                $Testset = $Testset.Output
                           
                It 'Verify if able create test package - Name: <PackageName> Id: <PackageId>' -TestCases $TestSet  {
                    param
                    (
                        $PackageName,
                        $PackageId
                    )
                    $PackageId | Should Not Be $null
                }

                It "Verify if able to distribute test package '<PackageName>' to distribution point group - '<DistributionPointGroupName>'" -TestCases $TestSet  {
                    param
                    (
                        $PackageName,
                        $PackageId,
                        $DistributionPointName,
                        $DistributionPointGroupName,
                        $ReplicationSuccess

                    )
                     $ReplicationSuccess | Should Not Be $null
                }

                It "Verify if able to deploy package to client setting Run From DP Pkg Name '<PackageName>'" -TestCases $TestSet  {
                    param
                    (
                        $PackageName,
                        $PackageId,
                        $StandardProgramName,
                        $LimitingCollectionName,
                        $DistributionPointGroupName
                    )       
                   
                    $DeploymentStatus.Count | Should Not Be $null
                } 
                
                It "Verify if able to Create Folders under Package/Advertisement Node (Create, modify)  FoldersName '<PSChildName>'" -TestCases $TestSet  {
                    param
                    (
                        $PackageName,
                        $PackageId,
                        $PSChildName
                    )       
                   
                    $PSChildName.Count | Should Not Be $null
                }           
           
        }

        Context 'Package Replication and Deploy package to client setting download content locally and Run' {
            
                              
                $Testset = Create-PkgDownloadContentLocally -DistributionPointName $DistributionPointName -DistributionPointGroupName $DistributionPointGroupName -DeployCollectionName $DeployCollectionName -SourcePath $SourcePath -PackageFolderName $PackageFolderName -PackageFolderPath $PackageFolderPath
                $Testset = $Testset.Output
                           
                It "Package Replication Status Pkg Name '<PackageName>' NumberSuccess '<ReplicationSuccess>' and NumberInProgress '<ReplicationInprog>'" -TestCases $TestSet  {
                    param
                    (
                        $PackageName,
                        $PackageId,
                        $DistributionPointGroupName,
                        $ReplicationSuccess,
                        $ReplicationInprog
                    )       
                   
                    $ReplicationSuccess.Count | Should Not Be $null
                }  
                It "Verify if able to deploy package to client setting download content locally and Run Pkg Name '<PackageName>'" -TestCases $TestSet  {
                    param
                    (
                        $PackageName,
                        $PackageId,
                        $DistributionPointGroupName
                    )       
                   
                    $DeploymentStatus.Count | Should Not Be $null
                }      
               }
        
    Context 'Create AppModel Manually (Central Site Only) ' {
        
                $Testset = Create-Application -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName -DeployCollectionName $DeployCollectionName -ApplicationFolderName $ApplicationFolderName -AppSourcePath $AppSourcePath -ApplicationFolderPath $ApplicationFolderPath
                $Testset = $Testset.Output
                           
                It 'Verify able create test Application - Name: <ApplicationName> Id: <ApplicationID>' -TestCases $TestSet  {
                    param
                    (
                        $ApplicationName,
                        $ApplicationID
                    )
                    $ApplicationID | Should Not Be $null
                }

                It "Verify able to Add test deploymentType to Application '<ApplicationName>' and deploymentType name '<DisplayName>'" -TestCases $TestSet  {
                    param
                    (
                        $ApplicationName,
                        $DisplayName
                        
                    )
                    $DisplayName | Should Not Be $null
                }

                It "Deploy AppModel '<AppModelId>' to machine (Central Site Only)" -TestCases $TestSet {
                    param
                    (
                        $ApplicationName,
                        $AppModelId
                        
                    )
                    $AppModelId | Should Not Be $null
                    }
                    It "Verify if able to Export Application '<ApplicationName>' Path is '<folderPath>' " -TestCases $TestSet {
                    param
                    (
                        $ApplicationName,
                        $AppModelId,
                        $Exported,
                        $folderPath
                        
                    )

                    $Exported | Should Not Be $null
                    }



    }

    Context 'Set AppModel Dependency link to another AppModel (Central Site Only) ' {
        
                $Testset = Create-DependencyApp -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName -DeployCollectionName $DeployCollectionName -ApplicationFolderName $ApplicationFolderName -AppSourcePath $AppSourcePath -ApplicationFolderPath $ApplicationFolderPath -DependencySource $DependencySource
                $Testset = $Testset.Output
                           
                It 'Verify if able to Set AppModel Dependency link to another AppModel- Name: <DependentAppName> Id: <DependentAppID>' -TestCases $TestSet  {
                    param
                    (
                        $DependentAppName,
                        $DependentAppID
                    )
                    $DependentAppID | Should Not Be $null
                }
    }

   Context 'Modern app with APPX on client ' {
        
                $Testset = Create-AppxApplication -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName -DeployCollectionName $DeployCollectionName -ApplicationFolderName $ApplicationFolderName -AppxAppSourcePath $AppxAppSourcePath -ApplicationFolderPath $ApplicationFolderPath
                $Testset = $Testset.Output
                           
                It 'Verify able create test Appx Application - Name: <ApplicationName> Id: <ApplicationID>' -TestCases $TestSet  {
                    param
                    (
                        $ApplicationName,
                        $ApplicationID
                    )
                    $ApplicationID | Should Not Be $null
                }
               }
    Context 'Modern app with Deep link on  client ' {
        
                $Testset = Create-AppwithDeeplink -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName -UserCollectionName $UserCollectionName -ApplicationFolderName $ApplicationFolderName -AppxAppSourcePath $AppxAppSourcePath -ApplicationFolderPath $ApplicationFolderPath
                $Testset = $Testset.Output
                           
                It 'Verify able create test App with deep link Application - Name: <ApplicationName> Id: <ApplicationID>' -TestCases $TestSet  {
                    param
                    (
                        $ApplicationName,
                        $ApplicationID
                    )
                    $ApplicationID | Should Not Be $null
                }
               }
     Context 'Modern app with Supersedes application on  client ' {
              
              $Testset = Create-SupersededApp -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName -DeployCollectionName $DeployCollectionName -ApplicationFolderName $ApplicationFolderName -AppxAppSourcePath $AppxAppSourcePath -SupersedSource $SupersedSource -ApplicationFolderPath $ApplicationFolderPath
                $Testset = $Testset.Output
                           
                It 'Verify able create test Supersedes Application - Name: <SuperAppName> Id: <SuperAppID>' -TestCases $TestSet  {
                    param
                    (
                        $SuperAppName,
                        $SuperAppID
                    )
                    $SuperAppID | Should Not Be $null
                }
     }

     Context 'App Model with Supersedes application on client ' {
              
              $Testset = Create-AppModelSupersed -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName -DeployCollectionName $DeployCollectionName -ApplicationFolderName $ApplicationFolderName -AppSourcePath $AppSourcePath -SupersedAppSource $SupersedAppSource -ApplicationFolderPath $ApplicationFolderPath
                $Testset = $Testset.Output
                           
                It 'Verify able create test App Model Supersedes Application - Name: <SuperAppName> Id: <SuperAppID>' -TestCases $TestSet  {
                    param
                    (
                        $SuperAppName,
                        $SuperAppID
                    )
                    $SuperAppID | Should Not Be $null
                }
     }

}#ApplicationDeployment


Describe 'DCM Evaluation/EDP' {

   Context 'DCM Evaluation' {
        $Testset = Check-DCMEvaluation
        $Testset = $Testset.Output
        It "Verify if computer agent for PowerShell execution policy is set to '<DCMEvaluation>' " -TestCases $TestSet  {
                    param
                    (
                        $DCMEvaluation
                        
                    )
                    $DCMEvaluation | Should Not Be $null
                }

   }

   Context 'EDP' {
        $TestSet = Create-EDPPolicy -ConfigurationItemName $ConfigurationItemName -BaselineName $BaselineName -DeployCollectionName $DeployCollectionName
        $TestSet = $TestSet.Output
        It "Verify if able to create ConfigurationItem Name '<LocalizedDisplayName>'" -TestCases $TestSet  {
                    param
                    (
                        $LocalizedDisplayName,
                        $ConfigCIID
                        
                    )
                    $ConfigCIID | Should Not Be $null
                }
        It "Verify if able to create Configuration Baseline Name '<BaseName>'" -TestCases $TestSet  {
                    param
                    (
                        $BaseName,
                        $BaselineCIID
                        
                    )
                    $BaselineCIID | Should Not Be $null
                }

   }


}#DCM Evaluation/EDP

Describe 'Global Conditions' {
   
   Context 'GlobalConditions Registry/File/WQL' {
        $Testset = Create-GlobalConditions -GlobalConditionName $GlobalConditionName -GlobalCondFileName $GlobalCondFileName -GlobalCondWqlName $GlobalCondWqlName
        $Testset = $Testset.Output
        It "Verify if able to create GlobalCondition type Registry  '<GloConditionType>' and Name '<GloConditionName>' " -TestCases $TestSet  {
                    param
                    (
                        $GloConditionID,
                        $GloConditionName,
                        $GloConditionType
                        
                    )
                    $GloConditionID | Should Not Be $null
                }
        It "Verify if able to create GlobalCondition type File  '<GloConditionFileType>' and Name '<GloConditionFileName>' " -TestCases $TestSet  {
                    param
                    (
                        $GloConditionFileID,
                        $GloConditionFileName,
                        $GloConditionFileType
                              
                        
                    )
                    $GloConditionFileID | Should Not Be $null
                }
       It "Verify if able to create GlobalCondition type Wql Query  '<GloConditionWqlType>' and Name '<GloConditionWqlName>' " -TestCases $TestSet  {
                    param
                    (
                        $GloConditionWqlID,
                        $GloConditionWqlName,
                        $GloConditionWqlType
                        
                    )
                    $GloConditionWqlID | Should Not Be $null
                }


   }


}#Global Conditions