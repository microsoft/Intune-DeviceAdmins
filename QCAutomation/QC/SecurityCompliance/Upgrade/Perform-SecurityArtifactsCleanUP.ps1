#############################################################################
# Purpose : This script is to delete all ADR's/DeployedPackaages/SUG's which are created by QC Automation
# Created : 2019/01/01
# Author  : Microsoft
#
#############################################################################

#region Configuration variables
$BaseDirectory = "$PSScriptRoot\Config\Prod"
Import-LocalizedData -BaseDirectory $BaseDirectory -FileName SecurityQCConfigurations.psd1 -BindingVariable Configurations
$QCEnvironment = $ConfigParams.QCEnvironment
$CentralSiteDetails = $Configurations.CentralSiteDetails[$QCEnvironment]
$SiteCode = $CentralSiteDetails.SiteCode
$SiteServer = $CentralSiteDetails.SiteServer
$ConfigParams = $Configurations.ConfigParams
$SugName = $ConfigParams.SugName
$ADRName = $ConfigParams.ADRName
#endregion

#Import SCCM Module
$ModuleName = (get-item $env:SMS_ADMIN_UI_PATH).parent.FullName + "\ConfigurationManager.psd1"
Import-Module $ModuleName 

#Get SiteCode
CD $SiteCode":"

#Create the log file to track the what are artifacts are deleted
    $OutputPath = $PSScriptRoot 
    $timeStamp = (Get-Date).ToString("yyyy-MM-dd hh mm ss")
    $ReportPath = "{0}\CleanUPLogs\{1}" -f $OutputPath, $timeStamp
    if(!(Test-Path $ReportPath -ErrorAction SilentlyContinue))
    {
        New-Item -ItemType Directory -Path $ReportPath -Force
    }
    $OutputLogFileName = "{0}\ArtifactsCleanuplogs.log" -f $ReportPath
    

#####Delete Packages

#Get PackageID under Folder and delete Package

            $Package = Get-CMSoftwareUpdateDeploymentPackage -Name $ADRName
            $PackageToDeleteID = $Package.PackageID
                        
            #DeletingPackage
            
            try
             {
                Remove-CMSoftwareUpdateDeploymentPackage -Id $PackageToDeleteID -Force
                "Deleted Package $PackageToDeleteID" | Out-File $OutputLogFileName -Append
             }
            catch [System.Exception]
             {
                $returnObj += "Error - $($_.Exception.ToString())"
                "Unable to delete Package: $returnObj" | Out-File $OutputLogFileName -Append
             }
                
            
 ###########################################################

#####Delete ADR

            $ADR = Get-CMSoftwareUpdateAutoDeploymentRule -Name $ADRName
            $Name = $ADR.Name
            try
             {
                Remove-CMSoftwareUpdateAutoDeploymentRule -Name $Name -Force
                "Deleted ADR $Name" | Out-File $OutputLogFileName -Append
             }
            catch [System.Exception]
             {
                $returnObj += "Error - $($_.Exception.ToString())"
                "Unable to delete ADR: $returnObj" | Out-File $OutputLogFileName -Append
             }            
            

###end

###########################################################

#####Delete Software Update Group

            $Sug = Get-CMSoftwareUpdategroup -Name $SugName
            $LocalizedDisplayName = $Sug.LocalizedDisplayName
            try
             {
                Remove-CMSoftwareUpdategroup -Name $LocalizedDisplayName -Force
                "Deleted SUG $LocalizedDisplayName" | Out-File $OutputLogFileName -Append
             }
            catch [System.Exception]
             {
                $returnObj += "Error - $($_.Exception.ToString())"
                "Unable to delete ADR: $returnObj" | Out-File $OutputLogFileName -Append
             }            
            
           ##### Deleting Auto Deployed SUG's

            $SUGs = (get-cmsoftwareupdategroup).LocalizedDisplayName
            $Pattern = $ADRName +' '+ (Get-Date).ToString("yyyy-MM-dd") 
            foreach($Name In $SUGs){ if($Name -match $Pattern) { $SugName="$($Name)"}}
            $Sug = Get-CMSoftwareUpdategroup -Name $SugName
            $LocalizedDisplayName = $Sug.LocalizedDisplayName
            try
             {
                Remove-CMSoftwareUpdategroup -Name $LocalizedDisplayName -Force
                "Deleted SUG $LocalizedDisplayName" | Out-File $OutputLogFileName -Append
             }
            catch [System.Exception]
             {
                $returnObj += "Error - $($_.Exception.ToString())"
                "Unable to delete ADR: $returnObj" | Out-File $OutputLogFileName -Append
             }  

###end

   

