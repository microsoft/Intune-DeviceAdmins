param
(
    $InputParams,
    $AllSiteArtifacts,
    $Configurations
)

$SiteCode = $InputParams.SiteCode
$SiteArtifacts = $AllSiteArtifacts | ? {$_.SiteCode -eq $SiteCode}
$CentralSiteArtifacts = $AllSiteArtifacts | ? {$_.Site -eq "Central"}

## Expected values
$ExpectedValues = $Configurations.ExpectedValues
$ExpectedClientVersion = $InputParams.ExpectedClientVersion
$ExpectedUpgradeName = $InputParams.ExpectedUpgradeName

## Site code and server details - Primary (Central, not to be confused primary sites)
$PrimarySiteCode = $CentralSiteArtifacts.SiteCode
$PrimarySiteServerName = $CentralSiteArtifacts.SiteServer
$PrimarySQLServerName = $CentralSiteArtifacts.SQLClusterName
$PrimarySQLDBName = $CentralSiteArtifacts.SiteSQLDBName

## Site code and server details - QC site
$SiteServerName = $SiteArtifacts.SiteServer
$SiteSQLServerName = $SiteArtifacts.SQLClusterName
$SiteSQLDBName = $SiteArtifacts.SiteSQLDBName

$ComputerName1 = $InputParams.ComputerName1
$ComputerName2 = $InputParams.ComputerName2
$CollectionFolderName = $InputParams.CollectionFolderName
$LimitingCollectionName = $InputParams.LimitingCollectionName
$CollectionFolderPath = $InputParams.CollectionFolderPath
$QCEnvironment = $InputParams.QCEnvironment

## Following variables are removed as their test cases (distribute package) have been removed from the QC automation.
#$DistributionPointGroupName = $InputParams.DistributionPointGroupName
#$DistributionPointName = $InputParams.DistributionPointName
#$PackageFolderName = $InputParams.PackageFolderName
#$PackageFolderPath = $InputParams.PackageFolderPath
#$SourcePath = $InputParams.SourcePath

Describe 'Upgrade Completion Validation' {

        Context 'Verify if server is upgraded to correct build' {

            $SiteServerInfo = Get-SiteServerInfo -PrimarySiteCode $PrimarySiteCode -SiteCode $SiteCode -PrimarySiteServerName $PrimarySiteServerName -ProviderMachineName $SiteServerName

            It "Verify if connected to site - '<SiteCode>'" -TestCases @{SiteCode=$InputParams.SiteCode} {
                param
                (
                    $SiteCode
                )
                $IsSuccess = @{$true="No";$false="Yes"}[$SiteServerInfo.IsError]
                $IsSuccess | Should Be "Yes"
                #$SiteServerInfo.IsError | Should Be $False
                $SiteServerInfo.Output.ConnectionInfo.SiteCode | Should Be $SiteCode
                $SiteServerInfo.Output.ConnectionInfo.ProviderMachineName | Should Not Be $null
            }

            It "Verify if CM client Version is '<ExpectedClientVersion>'" -TestCases @{ExpectedClientVersion=$InputParams.ExpectedClientVersion} {
                param
                (
                    $ExpectedClientVersion
                )
                $SiteServerInfo.Output.SiteDetails["Version"].StringValue | Should Be $ExpectedClientVersion
                #$SiteServerInfo.Output.SiteDetails["Version"].StringValue | Should Be $SiteServerInfo.Output.UpdateStatus[0].ClientVersion
                #$SiteServerInfo.Output.SiteDetails["Version"].StringValue | Should Be $SiteServerInfo.Output.SiteProperties.'Full Version'
            }

            It "Verify if site is upgraded to latest build '<ExpectedUpgradeName>'" -TestCases @{ExpectedUpgradeName=$InputParams.ExpectedUpgradeName} {
                param
                (
                    $ExpectedUpgradeName
                )
                $SiteServerInfo.Output.UpdateStatus | Should Not Be $null
                $SiteServerInfo.Output.UpdateStatus[0] | Should Not Be $null
                $SiteServerInfo.Output.UpdateStatus[0].Name | Should Be $ExpectedUpgradeName
                #$SiteServerInfo.Output.UpdateStatus[0].Installed | Should Be $true
            }
    }

}

