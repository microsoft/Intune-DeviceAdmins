#############################################################################
# Purpose : This script is to delete all collections/Packages/Applications from a specific folder
# Created : 2018/10/08
# Author  : Microsoft
#
#############################################################################

#region Configuration variables
$BaseDirectory = "$PSScriptRoot\Config"
Import-LocalizedData -BaseDirectory $BaseDirectory -FileName InfraQCConfigurations.psd1 -BindingVariable Configurations
$InputParams = $Configurations.InputParams

$SiteCode = $Configurations.PrimarySiteCode
$SiteServer = $Configurations.SiteServers[$Configurations.PrimarySiteCode]

$CollectionFolderName = $InputParams.CollectionFolderName
$PackageFolderName = $InputParams.PackageFolderName
$ApplicationFolderName = $InputParams.ApplicationFolderName

#endregion

#Import SCCM Module
$ModuleName = (get-item $env:SMS_ADMIN_UI_PATH).parent.FullName + "\ConfigurationManager.psd1"
Import-Module $ModuleName 

#Get SiteCode
CD $SiteCode":"

#Create the log file to trick the what are artifacts are deleted
    $OutputPath = $PSScriptRoot 
    $timeStamp = (Get-Date).ToString("yyyy-MM-dd hh mm ss")
    $ReportPath = "{0}\CleanUPLogs\{1}" -f $OutputPath, $timeStamp
    if(!(Test-Path $ReportPath -ErrorAction SilentlyContinue))
    {
        New-Item -ItemType Directory -Path $ReportPath -Force
    }
    $OutputLogFileName = "{0}\ArtifactsCleanuplogs.log" -f $ReportPath
    

########Delete Collections

#Get ContainerNodeID for Folders
$FolderList = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -class "SMS_ObjectContainerNode" -Filter "Name LIKE '$CollectionFolderName'"
$FolderID = $FolderList.ContainerNodeID

#Get CollectionID under Folder and delete collection
Foreach($ContainerNodeID in $FolderID)
    { 
        $ContainerNode = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -Query "SELECT InstanceKey FROM SMS_ObjectContainerITEM WHERE ContainerNodeID = '$ContainerNodeID'"
        $ContainerID = $ContainerNode.InstanceKey
        Foreach($CollectionID in $ContainerID)
            {
            $CollectionList = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -Query "SELECT * FROM SMS_Collection WHERE CollectionID = '$CollectionID'"
            $CollectionToDelete = $CollectionList.CollectionID
                        
            #Deleting Collection
            Foreach ($CollectionToDeleteID in $CollectionToDelete)
              {
                try
                 {
                  Remove-CMDeviceCollection -CollectionId $CollectionToDeleteID -Force
                  "Deleted CollectionId $CollectionToDeleteID" | Out-File $OutputLogFileName -Append
                }
              
            catch [System.Exception]
                {
                  $returnObj += "Error - $($_.Exception.ToString())"
                  "Unable to delete Collection: $returnObj" | Out-File $OutputLogFileName -Append
                }
              }
            }
    }

###########################################################

#####Delete Packages

#Get ContainerNodeID for Folder
$FolderList = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -class "SMS_ObjectContainerNode" -Filter "Name LIKE '$PackageFolderName'"
$FolderID = $FolderList.ContainerNodeID

#Get PackageID under Folder and delete Package
Foreach($ContainerNodeID in $FolderID)
    { 
        $ContainerNode = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -Query "SELECT InstanceKey FROM SMS_ObjectContainerITEM WHERE ContainerNodeID = '$ContainerNodeID'"
        $ContainerID = $ContainerNode.InstanceKey
        Foreach($PackageID in $ContainerID)
            {
            $PackageList = Get-CMPackage -Id $PackageID
            $PackageToDelete = $PackageList.PackageID
                        
            #DeletingPackage
            Foreach ($PackageToDeleteID in $PackageToDelete)
             {
            try
             {
                Remove-CMPackage -Id $PackageToDeleteID -Force
                "Deleted Package $PackageToDeleteID" | Out-File $OutputLogFileName -Append
             }
            catch [System.Exception]
             {
                $returnObj += "Error - $($_.Exception.ToString())"
                "Unable to delete Package: $returnObj" | Out-File $OutputLogFileName -Append
             }
                
            }
           }
    }

 ###########################################################

#####Delete Applications
#Get ContainerNodeID for Folder
$FolderList = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -class "SMS_ObjectContainerNode" -Filter "Name LIKE '$ApplicationFolderName'"
$FolderID = $FolderList.ContainerNodeID

#Get ApplicationCIID under Folder and delete Application
Foreach($ContainerNodeID in $FolderID)
    { 
        $ContainerNode = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -Query "SELECT * FROM SMS_ObjectContainerITEM WHERE ContainerNodeID = '$ContainerNodeID'"
        $ContainerID = $ContainerNode.InstanceKey
        Foreach($AppID in $ContainerID)
            {
            $AppList = Get-CMApplication -ModelName $AppID
            $AppToDelete = $AppList.CI_ID
                        
            #DeleteApplication
            Foreach ($AppToDeleteID in $AppToDelete)
            {
             #Delete Deployment if exists
             if($AppList.NumberOfDeployments -ne 0)
               {
            
              try{
                  Remove-CMApplicationDeployment -SmsObjectId $AppToDeleteID -Force
                  "Deleted Deployment $AppToDeleteID" | Out-File $OutputLogFileName -Append
                }
             catch [System.Exception]
                 {
                  $returnObj += "Error - $($_.Exception.ToString())"
                  "Unable to delete ApplicationDeployment: $returnObj" | Out-File $OutputLogFileName -Append 
                }
             }
            
           try{
                Remove-CMApplication -Id $AppToDeleteID -Force
                "Deleted Application $AppToDeleteID" | Out-File $OutputLogFileName -Append
                
                }
           catch [System.Exception]
               {
                 $returnObj += "Error - $($_.Exception.ToString())"
                 "Unable to delete Application: $returnObj" | Out-File $OutputLogFileName -Append
                     
               }
           }
         }
    }

###end
