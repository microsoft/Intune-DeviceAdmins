<#
.SYNOPSIS
    Colect Device Logs from a Collection ID or Device Name in SCCM
.DESCRIPTION
    Powershell script used to collect device logs from user devices from SCCM. 
    It works by connecting to SCCM, running a Powershell script called Collect Logs to Cloud 
    stored in SCCM on each device collecting specific logs, connecting to an Azure Storage 
    Account with an MSI using Client Id, and then sending the logs to the Storage Account. An
    HTML Report is also generated in the local filepath with the results.
.PARAMETER SiteCode
    SCCM Site Code
.PARAMETER SiteServer
    SCCM Site Server
.PARAMETER StorageAccountName
    Name of Azure Storage Account
.PARAMETER StorageAccountResourceGroup
    Name of Azure Storage Account Resource Group
.PARAMETER Container
    Name of Container in Azure Storage Account
.PARAMETER ClientId
    Azure MSI Client Id used to get the Storage Account Access Token
.NOTES
    Version:        1.0
    Creation date:  02/09/2023
    Purpose/Change: Open Source example
#>

$ErrorActionPreference = "Stop"
$SiteCode = "" #Enter SCCM Site Code
$SiteServer = "" #Enter SCCM Site Server Fully Qualified Domain Name
$Namespace = "root\sms\site_$SiteCode"
$StorageAccountName = "" #Enter Azure Storage Account Name where logs will be sent
$StorageAccountResourceGroup = "" #Enter Azure Storage Account Resource Group Name where logs will be sent
$Container = "" #Enter Azure Storage Account Container Name where logs will be sent
$StorageURL = "https://$($StorageAccountName).blob.core.windows.net/$($Container)"
enum EnumExecutionState 
{
    Succeeded = 1
    Failed  = 2
}
function Create-HTMLTable 
{
    param(
        [Parameter(Mandatory)]
        $TableData
    )
    $CSS = "<style>
                TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
                TH{border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
                TD{border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
                .odd { background-color:#ffffff;}
                .even { background-color:#e7e7e7;}
           </style>"

    return ($TableData | ConvertTo-HTML -as Table -Fragment -PreContent $CSS | Out-String)
}
function Connect-ConfigMgrProvider($SiteCode, $SiteServer) 
{
    $initParams = @{}
    $Module = (Get-Item $env:SMS_ADMIN_UI_PATH).Parent.FullName + "\ConfigurationManager.psd1" 
    Import-Module $Module @initParams
   
    if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -Scope Script @initParams | Out-Null
    }
    Set-Location "$($SiteCode):\" @initParams | Out-Null
}
function Get-MsiAccessToken
{
    param
    (
        [Parameter(Mandatory=$true)]
        [Validateset("https://graph.microsoft.com","https://vault.azure.net","https://management.azure.com","https://database.windows.net")]
        $ResourceUri,
        [Parameter(Mandatory=$true)]
        $ClientId
    )
    $msiEndpoint = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$($ResourceUri)&client_id=$($ClientId)"
    $response = Invoke-WebRequest -Uri $msiEndpoint -Headers @{"Metadata"= $true} -UseBasicParsing
    $responseJson = ConvertFrom-Json -InputObject $response
    $AccessToken = $responseJson.access_token
    return $AccessToken
}
function Get-SASToken($StorageAccountName, $StorageAccountResourceGroup) 
{
    $ClientId = "" #Enter MSI Client Id with access to the Azure Storage Account
    $AccessToken = Get-MsiAccessToken -ResourceUri https://management.azure.com -ClientId $ClientId
    Connect-AzAccount -AccessToken $AccessToken -AccountId $ManagedIdentity | Out-Null
    $StorageAccountAccessKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageAccountResourceGroup -Name $StorageAccountName).Value[0]
    $StorageContext = New-AzStorageContext $StorageAccountName -StorageAccountKey $StorageAccountAccessKey
    New-AzStorageAccountSASToken -Context $StorageContext -Service Blob -ResourceType Object -Permission "rw" -ExpiryTime (Get-Date).AddHours(1)
}
function WaitToComplete($OperationId) 
{
    Write-Output "OperationId - $($OperationId) - checking Runscript execution status"
    #Get script output, wait a maximum of 30 minutes
    $pollTimeOut = (Get-Date).AddMinutes(30)
    do 
    {
        $ExecutionStatuses = Get-CimInstance -ComputerName $SiteServer -Namespace $Namespace -ClassName SMS_ScriptsExecutionStatus -Filter "ClientOperationID = '$OperationId'" 
        if ($ExecutionStatuses) 
        {
            Write-Output "RunScript Execution Completed : OperationId - $($OperationId)"
            return $ExecutionStatuses
        }

        Write-Output "OperationId - $($OperationId) - Sleeping for 15 seconds for check Runscript execution status"
        Start-Sleep -Seconds 15
    }
    while ((Get-date) -le $pollTimeOut)
    Write-Output "OperationId - $($OperationId) - Get Runscript execution status timedout"
}
function Collect-Log ($TargetSources, $FilesOrFolders) 
{
    Begin 
    {
        Write-Output "Executing Collect-Logs script"
        Write-Output "TargetSources : $TargetSources, FilesOrFolders : $FilesOrFolders"
        $TargetSourcesColletion = $TargetSources.Split(',', [StringSplitOptions]::RemoveEmptyEntries)
        $FilesOrFoldersColletion = $FilesOrFolders.Split(',', [StringSplitOptions]::RemoveEmptyEntries).ToLowerInvariant()
        $AllowedFolders = 'c:\windows\ccm\logs,c:\windows\ccmsetup\logs'
        foreach ($Folder in $FilesOrFoldersColletion) 
        {
            if ($AllowedFolders.Contains($Folder) -eq $false) 
            {
                Write-Error "Folder : '$Folder' not in scope to collect device log"
                break
            }
        }
        #Connect to SCCM
        Connect-ConfigMgrProvider -SiteCode $SiteCode -SiteServer $SiteServer
        $TargetCollections = @()
        $TargetDevices = @()
        foreach ($TargetSource in $TargetSourcesColletion) 
        {
            $Collection = Get-CMCollection -CollectionId $TargetSource
            if ([string]::IsNullOrEmpty($Collection)) 
            {
                $Device = Get-CMDevice -Name $TargetSource -Fast
                if ([string]::IsNullOrEmpty($Device)) 
                {
                    Write-Error "'$TargetSource' is not valid Device or Collection"
                }
                else 
                {
                    $TargetDevices += $Device
                }
            }
            else 
            {
                $TargetCollections += $TargetSource
            }
        }
        $SASToken = Get-SASToken -StorageAccountName $StorageAccountName -StorageAccountResourceGroup $StorageAccountResourceGroup
        $RunScriptName = "Collect Logs to Cloud" #This file needs to be uploaded to SCCM
        Write-Output "Getting CM Script '$RunScriptName' from ConfigManager"
        $ScriptGuid = (Get-CMScript -ScriptName $RunScriptName -Fast).ScriptGuid
        if ([string]::IsNullOrEmpty($ScriptGuid)) 
        {
            Write-Error "No Script found with the name '$RunScriptName' in the ConfigMgr Script Repository"
            break
        }
    }
    Process 
    {
        $EscapedSASToken = [uri]::EscapeDataString($SASToken)
        $Parameters = @{
            "EscapedSASToken" = "$EscapedSASToken"
            "StorageURL" = "$StorageURL"
            "FilesOrFolders" = "$FilesOrFolders"
        }
        $ExecutionResults = @()
        $CollectionOperationResults = @()
        $DeviceOperationResults = @()
        $CollectionExecutionStatuses = @()
        $DeviceExecutionStatuses = @()
        foreach ($TargetCollection in $TargetCollections) 
        {
            Write-Output "Invoking Runscript on Config Manager for Collection $($TargetCollection)"
            $OperationId = (Invoke-CMScript -CollectionId $TargetCollection -ScriptGuid $ScriptGuid -ScriptParameter  $Parameters -PassThru).OperationID
            Write-Output "Runscript Invoked on Config Manager for Collection $($TargetCollection) with OperationId: $($OperationId)"
            $Record = New-Object PSObject
            $Record | Add-Member -type NoteProperty -Name 'Collection' -Value $TargetCollection
            $Record | Add-Member -type NoteProperty -Name 'OperationId' -Value $OperationId
            $CollectionOperationResults += $Record
        }
        foreach ($TargetDevice in $TargetDevices) 
        {
            Write-Output "Invoking Runscript on Config Manager for Device $($TargetDevice.Name)"
            $OperationId = (Invoke-CMScript -Device $TargetDevice -ScriptGuid $ScriptGuid -ScriptParameter $Parameters  -PassThru).OperationID
            Write-Output "Runscript Invoked on Config Manager for Device $($TargetDevice.Name) with OperationId: $($OperationId)"
            $Record = New-Object PSObject
            $Record | Add-Member -type NoteProperty -Name 'Device' -Value $TargetDevice.Name
            $Record | Add-Member -type NoteProperty -Name 'OperationId' -Value $OperationId
            $DeviceOperationResults += $Record
        }
        # Check execution status
        foreach ($DeviceOperation in $DeviceOperationResults) 
        {
            $ExecutionStatuses = WaitToComplete -OperationId $DeviceOperation.OperationId
            $Record = New-Object PSObject
            $Record | Add-Member -type NoteProperty -Name 'Device' -Value $DeviceOperation.Device
            $Record | Add-Member -type NoteProperty -Name 'OperationId' -Value $DeviceOperation.OperationId
            $Record | Add-Member -type NoteProperty -Name 'ExecutionStatuses' -Value $ExecutionStatuses
            $DeviceExecutionStatuses += $Record
        }
        foreach ($CollectionOperation in $CollectionOperationResults) 
        {
            $ExecutionStatuses = WaitToComplete -OperationId $CollectionOperation.OperationId
            $Record = New-Object PSObject
            $Record | Add-Member -type NoteProperty -Name 'Collection' -Value $CollectionOperation.Collection
            $Record | Add-Member -type NoteProperty -Name 'OperationId' -Value $CollectionOperation.OperationId
            $Record | Add-Member -type NoteProperty -Name 'ExecutionStatuses' -Value $ExecutionStatuses
            $CollectionExecutionStatuses += $Record
        }
        $Body = "RunScript : <b>$RunScriptName</b>,  Target Source : $TargetSources"
        #Prepare report for Collection
        foreach ($CollectionExecutionStatus in $CollectionExecutionStatuses) 
        {
            $ExecutionResults = @()
            Write-Output "Fetching collection members"
            $CollectionMembers = (Get-CMCollectionMember -CollectionId $CollectionExecutionStatus.Collection).Name
            Write-Output "Checking Runscript execution status for each members for collection : $($CollectionExecutionStatus.Collection)"
            foreach ($Member in $CollectionMembers) 
            {
                $ExecutionStatus = $CollectionExecutionStatus.ExecutionStatuses | Where-Object { $_.DeviceName -eq $Member }
                if ($ExecutionStatus -ne $null) 
                {
                    $ExecutionResults += [PSCustomObject] @{DeviceName = $($ExecutionStatus).DeviceName
                        ExecutionState                                 = ([EnumExecutionState]$($ExecutionStatus).ScriptExecutionState).ToString()
                        ExitCode                                       = $($ExecutionStatus).ScriptExitCode
                        ScriptOutput                                   = $($ExecutionStatus).ScriptOutput
                    }
                }
                else 
                {
                    $ExecutionResults += [PSCustomObject] @{DeviceName = $Member
                        ExecutionState                                 = 'Unknown'
                        ExitCode                                       = 'Unknown'
                        ScriptOutput                                   = 'NA'
                    }
                }
            }
            $ExecTask = Get-CimInstance -ComputerName $SiteServer -Namespace $Namespace -ClassName SMS_ScriptsExecutionTask -Filter "ClientOperationID = '$($CollectionExecutionStatus.OperationId)'" 
            $OverAllResult = [PSCustomObject] @{Completed = $($ExecTask.CompletedClients)
                NotApplicable                             = $($ExecTask.NotApplicableClients)
                Failed                                    = $($ExecTask.FailedClients)
                Unknown                                   = $($ExecTask.UnknownClients)
                Offline                                   = $($ExecTask.OfflineClients)
            }
            $OverAllResultTable = Create-HTMLTable -TableData $OverAllResult
            $ExecutionResultTable = Create-HTMLTable -TableData $ExecutionResults
            $Body += "<br><br><b>Overall Script Execution Status : Collection <em>$($CollectionExecutionStatus.Collection)</em></b><br><br>"
            $Body += $OverAllResultTable
            $Body += "<br><br><b>Client Execution Status : Collection <em>$($CollectionExecutionStatus.Collection)</em></b><br><br>"
            $Body += $ExecutionResultTable
        }
        #Prepare report for Devices
        foreach ($DeviceExecutionStatus in $DeviceExecutionStatuses) 
        {
            $ExecutionResults = @()
            $ExecutionStatus = $DeviceExecutionStatus.ExecutionStatuses
            if ($ExecutionStatus -ne $null) 
            {
                $ExecutionResults += [PSCustomObject] @{DeviceName = $($ExecutionStatus).DeviceName
                    ExecutionState                                 = ([EnumExecutionState]$($ExecutionStatus).ScriptExecutionState).ToString()
                    ExitCode                                       = $($ExecutionStatus).ScriptExitCode
                    ScriptOutput                                   = $($ExecutionStatus).ScriptOutput
                }
            }
            else 
            {
                $ExecutionResults += [PSCustomObject] @{DeviceName = $Member
                    ExecutionState                                 = 'Unknown'
                    ExitCode                                       = 'Unknown'
                    ScriptOutput                                   = 'NA'
                }
            }
            $ExecutionResultTable = Create-HTMLTable -TableData $ExecutionResults
            $Body += "<br><br><b>Individual Device Execution Status</b><br><br>"
            $Body += $ExecutionResultTable
        }
        $Body += "<br><br>Files Uploaded to Storage Account : $($StorageURL)"
        Write-Output "Collect-Logs Script Execution Completed"
        $Body | ConvertTo-Html | Out-File -FilePath .\Collect-DeviceLogs-Report.html
    }
    End 
    {
        Get-Content $global:LogFileName -ErrorAction SilentlyContinue
        Remove-Item -Path $global:LogFileName -Force -ErrorAction SilentlyContinue
    }
}
$TargetSources = "" #Comma separated list of SCCM Collection Ids or Device Names to collect logs from
$FilesOrFolders = "" #Comma separated list of Files/Folders Path to collect the logs from
Collect-Log -TargetSources $TargetSources -FilesOrFolders $FilesOrFolders