Describe 'Post Upgrade Hierarchy Health Validation' {

    Context "Verify if all ConfigMgr 2012 services are running" {

        $ProviderMachineName = $SiteServerName
        $ServicesStatus = Get-ServiceDetails -ComputerName $ProviderMachineName -ServiceNames @($ExpectedValues["ExpectedServiceStatus"].ServiceName)

        It "Verify if able to get details of all ConfigMgr 2012 services" {
            $IsSuccess = @{$true="No";$false="Yes"}[$ServicesStatus.IsError]
            $IsSuccess | Should Be "Yes"
            #$ServicesStatus.IsError | Should Be $False
            $ServicesStatus.Output | Should Not Be $null
        }

        It "Verify if '<ServiceName>' service is '<ExpectedStatus>'" -TestCases $ExpectedValues["ExpectedServiceStatus"] {
            param
            (
                $ServiceName,
                $ExpectedStatus
            )
            $ServiceStatus = $ServicesStatus.Output | ? {$_.Name -eq $ServiceName}
            $ServiceStatus | Should Not Be $null
            $ServiceStatus.Name | Should BeExactly $ServiceName
            $ServiceStatus.State | Should BeExactly $ExpectedStatus
        }
    }

    Context 'Check ConfigMgr 2012 logs for any errors/warnings' {

        $ProviderMachineName = $SiteServerName
        $ExpectedErrorLogFiles = $ExpectedValues["ExpectedErrorLogFiles"]
        $ExpectedErrorLogPattern = $ExpectedValues["ExpectedErrorLogPattern"]
        $ExpectedErrorLogFileDetails = @()
        $ExpectedErrorLogFiles | % { $ExpectedErrorLogFileDetails += @{FileName=$_;Filter=$ExpectedErrorLogPattern.Filter;IgnoreFilter=$ExpectedErrorLogPattern.IgnoreFilter} }
        $FileLogDetails = Get-FileLogs -ComputerNames $ProviderMachineName -FileNames $ExpectedErrorLogFiles -Filters $ExpectedErrorLogPattern.Filter

        It "Verify if able to read all log files" {
            $IsSuccess = @{$true="No";$false="Yes"}[$FileLogDetails.IsError]
            $IsSuccess | Should Be "Yes"
            #$FileLogDetails.IsError | Should Be $False
            $FileLogDetails.Output | Should Not Be $null
            $FileLogDetails.Output[0].FileLogs | Should Not Be $null
            $FileLogDetails.Output[0].FileLogs.Count | Should Be $ExpectedErrorLogFiles.Count
        }
        
        It "Verify if file '<FileName>' does not contain any '<Filter>' in past 7 days" -TestCases $ExpectedErrorLogFileDetails {
            param
            (
                $FileName,
                $Filter,
                $IgnoreFilter
            )
            $FileLogs = $FileLogDetails.Output[0].FileLogs | ? {$_.FileName -eq $FileName}
            $FileLogs | Should Not Be $null
            if($FileLogs.LogData -ne $null)
            {
                $ErrorsExist = $FileLogs.LogData | ? {$_ -notmatch $IgnoreFilter}                
                $datePattern = "\<(\d{2}\-\d{2}\-\d{4}\s\d{2}:\d{2}:\d{2}\.\d{3}?)\+\d{3}\>"
                $ErrorsWithLogDate = @($ErrorsExist | ? {$_ -match $datePattern})
                $ErrorsWithoutLogDate = @()
                $ErrorsWithoutLogDate += @($ErrorsExist | ? {$_ -notmatch $datePattern})
                if(($ErrorsWithLogDate -ne $null) -and ($ErrorsWithLogDate.Count -gt 0) -and ($ErrorsWithLogDate[0] -ne $null))
                {
                    foreach($ErrorWithLogDate in $ErrorsWithLogDate)
                    {
                        if($ErrorWithLogDate -match $datePattern)
                        {
                            $ErrorLogDate = [DateTime]($matches[1])
                            if($LogDate -ge (Get-Date).AddDays(-7))
                            {
                                $ErrorsWithoutLogDate += $ErrorWithLogDate
                            }
                        }
                        else
                        {
                            $ErrorsWithoutLogDate += $ErrorWithLogDate
                        }
                    }
                }
                $ErrorsWithoutLogDate.Count -eq 0 | Should Be $true
            }
        }        
    }

    if($InputParams.UpgradeDateTime -le [DateTime]::Now)
    {
        Context 'Check for any SMSExec crash dumps below upgrade' {

            $ProviderMachineName = $SiteServerName
            $ExpectedCrashDumpValues = $ExpectedValues["ExpectedCrashDumpValues"]
            $ExpectedRootFolder = $ExpectedCrashDumpValues["ExpectedRootFolder"]
            $Filter = $ExpectedCrashDumpValues["Filter"]
            $UpgradeDateTime = $InputParams.UpgradeDateTime
            $CrashDumpInfo = Get-LatestCrashDumpInfo -ComputerName $ProviderMachineName -CrashDumpPath $ExpectedRootFolder -UpgradeDateTime $UpgradeDateTime -Filter $Filter
            $TestInputs = @{ExpectedRootFolder = $ExpectedRootFolder;CrashDumpInfo=$CrashDumpInfo}
            ## Convert PSObject to Hashtable
            $ValidationTestInputs = @{}
            $CrashDumpInfo.Output.PSObject.Properties | % { $ValidationTestInputs[$_.Name] = $_.Value }

            It "Verify if crash dump root folder '<ExpectedRootFolder>' exists" -TestCases $TestInputs {
                param
                (
                    $ExpectedRootFolder,
                    $CrashDumpInfo
                )
                $IsSuccess = @{$true="No";$false="Yes"}[$CrashDumpInfo.IsError]
                $IsSuccess | Should Be "Yes"
                #$CrashDumpInfo.IsError | Should Be $false
                $CrashDumpInfo.Output | Should Not Be $null
                $CrashDumpInfo.Output.RootFolderExists | Should Be $true
            }

            It "Verify if latest crash dump folder exists - '<FolderName>'" -TestCases $ValidationTestInputs {
                param
                (
                    $CrashDumpFoldersExist,
                    $FolderName
                )
                $FolderName | Should Not Be $false
                $CrashDumpFoldersExist | Should Be $true
            }
        
            It "Verify if latest crash dump folder '<FolderName>' on '<LastWriteTime>' exists after upgrade: '<UpgradeDate>'" -TestCases $ValidationTestInputs {
                param
                (
                    $LastWriteTime,
                    $FolderName,
                    $LatestCrashDumpFolderExists,
                    $UpgradeDate
                )
                $LastWriteTime | Should Not Be $null
                $LatestCrashDumpFolderExists | Should Be $true
            }

        }
    }

    if($SiteCode -eq $PrimarySiteCode)
    {
        Context 'Check Site Component Status Messages for critical and warning messages' {

            $ExpectedComponentStatusMessageInputs = $ExpectedValues["ExpectedComponentStatusMessageInputs"]
            $SeverityLevels = $ExpectedComponentStatusMessageInputs["SeverityLevels"]
            $DaysOld = $ExpectedComponentStatusMessageInputs["DaysOld"]
            $IgnoreComponents = $ExpectedComponentStatusMessageInputs["IgnoreComponents"]
            $ExectedMinimumMessageCount = $ExpectedComponentStatusMessageInputs["ExpectedMinimumMessageCountPerComponent"]
            $InputTestSet = @()

            $ComponentStatusMessages = Get-ComponentStatusMessages -SQLServerName $SiteSQLServerName -SQLDBName $SiteSQLDBName -SiteCode $SiteCode -DaysOld $DaysOld -IgnoreComponents $IgnoreComponents

            It "Verify if able to pull site component status messages" {
                #$ComponentStatusMessages.IsError | Should Be $false
                $IsSuccess = @{$true="No";$false="Yes"}[$ComponentStatusMessages.IsError]
                $IsSuccess | Should Be "Yes"
            }

            if($ComponentStatusMessages.Output -ne $null)
            {

                foreach($SeverityLevel in $SeverityLevels)
                {
                    $ComponentMessages = $ComponentStatusMessages.Output | ? {$_.Severity -eq $SeverityLevel}
                    $MessagesByComponent = $ComponentMessages | Group Component
                    foreach($ComponentMessage in $MessagesByComponent)
                    {
                        $ComponentMessageTexts = @()
                        $ComponentMessageGroup = $ComponentMessage.Group | Sort TimeLogged -desc
                        $ComponentMessages = $ComponentMessageGroup[0..10]
                        for($i=0;$i-lt$ComponentMessages.Count;$i++)
                        {
                            $ComponentMessageTexts += "ModuleName: {0}; Severity: {1}; MessageID: {2};MachineName: {3}; Component: {4}; SiteCode: {5}; TimeLogged: {6}" -f $ComponentMessages[$i].ModuleName, $ComponentMessages[$i].Severity, $ComponentMessages[$i].MessageID, $ComponentMessages[$i].MachineName, $ComponentMessages[$i].Component, $ComponentMessages[$i].SiteCode, $ComponentMessages[$i].TimeLogged
                        }
                        $InputTestSet += @{SeverityLevel=$SeverityLevel;DaysOld=$DaysOld;ComponentName=$ComponentMessage.Name;MessageCount=$ComponentMessage.Count;Messages=($ComponentMessageTexts -join "`n");ExectedMinimumMessageCount=$ExectedMinimumMessageCount}
                    }
                }

                It "Verify if there are more than '<ExectedMinimumMessageCount>' site component messages with '<SeverityLevel>' in last '<DaysOld>' days for component '<ComponentName>'" -TestCases $InputTestSet {
                    param
                    (
                        $ExectedMinimumMessageCount,
                        $SeverityLevel,
                        $DaysOld,
                        $ComponentName,
                        $MessageCount,
                        $Messages
                    )
                    if($MessageCount -gt $ExectedMinimumMessageCount)
                    {
                        $Messages | Should Be $null
                    }
                    else
                    {
                        $MessageCount -le $ExectedMinimumMessageCount | Should Be $true
                    }
                }
            }
            else
            {
                It "Verify there are no site component status messages" {
                    $ComponentStatusMessages.Output | Should Be $null
                }
            }

        }
    }
    else
    {
        Context 'Check Site Component Status Messages for critical and warning messages' {

            $ExpectedComponentStatusMessageInputs = $ExpectedValues["ExpectedComponentStatusMessageInputs"]
            $SeverityLevels = $ExpectedComponentStatusMessageInputs["SeverityLevels"]
            $DaysOld = $ExpectedComponentStatusMessageInputs["DaysOld"]
            $IgnoreComponents = $ExpectedComponentStatusMessageInputs["IgnoreComponents"]
            $ExectedMinimumMessageCount = $ExpectedComponentStatusMessageInputs["ExpectedMinimumMessageCountPerComponent"]
            $InputTestSet = @()
            
            #$ComponentStatusMessages = Get-ComponentStatusMessages -SQLServerName $SiteSQLServerName -SQLDBName $SiteSQLDBName -SiteCode $SiteCode -DaysOld $DaysOld -IgnoreComponents $IgnoreComponents
            foreach($SeverityLevel in $SeverityLevels)
            {
                #$ComponentMessages = $ComponentStatusMessages.Output | ? {$_.Severity -eq $SeverityLevel}
                #$MessagesByComponent = $ComponentMessages | Group Component
                #foreach($ComponentMessage in $MessagesByComponent)
                #{
                    $InputTestSet += @{SeverityLevel=$SeverityLevel;DaysOld=$DaysOld;ExectedMinimumMessageCount=$ExectedMinimumMessageCount}
                #}
            }    
            <#
            
            It "Verify if able to pull site component status messages" -Skip {
                $ComponentStatusMessages.IsError | Should Be $false                        
            }
            #>
            It "Verify if there are more than '<ExectedMinimumMessageCount>' site component messages with '<SeverityLevel>' in last '<DaysOld>' days" -TestCases $InputTestSet -Skip {
                param
                (
                    $ExectedMinimumMessageCount,
                    $SeverityLevel,
                    $DaysOld
                )
            }

        }
    }

    if($InputParams.UpgradeDateTime -le [DateTime]::Now)
    {
        Context 'Monitor the Inbox Backlogs and see if they are processing at the normal rate' {

            $ProviderMachineName = $SiteServerName
            $ExpectedInboxBoxAndOutBoxLogCheckParams = $ExpectedValues["ExpectedInboxBoxAndOutBoxLogCheckParams"]
            $UpgradeDateTime = $InputParams.UpgradeDateTime
            $InboxOutBoxMonLogs = Get-InboxAndOutBoxLogs -ComputerName $ProviderMachineName -ExpectedInboxBoxAndOutBoxLogCheckParams $ExpectedInboxBoxAndOutBoxLogCheckParams -UpgradeDate $UpgradeDateTime
            $InboxOutBoxMonLogGroup = $InboxOutBoxMonLogs.Output | Group LogLine
            $ValidationTests = @()
            foreach($InboxOutBoxMonLog in $InboxOutBoxMonLogGroup)
            {
                $LogLine = $InboxOutBoxMonLog.Name
                $LogsExceedingThreshold = ($InboxOutBoxMonLog.Group | ? {$_.LogValue -gt $_.Threshold}).LogOutput
                $ValidationTests += @{LogLine = $LogLine; LogsExceedingThreshold = $LogsExceedingThreshold}
            }

            if(($ValidationTests -ne $null) -and ($ValidationTests.Count -gt 0) -and ($ValidationTests[0] -ne $null))
            {
                It "Verify File count for '<LogLine>'" -TestCases $ValidationTests {
                    param
                    (
                        $LogLine,
                        $LogsExceedingThreshold
                    )
                    $LogsExceedingThreshold | Should Be $null
                }
            }

        }

    }

    Context 'Monitor the BADMIF folders to ensure all MIFs are not moved there' {
        $ProviderMachineName = $SiteServerName
        $ExpectedBadMIFFileParams = $ExpectedValues["ExpectedBadMIFFileParams"]
        $FolderName = $ExpectedBadMIFFileParams.FolderName
        if($FolderName.Contains(":"))
        {
            $FolderName = "\\{0}\{1}" -f $ProviderMachineName, ($FolderName.Replace(":","$"))
        }
        $BADMIFFiles = @(Get-ChildItem $FolderName -ErrorAction SilentlyContinue)
        $TestCase = @{FolderName=$FolderName;MIFFileCount=$BADMIFFiles.Count}

        It "Verify there are no BAD MIF files in location '<FolderName>'" -TestCases $TestCase {
            param
            (
                $FolderName,
                $MIFFileCount
            )
            $MIFFileCount -eq 0 | Should Be $true
        }
    }
    
}#describePostUpgradeHierarchyHealthValidation

Describe 'Connectivity and Access Validation' {

    Context 'Verify SQL connectivity locally and remotely' {
        $SQLServerName = $SiteSQLServerName
        $SQLDBName = "master"
        $SQLConnectionResult = Test-SQLServerConnection -SQLServerName $SQLServerName -DatabaseName $SQLDBName
        $TestCase = @{ServerName = $SQLConnectionResult.Output.ServerName}

        It "Verify SQL connectivity locally" -Skip {
        }

        It "Verify there are no errors connecting SQL Server remotely" {
            #$SQLConnectionResult.IsError | Should Be $false
            $IsSuccess = @{$true="No";$false="Yes"}[$SQLConnectionResult.IsError]
            $IsSuccess | Should Be "Yes"
        }

        It "Verify able to connect to Site SQL Server '<ServerName>' remotely" -TestCases $TestCase {
            param
            (
                $ServerName
            )
            $ServerName | Should Not Be $null
        }
    }

    if($SiteCode -ne $PrimarySiteCode)
     {
        Context 'Check access to CM12 Console locally and remotely' {

            It "Verify access to CM12 Console locally" -Skip {
            }

            It "Verify access to CM12 Console remotely" -Skip {
            }

        }
    

    Context 'Verify if required security groups are provisioned with correct access to shares' {
        
        It "Verify if required security groups are provisioned with correct access to shares. " -Skip {
        }
    }
    }

    Context 'Verify all SMS objects accessible using account that is not local Admin' {
        $ProviderMachineName = $SiteServerName
        $ExpectedSMSObjectParams = $ExpectedValues["ExpectedSMSObjectsParams"]
        $RootFolders = $ExpectedSMSObjectParams.RootFolders[$QCEnvironment]
        foreach($RootFolder in $RootFolders)
        {
            if($RootFolder.Contains(":"))
            {
                $RootCheckFolder = "\\{0}\{1}" -f $ProviderMachineName, $RootFolder.Replace(":","$")
            }
            else
            {
                $RootCheckFolder = $RootFolder
            }
            if(Test-Path $RootCheckFolder -ErrorAction SilentlyContinue)
            {
                $SMSObjectFolders = @(Get-ChildItem $RootCheckFolder -Directory -ErrorAction SilentlyContinue)
                break;
            }
        }
        $TestCase = @{FolderName=$RootFolder;SMSObjectCount=$SMSObjectFolders.Count}

        It "Verify SMS objects exist under folder '<FolderName>'" -TestCases $TestCase {
            param
            (
                $FolderName,
                $SMSObjectCount
            )
            $SMSObjectCount -gt 0 | Should Be $true
        }
    }
       

    if($InputParams.UpgradeDateTime -le [DateTime]::Now)
    {

        Context 'Check SQL Error logs for any critical errors' {
                $SQLServerName = $SiteSQLServerName
                $ExpectedSQLErrorLogsParams = $ExpectedValues["ExpectedSQLErrorLogsParams"]
                $UpgradeDateTime = $InputParams.UpgradeDateTime
                $SQLErrorLogs = Get-SQLServerErrorLogs -SQLServerName $SQLServerName -LogFrom $UpgradeDateTime -IgnorePattern $ExpectedSQLErrorLogsParams.IgnorePattern

                It "Verify able to pull SQL server logs" {
                    #$SQLErrorLogs.IsError | Should Be $false           
                    $IsSuccess = @{$true="No";$false="Yes"}[$SQLErrorLogs.IsError]
                    $IsSuccess | Should Be "Yes"
                }

                It "Verify there are no more than '<ErrorThreshold>' critical errors found from SQL logs since upgrade" -TestCases $ExpectedSQLErrorLogsParams {
                    param
                    (
                        $ErrorThreshold
                    )
                    if($SQLErrorLogs.Output -eq $null)
                    {
                        $SQLErrorLogs.Output | Should Be $null
                    }
                    else
                    {
                        if($SQLErrorLogs.OutPut.Count -le $ErrorThreshold)
                        {
                            $SQLErrorLogs.OutPut.Count -le $ErrorThreshold | Should Be $true
                        }
                        else
                        {
                            $SQLErrorLogs.OutPut[0..($SQLErrorLogs.OutPut.Count-1)].Text | Should Be $null
                        }
                    }
                }
            }

        Context 'Check Events for any critical errors' {
            $ProviderMachineName = $SiteServerName
            $ExpectedEventLogParams = $ExpectedValues["ExpectedEventLogParams"]
            $UpgradeDateTime = $InputParams.UpgradeDateTime
            $TestCases = @()
            foreach($LogName in $ExpectedEventLogParams.LogNames)
            {
                $EventLogs = Get-EventLogData -ComputerNames $ProviderMachineName -LogName $LogName -EntryType Error -After $UpgradeDateTime
                $EventLogOutput = $EventLogs.Output[0].EventLogs
                if($ExpectedEventLogParams.IgnorePattern)
                {
                    $EventLogOutput = $EventLogOutput | ? {$_.Message -notmatch $ExpectedEventLogParams.IgnorePattern}
                }
                $TestCases += @{LogName=$LogName;IsError=$EventLogs.IsError;LogMessages=$EventLogOutput.Message}
            }

            It "Check error events from '<LogName>' event log post upgrade" -TestCases $TestCases {
                param
                (
                    $LogName,
                    $IsError,
                    $LogMessages
                )
                $IsSuccess = @{$true="No";$false="Yes"}[$IsError]
                $IsSuccess | Should Be "Yes"
                #$IsError | Should Be $false
                $LogMessages | Should Be $null
            }
        }
    }

}#describeConnectivityandAccessValidation

Describe 'Hierarchy Functionality Validation' {

    if($SiteCode -eq $PrimarySiteCode)
    {
        Context 'Trigger WSUS Sync on Central Site and Monitor the Sync progress across all sites' {
            $WSUSSyncStatus = Get-WSUSSyncStatus -SiteCode $SiteCode -ProviderServerName $SiteServerName
            $TestSet = @($WSUSSyncStatus.Output)

            It 'Verify able to get WSUS Sync status on Central Site' {
                $IsSuccess = @{$true="No";$false="Yes"}[$WSUSSyncStatus.IsError]
                $IsSuccess | Should Be "Yes"
                #$WSUSSyncStatus.IsError | Should Be $false
            }

            It "Verify latest WSUS Sync status on site '<SiteCode>' occurred at '<LastSync>' and last sync version is '<SyncCatalogVersion>' and Sync status is '<LastSyncState>' and link replication status is '<ReplicationLinkStatus>'" -TestCases $TestSet {
                param
                (
                    $SiteCode,
                    $LastSync,
                    $SyncCatalogVersion,
                    $LastSyncState,
                    $ReplicationLinkStatus
                )
                $LastSync | Should Not Be $null
                $SyncCatalogVersion | Should Not Be $null
                $LastSyncState | Should Be "Completed"
                $ReplicationLinkStatus | Should Be "Active"
            }

        }    

        Context 'Distribute test package and monitor package replication status.' {
            
                              
                <#$Testset = Get-Package -PrimarySiteCode $PrimarySiteCode -PrimarySiteServer $PrimarySiteServerName -SiteCode $SiteCode -DistributionPointName $DistributionPointName -DistributionPointGroupName $DistributionPointGroupName -PackageFolderName $PackageFolderName -PackageFolderPath $PackageFolderPath -SourcePath $SourcePath
                $Testset = $Testset.Output#>
                           
                It 'Verify able create test package' -Skip  {
                }

                It "Verify able to distribute test package" -Skip  {
                }
          
           
        }
    }

    Context 'Validate the SUP role configuration' {
        
        $SUPServers = Get-SUPServerAndUrls -PrimarySiteCode $PrimarySiteCode -PrimarySiteServer $PrimarySiteServerName -SiteCode $SiteCode
        $Testset = $SUPServers.Output
        if($Testset -ne $null)
        {
        It "Validate the SUP role configuration '<wuident>'" -TestCases $Testset  {
            param
            (
                $ServerName,
                $wuident
            )
            $Response = Invoke-WebRequest -Uri $wuident
            $Response.StatusCode | Should Be 200
        }

        It 'Verify ClientWebService <client>' -TestCases $Testset  {
            param
            (
                $ServerName,
                $client
            )
            $Response = Invoke-WebRequest -Uri $client
            $Response.StatusCode | Should Be 200
        }

        It "Verify SimpleAuthWebService <SimpleAuth>" -TestCases $Testset {
            param
            (
                $ServerName,
                $SimpleAuth
            )
            $Response = Invoke-WebRequest -Uri $SimpleAuth
            $Response.StatusCode | Should Be 200
        }

        It "Verify content url <content>" -TestCases $Testset {
            param
            (
                $ServerName,
                $content
            )
            $Response = Invoke-WebRequest -Uri $content
            $Response.StatusCode | Should Be 200
        }
        }
    }

    if($SiteCode -eq $PrimarySiteCode)
    {
        Context 'Validate Site to Site communications' {

            $DBRepolicationStatus = Get-ReplicationStatus -SiteCode $SiteCode -ProviderServerName $SiteServerName

            It 'Verify able to get database replication status' {
                $IsSuccess = @{$true="No";$false="Yes"}[$DBRepolicationStatus.IsError]
                $IsSuccess | Should Be "Yes"
                #$DBRepolicationStatus.IsError | Should Be $false
                $DBRepolicationStatus.Output | Should Not Be $null
            }

            It "Verify Parent - '<ParentSite> - (<ParentSiteState>)' to Child '<ChildSite> - (<ChildSiteState>)' site replication status is '<LinkStatus>'" -TestCases $DBRepolicationStatus.Output.SiteReplicationStatus {
                param
                (
                    $ParentSite,
                    $ParentSiteState,
                    $ChildSite,
                    $ChildSiteState,
                    $LinkStatus
                )
                $LinkStatus | Should Be "Link Active"
                $ParentSiteState | Should Be "Replication Active"
                $ChildSiteState | Should Be "Replication Active"
            }
        
            It "Verify global synchronization time for Parent '(<ParentSite> - <ParentToChildGlobalSyncTime>)' to Child '(<ChildSite> - <ChildToParentGlobalSyncTime>)' and global data initialization percentage '<InitializationPercentage>'" -TestCases $DBRepolicationStatus.Output.SiteGlobalSyncStatus {
                param
                (
                    $ParentSite,
                    $ParentToChildGlobalSyncTime,
                    $ChildSite,
                    $ChildToParentGlobalSyncTime,
                    $InitializationPercentage
                )
                $ParentToChildGlobalSyncTime | Should Not Be $null
                $ChildToParentGlobalSyncTime | Should Not Be $null
                $InitializationPercentage | Should Not Be $null
            }

        }
    }

    if($SiteCode -eq $PrimarySiteCode)
    {
        Context 'Validate if component status messages not giving any SUP component errors' {
        
            $ExpectedComponentStatusMessageInputs = $ExpectedValues["ExpectedSUPComponentStatusMessageInputs"]
            $SeverityLevels = $ExpectedComponentStatusMessageInputs["SeverityLevels"]
            $DaysOld = $ExpectedComponentStatusMessageInputs["DaysOld"]
            $IgnoreComponents = $ExpectedComponentStatusMessageInputs["IgnoreComponents"]
            $ExectedMinimumMessageCount = $ExpectedComponentStatusMessageInputs["ExpectedMinimumMessageCountPerComponent"]
            $InputTestSet = @()

            $ComponentStatusMessages = Get-ComponentStatusMessagesForSUP -SQLServerName $SiteSQLServerName -SQLDBName $SiteSQLDBName -SiteCode $SiteCode -SUPMachineNameSubstring $SUPMachineNameSubstring -DaysOld $DaysOld -IgnoreComponents $IgnoreComponents

            It "Verify if able to pull site component status messages for SUP" {
                #$ComponentStatusMessages.IsError | Should Be $false                        
                $IsSuccess = @{$true="No";$false="Yes"}[$ComponentStatusMessages.IsError]
                $IsSuccess | Should Be "Yes"
            }

            if($ComponentStatusMessages.Output -ne $null)
            {

                foreach($SeverityLevel in $SeverityLevels)
                {
                    $ComponentMessages = $ComponentStatusMessages.Output | ? {$_.Severity -eq $SeverityLevel}
                    $MessagesByComponent = $ComponentMessages | Group Component
                    foreach($ComponentMessage in $MessagesByComponent)
                    {
                        $ComponentMessageTexts = @()
                        $ComponentMessageGroup = $ComponentMessage.Group | Sort TimeLogged -desc
                        $ComponentMessages = $ComponentMessageGroup[0..10]
                        for($i=0;$i-lt$ComponentMessages.Count;$i++)
                        {
                            $ComponentMessageTexts += "ModuleName: {0}; Severity: {1}; MessageID: {2};MachineName: {3}; Component: {4}; SiteCode: {5}; TimeLogged: {6}" -f $ComponentMessages[$i].ModuleName, $ComponentMessages[$i].Severity, $ComponentMessages[$i].MessageID, $ComponentMessages[$i].MachineName, $ComponentMessages[$i].Component, $ComponentMessages[$i].SiteCode, $ComponentMessages[$i].TimeLogged
                        }
                        $InputTestSet += @{SeverityLevel=$SeverityLevel;DaysOld=$DaysOld;ComponentName=$ComponentMessage.Name;MessageCount=$ComponentMessage.Count;Messages=($ComponentMessageTexts -join "`n");ExectedMinimumMessageCount=$ExectedMinimumMessageCount}
                    }
                }


                It "Verify if there are more than '<ExectedMinimumMessageCount>' site component messages with '<SeverityLevel>' in last '<DaysOld>' days for component '<ComponentName>'" -TestCases $InputTestSet {
                    param
                    (
                        $ExectedMinimumMessageCount,
                        $SeverityLevel,
                        $DaysOld,
                        $ComponentName,
                        $MessageCount,
                        $Messages
                    )
                    $MessageCount -le $ExectedMinimumMessageCount | Should Be $true
                }
            }
            else
            {
                It "Verify there are no component status messages for SUP" {
                    $ComponentStatusMessages.Output | Should Be $null                        
                }
            }
        
        }
    }
    else
    {
        Context 'Validate if component status messages not giving any SUP component errors' {
        
            $ExpectedComponentStatusMessageInputs = $ExpectedValues["ExpectedSUPComponentStatusMessageInputs"]
            $SeverityLevels = $ExpectedComponentStatusMessageInputs["SeverityLevels"]
            $DaysOld = $ExpectedComponentStatusMessageInputs["DaysOld"]
            $IgnoreComponents = $ExpectedComponentStatusMessageInputs["IgnoreComponents"]
            $ExectedMinimumMessageCount = $ExpectedComponentStatusMessageInputs["ExpectedMinimumMessageCountPerComponent"]
            $InputTestSet = @()

            #$ComponentStatusMessages = Get-ComponentStatusMessagesForSUP -SQLServerName $SiteSQLServerName -SQLDBName $SiteSQLDBName -SiteCode $SiteCode -SUPMachineNameSubstring $SUPMachineNameSubstring -DaysOld $DaysOld -IgnoreComponents $IgnoreComponents
            foreach($SeverityLevel in $SeverityLevels)
            {
                #$ComponentMessages = $ComponentStatusMessages.Output | ? {$_.Severity -eq $SeverityLevel}
                #$MessagesByComponent = $ComponentMessages | Group Component
                #foreach($ComponentMessage in $MessagesByComponent)
                #{
                    $InputTestSet += @{SeverityLevel=$SeverityLevel;DaysOld=$DaysOld;ExectedMinimumMessageCount=$ExectedMinimumMessageCount}
                #}
            }        

            It "Verify if there are more than '<ExectedMinimumMessageCount>' site component messages with '<SeverityLevel>' in last '<DaysOld>' days" -TestCases $InputTestSet -Skip {
                param
                (
                    $ExectedMinimumMessageCount,
                    $SeverityLevel,
                    $DaysOld
                )
            }
        
        }
    }

    if($SiteCode -eq $PrimarySiteCode)
    {

       Context 'Create a collection with direct membership or query rule membership & Verify if it propogates to all child Primary Sites' {
            $Computers = $ComputerName1, $ComputerName2
            $colResult = Create-DirectMembershipCollection -PrimarySiteCode $PrimarySiteCode -PrimarySiteServer $PrimarySiteServerName -SiteCode $SiteCode -Computers $Computers -LimitingCollectionName $LimitingCollectionName -CollectionFolderName $CollectionFolderName -CollectionFolderPath $CollectionFolderPath
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

    }

    Context 'Verify if custom extensions done are presisted after restoration of MOF ' {
        
        It 'Verify if custom extensions done are presisted after restoration of MOF ' -Skip {
        }
    }
        
}#describeHierarchyFunctionalityValidation

Describe 'Known Issues Validation' {

    Context 'Verify if AD publishing to the forest is happening successfully and the data is visibile from all domains' {

        It 'Verify if AD publishing to the forest is happening successfully and the data is visibile from all domains' -Skip {
        }
    }
    if($SiteCode -ne $PrimarySiteCode)
    {
    Context 'Verify if the ConfigMgr 2012 SSRS Reports are available and intact' {

        It 'Verify if the ConfigMgr 2012 SSRS Reports are available and intact' -Skip {
        }

    }
    }


}#describeKnownIssuesValidation

Describe 'Site Server availability Validation' {

    if($SiteArtifacts.Site -ne "Secondary") {
        Context 'Verify SQL Jobs' {
            $SQLServerName = $SiteSQLServerName
            $SQLServerDetails = Get-SQLServerDetails -ServerName $SQLServerName
            $SqlJobDetails = $SQLServerDetails.Output.SqlJobDetails
            $ExpectedSQLJobStatus = $ExpectedValues["ExpectedSQLJobStatus"]
            $SQLServerTestCases = @{SQLServerName=$SQLServerName;IsError=$SQLServerDetails.IsError;Output=$SQLServerDetails.Output;SqlJobDetails=$SqlJobDetails}
            $JobTestCases = @()
            if(($SqlJobDetails -ne $null) -and ($SqlJobDetails.Rows -ne $null) -and ($SqlJobDetails.Rows.Count -gt 0))
            {
                $SQLRecords = $SqlJobDetails.Rows
                foreach($ExpectedJobName in $ExpectedSQLJobStatus.JobNames)
                {
                    $SQLRecord = $SQLRecords | ? {$_.JobName -eq $ExpectedJobName}
                    if($SQLRecord -ne $null)
                    {
                        $JobTestCases += @{SQLServerName=$SQLServerName;JobName=$SQLRecord.JobName;ExpectedJobEnabledStatus=$ExpectedSQLJobStatus.ExpectedEnabledStatus;ActualJobEnabledStatus=$SQLRecord.IsEnabled}
                    }
                    else
                    {
                        $JobTestCases += @{SQLServerName=$SQLServerName;JobName=$ExpectedJobName;ExpectedJobEnabledStatus=$ExpectedSQLJobStatus.ExpectedEnabledStatus;ActualJobEnabledStatus="Not found!"}
                    }
                }
            }

            It "Verify able to connect to site SQL server '<SQLServerName>'" -TestCases $SQLServerTestCases {
                param
                (
                    $SQLServerName,
                    $IsError,
                    $Output,                
                    $SqlJobDetails
                )
                $IsSuccess = @{$true="No";$false="Yes"}[$IsError]
                $IsSuccess | Should Be "Yes"
                #$IsError | Should Be $false
                $Output | Should Not Be $null
                $SqlJobDetails | Should Not Be $null
            }
            if(($JobTestCases -ne $null) -and ($JobTestCases.Count -gt 0) -and ($JobTestCases[0] -ne $null))
            {
                It "Verify SQL Job '<JobName>' is enabled on '<SQLServerName>'" -TestCases $JobTestCases {
                    param
                    (
                        $SQLServerName,
                        $JobName,
                        $ExpectedJobEnabledStatus,
                        $ActualJobEnabledStatus
                    )
                    $ActualJobEnabledStatus | Should Be $ExpectedJobEnabledStatus
                }
            }

        }
    }

    Context 'Check the client on  is the same version of the Build' {

        $SiteServerInfo = Get-SiteServerInfo -PrimarySiteCode $PrimarySiteCode -SiteCode $SiteCode -PrimarySiteServerName $PrimarySiteServerName -ProviderMachineName $SiteServerName

            It "Verify if connected to site - '<SiteCode>'" -TestCases @{SiteCode=$InputParams.SiteCode} {
                param
                (
                    $SiteCode
                )
                #$SiteServerInfo.IsError | Should Be $False
                $IsSuccess = @{$true="No";$false="Yes"}[$SiteServerInfo.IsError]
                $IsSuccess | Should Be "Yes"
                $SiteServerInfo.Output.ConnectionInfo.SiteCode | Should Be $SiteCode
                $SiteServerInfo.Output.ConnectionInfo.ProviderMachineName | Should Not Be $null
            }

            It "Verify if CM client Version is '<ExpectedClientVersion>'" -TestCases @{ExpectedClientVersion=$InputParams.ExpectedClientVersion} {
                param
                (
                    $ExpectedClientVersion
                )
                $SiteServerInfo.Output.SiteDetails["Version"].StringValue | Should Be $ExpectedClientVersion
                #$SiteServerInfo.Output.SiteDetails["Version"].StringValue | Should Be $SiteServerInfo.Output.UpdateStatus[0].ClientVersion
                #$SiteServerInfo.Output.SiteDetails["Version"].StringValue | Should Be $SiteServerInfo.Output.SiteProperties.'Full Version'
            }

            It "Verify if site is upgraded to latest build '<ExpectedUpgradeName>'" -TestCases @{ExpectedUpgradeName = $InputParams.ExpectedUpgradeName} {
                param
                (
                    $ExpectedUpgradeName
                )
                $SiteServerInfo.Output.UpdateStatus | Should Not Be $null
                $SiteServerInfo.Output.UpdateStatus[0] | Should Not Be $null
                $SiteServerInfo.Output.UpdateStatus[0].Name | Should Be $ExpectedUpgradeName
                #$SiteServerInfo.Output.UpdateStatus[0].Installed | Should Be $true
            }
    }
    if($SiteCode -ne $PrimarySiteCode)
    {
        Context 'check the custom reports and SSRS is working fine' {

            It 'check the custom reports and SSRS is working fine' -Skip {
            }
        }
    }
}


if($SiteCode -eq $PrimarySiteCode)
{

    Describe 'Cloud Services Validation' {

        Context 'Azure Services Validation' {

            It "Verify Connection Status for 'ConfigMgr Client' service" -Skip {
            }

            It "Verify last sync status of 'MSFB' service" -Skip {
            }

            It 'Verify Active Direvtory User Descovery sync' -Skip {
            }

        }

        Context 'Verify Co-ManagementSetting Prod Availibility Status must be enabled' {

            It 'Verify Co-ManagementSetting Prod Availibility Status must be enabled' -Skip {
            }

        }

        Context 'Verify Azure Active Directory Tenants' {

            It 'Verify Azure Active Directory Tenants' -Skip {
            }
        }

        Context 'Verify Cloud Distribution Points Status' {

            It 'Verify Cloud Distribution Points Status' -Skip {
            }
        }

        Context 'Verify Cloud Management Gateway status' {

            It 'Verify Start Service option is disabled' -Skip {
            }

            It "Verify Service 'Connection Point' status is Connected" -Skip {
            }
        }    
    
    }#describeCloudServicesValidation

}

if($SiteCode -ne $PrimarySiteCode)
{
    Describe 'Site specific validation' {        

        $ScanResults = Get-ScanCmpltdCount -SiteSQLServerName $SiteSQLServerName -SiteSQLDBName $SiteSQLDBName
        $Testset = $null
        $Testset = $ScanResults.Output
        if(($Testset -ne $null) -and ($Testset.Count -gt 0) -and ($Testset[0] -ne $null)) {
            Context 'Validate if client are scanning successfully using HLB url in IIS logs.' {           

               It "Validate if total clients scanned '<ScanResult>' is more than '<UnexpectedScanCount>' after running query on SQL server '<SQLServerName>'" -TestCases $Testset {
                    param
                    (
                        $SQLServerName,
                        $ScanResult,
                        $UnexpectedScanCount                    
                    )
                    $ScanResult | Should Not Be $UnexpectedScanCount
               }
            }
        }

        $MPServers = Get-MPServers -PrimarySiteCode $PrimarySiteCode -PrimarySiteServer $PrimarySiteServerName -SiteCode $SiteCode
        $Testset = $null
        $Testset = $MPServers.Output
        if($MPServers.IsError -eq $true)
        {
            Context 'Validate the MP role and client folder is updated with the new client bits' {


                It "Check MP role on MP Servers" -Skip   {
                }
                It 'Check client folder is updated with the new client bits' -Skip {
                }
            }
        }
        elseif(($Testset -ne $null) -and ($Testset.Count -gt 0) -and ($Testset[0] -ne $null)) 
        {
            Context 'Validate the MP role and client folder is updated with the new client bits' {


                It "Check MP role on Server '<ServerName>'" -TestCases $Testset   {
                param
                    (
                        $SiteCode,
                        $ServerName
                    
                    )
                    $ServerName | Should Not Be $null

                }
                It 'Check client folder is updated with the new client bits' -Skip {
                }
            }
        }
        
        $ExpectedMPApplicationPools = $ExpectedValues.ExpectedMPApplicationPools
        $AppPools = Get-AppPools -PrimarySiteCode $PrimarySiteCode -PrimarySiteServer $PrimarySiteServerName -SiteCode $SiteCode -ExpectedAppPoolNames $ExpectedMPApplicationPools
        $Testset = $null
        $Testset = $AppPools.Output
        if($AppPools.IsError -eq $true)
        {
            Context 'Verify if Application Pools on Management Points are not crashing' {            

                It "Verify if Application Pool status on MP" -Skip {
                }
            }
        }
        elseif(($Testset -ne $null) -and ($Testset.Count -gt 0) -and ($Testset[0] -ne $null)) 
        {
            Context 'Verify if Application Pools on Management Points are not crashing' {            

                It "Verify if Application Pool '<PoolName>' on server '<MPServer>' is '<ExpectedState>'" -TestCases $Testset {
                    param
                    (
                        $PoolName,
                        $PoolState,
                        $MPServer,
                        $ExpectedState                    
                    )
                    $PoolState | Should Be $ExpectedState
                }
            }
        }

        Context 'Verify if the Application Catalog is working' {

            It 'Verify if the Application Catalog is working' -Skip {
            }
        }

        $ExchangeServers = Get-ExchangeConnectorServer -PrimarySiteCode $PrimarySiteCode -PrimarySiteServer $PrimarySiteServerName -SiteCode $SiteCode
        $Testset =$null
        $Testset = $ExchangeServers.Output
        if($ExchangeServers.IsError -eq $true)
        {
            Context 'Check Exchange connector' {
            

                It "Check Exchange server Url " -Skip {
                }

                It "Check Exchange serverType" -Skip {
                }
            }
        }
        elseif(($Testset -ne $null) -and ($Testset.Count -gt 0) -and ($Testset[0] -ne $null))
        {
        
            Context 'Check Exchange connector' {
            

                It "Check Exchange server Url '<ExchangeServer>'"  -TestCases $Testset {
                param
                    (
                        $SiteCode,
                        $ExchangeServer
                    
                    )
                    $ExchangeServer | Should Not Be $null
                }

                It "Check Exchange serverType '<serverType>'"  -TestCases $Testset {
                param
                    (
                        $SiteCode,
                        $serverType
                    
                    )
                    $serverType | Should Not Be $null
                }
            }
        }

        $FSPServers = Get-FSPServers -PrimarySiteCode $PrimarySiteCode -PrimarySiteServer $PrimarySiteServerName -SiteCode $SiteCode
        $Testset =$null
        $Testset = $FSPServers.Output
        if($FSPServers.IsError -eq $true)
        {
            Context 'Check FSP role' {


                It "Verify FSP role is intstall on FSP servers" -Skip  {
                }
            }
        }
        elseif(($Testset -ne $null) -and ($Testset.Count -gt 0) -and ($Testset[0] -ne $null))
        {

            Context 'Check FSP role' {


                It "Verify FSP role is intstall on Server '<ServerName>'" -TestCases $Testset  {
                 param
                    (
                        $SiteCode,
                        $ServerName
                    
                    )
                    $ServerName | Should Not Be $null
                }
            }
        }
        
        

        Context 'Check the client on MPs and Appcatlog is the same version of the Build' {

            It 'Check the client on MPs and Appcatlog is the same version of the Build' -Skip {
            }
        }

        $DMPServers = Get-DMPServers -PrimarySiteCode $PrimarySiteCode -PrimarySiteServer $PrimarySiteServerName -SiteCode $SiteCode
        $Testset =$null
        $Testset = $DMPServers.Output
        if($DMPServers.IsError -eq $true)
        {
            Context 'Check DMP Role/Enrolement role' {


                It "Verify DMP Role/Enrolement role is install on FSP servers" -Skip {
                }

            }
        }
        elseif(($Testset -ne $null) -and ($Testset.Count -gt 0) -and ($Testset[0] -ne $null))
        {
         
        Context 'Check DMP Role/Enrolement role' {


            It "Verify DMP Role/Enrolement role is install on Server '<ServerName>'" -TestCases $Testset  {
            param
                (
                    $SiteCode,
                    $ServerName
                    
                )
                $ServerName | Should Not Be $null
             }
           }
        }

    }
}