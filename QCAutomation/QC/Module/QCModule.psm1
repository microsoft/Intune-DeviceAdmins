## Standard result object from any function in this module
function New-ResultObject {
    return New-Object PSObject -Property @{Output = $null; IsError = $true; Logs = @()}
}

function Connect-SiteServer {
    param
    (
        $SiteCode,
        $ProviderMachineName
    )
    $returnObj = New-ResultObject
    try
    {
        $global:originalLocation = Get-Location

        # Uncomment the line below if running in an environment where script signing is 
        # required.
        #Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

        # Customizations
        $initParams = @{}
        #$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
        #$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

        # Do not change anything below this line

        # Import the ConfigurationManager.psd1 module
        if((Get-Module ConfigurationManager) -eq $null) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
        }

        # Connect to the site's drive if it is not already present
        if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
        }

        # Set the current location to be the site code.
        Set-Location "$($SiteCode):\" @initParams
        $returnObj.IsError = $false
        $returnObj.Output = New-Object PSObject -Property @{SiteCode=$SiteCode;ProviderMachineName=$ProviderMachineName}
    }
    catch [System.Exception]
    {
        Disconnect-SiteServer
        $returnObj.Logs += "Error while connecting to Site server: [$SiteCode]: [$($_.Exception.ToString())]"
    }
    return $returnObj
}

function Disconnect-SiteServer {
    if($global:originalLocation)
    {
        Set-Location $global:originalLocation
    }
}

function Get-ComputerDomain {
    param
    (
        $ComputerName
    )
    return (Get-WmiObject -ComputerName $ComputerName -Class Win32_ComputerSystem).Domain
}

function Get-SQLClusterName {
    param
    (
        $SQLServerNames
    )
    if($SQLServerNames.Count -eq 1)
    {
        return $SQLServerNames[0]
    }
    foreach($SQLServerName in $SQLServerNames)
    {
        try
        {
            $clusterName = (Invoke-Command -ComputerName $SQLServerName -ScriptBlock {Invoke-Sqlcmd -ServerInstance $env:COMPUTERNAME -Database "master" -Query "Select dns_name From sys.availability_group_listeners" -QueryTimeout 15 -ConnectionTimeout 30} -ErrorAction SilentlyContinue).dns_name
            if($clusterName) 
            {
                $clusterName = ("{0}.{1}" -f $clusterName, $env:USERDNSDOMAIN)
                break;
            }            
        }
        catch [System.Exception]
        {
            continue;
        }
    }
    if(!$clusterName)
    {
        ## The following code is not a standard logic, it is created to avoid hardcoding SQL cluster name as of now.
        foreach($SQLServerName in $SQLServerNames)
        {
            $SQLServerNameParts = $SQLServerName.Split(".")
            if($SQLServerNameParts[0]  -match "(01|02)$")
            {
                $ClusterName = $SQLServerNameParts[0] -replace "(01|02)$", "L"
                for($i=1;$i-lt$SQLServerNameParts.count;$i++)
                {
                    $ClusterName += ".{0}" -f $SQLServerNameParts[$i]
                }
                break;
            }
        }        
    }
    return $ClusterName
}

function Get-AllSiteArtifacts {
    param
    (
        $CentralSiteDetails
    )
    $AllSites = @()
    $SiteSQLServers = @()
    $SiteSUPServers = @()
    try
    {
        $void = Connect-SiteServer -SiteCode $CentralSiteDetails.SiteCode -ProviderMachineName $CentralSiteDetails.SiteServer    
        $AllSiteDetails = Get-CMSite
    
        $AllSiteSQLServers = Get-CMSiteRole -RoleName "SMS SQL Server" -AllSites | Select NetworkOSPath, SiteCode
        foreach($SiteSQLServer in $AllSiteSQLServers)
        {
            $SiteSQLServers += New-Object PSObject -Property @{SiteCode = $SiteSQLServer.SiteCode; ServerName = $SiteSQLServer.NetworkOSPath.Replace("\","")}
        }
        $AllSiteSUPServers = Get-CMSiteRole -RoleName "SMS Software Update Point" -AllSites | Select NetworkOSPath, SiteCode
        foreach($SiteSUPServer in $AllSiteSUPServers)
        {
            $SiteSUPServers += New-Object PSObject -Property @{SiteCode = $SiteSUPServer.SiteCode; ServerName = $SiteSUPServer.NetworkOSPath.Replace("\","")}
        }
        $SUPServers = @(@($SiteSUPServers | ? {$_.SiteCode -eq $CentralSiteDetails.SiteCode}).ServerName)
        $SQLServerNames = @(@($SiteSQLServers | ? {$_.SiteCode -eq $CentralSiteDetails.SiteCode}).ServerName)
        $SQLClusterName = Get-SQLClusterName -SQLServerNames $SQLServerNames
        $AllSites += New-Object PSObject -Property @{Site = "Central"; SiteCode = $CentralSiteDetails.SiteCode; SiteServer = $CentralSiteDetails.SiteServer; SQLServerNames = $SQLServerNames; SUPServers = $SUPServers; SQLClusterName = $SQLClusterName; SiteSQLDBName = "CM_$($CentralSiteDetails.SiteCode)"}
        $primarySites = @($AllSiteDetails | ? {$_.ReportingSiteCode -eq $CentralSiteDetails.SiteCode})
        foreach($primarySite in $primarySites)
        {
            $SUPServers = @()
            $SQLServerNames = @()
            $SUPServers = @(@($SiteSUPServers | ? {$_.SiteCode -eq $primarySite.SiteCode}).ServerName)
            $SQLServerNames = @(@($SiteSQLServers | ? {$_.SiteCode -eq $primarySite.SiteCode}).ServerName)
            $SQLClusterName = Get-SQLClusterName -SQLServerNames $SQLServerNames
            $AllSites += New-Object PSObject -Property @{Site = "Primary"; SiteCode = $primarySite.SiteCode; SiteServer = $primarySite.ServerName; SQLServerNames = $SQLServerNames; SUPServers = $SUPServers; SQLClusterName = $SQLClusterName; SiteSQLDBName = "CM_$($primarySite.SiteCode)"}
        }
        $secondarySites = @($AllSiteDetails | ? {$_.ReportingSiteCode -in @($primarySites.SiteCode)})
        foreach($secondarySite in $secondarySites)
        {
            $SUPServers = @()
            $SQLServerNames = @()
            $SUPServers = @(@($SiteSUPServers | ? {$_.SiteCode -eq $secondarySite.SiteCode}).ServerName)
            $SQLServerNames = @(@($SiteSQLServers | ? {$_.SiteCode -eq $secondarySite.SiteCode}).ServerName)
            $SQLClusterName = Get-SQLClusterName -SQLServerNames $SQLServerNames
            $AllSites += New-Object PSObject -Property @{Site = "Secondary"; SiteCode = $secondarySite.SiteCode; SiteServer = $secondarySite.ServerName; SQLServerNames = $SQLServerNames; SUPServers = $SUPServers; SQLClusterName = $SQLClusterName; SiteSQLDBName = "CM_$($secondarySite.SiteCode)"}
        }
        return $AllSites
    }
    finally
    {    
        Disconnect-SiteServer
    }
}

function Test-SiteServerConnection {
    param
    (
        $SiteCode,
        $ProviderMachineName
    )
    $returnObj = New-ResultObject
    try
    {
        $returnObj.Logs += "Connecting to Site server: [$SiteCode]"
        $connectionResult = Connect-SiteServer -SiteCode $SiteCode -ProviderMachineName $ProviderMachineName
        $returnObj.Logs += $connectionResult.Logs
        if($connectionResult.IsError -eq $false)
        {
            $returnObj.Logs += "Successfully connected to site server"
            Start-Sleep -Seconds 10
            $returnObj.Output += "Disconnecting from Site server: [$SiteCode]"
            Disconnect-SiteServer
            $returnObj.Logs += "Successfully disconnected from Site server: [$SiteCode]"
            $returnObj.IsError = $false
            $returnObj.Output = $true
        }
        else
        {
            $returnObj.Output = $false
        }
    }
    catch [System.Exception]
    {
        $returnObj.Output = $false
        $returnObj.Logs += "Error while connecting to Site server: [$SiteCode]: [$($_.Exception.ToString())]"
    }
    return $returnObj
}

function Get-DBResult {
    <#
    .SYNOPSIS
        Get SQL output after executing the SQL query...
    .DESCRIPTION
        Get SQL output after executing the SQL query against the DB... 
    .PARAMETER MOName
        SQL Server, SQL Database, SQL Command, SQL timeout (e.g. SQLServer, DB, SQLQuery, Timeout in Seconds) name...
    #>
    param
    (
        $SQLServerName, 
        $SQLDatabaseName, 
        $SQLCommand, 
        $intSQLTimeout, 
        $retryCount = 3,
        $CommandTimeOutSeconds = 120
    )
    $returnObj = New-ResultObject
    $attemptCount = 1	
    #convert timeout to seconds
	if ($intSqlTimeout -ne $null)
	{
		$strSQLTimeout = ";Connection Timeout=$intSQLTimeout"
	}
    do
    {
        #build SQL Server connect string
	    $strSQLConnect = "Server=$SQLServerName;Database=$SQLDatabaseName;Integrated Security=True$strSQLTimeout"
	    $returnObj.Logs += "$strSQLConnect"
	    #connect to server and recieve dataset
	    $objSQLConnection = New-Object System.Data.SQLClient.SQLConnection
	    $objSQLConnection.ConnectionString =  $strSQLConnect
	    $objSQLCmd = New-Object System.Data.SQLClient.SQLCommand
	    $objSQLCmd.CommandText = $SQLCommand
	    $objSQLCmd.Connection = $objSQLConnection
        $objSQLCmd.CommandTimeout = $CommandTimeOutSeconds
	    $objSQLAdapter = New-Object System.Data.SQLClient.SQLDataAdapter
	    $objSQLAdapter.SelectCommand = $objSQLCmd
	    $objDataSet = New-Object System.Data.DataSet
        try
        {
	        $strRowCount = $objSQLAdapter.Fill($objDataSet)
            if ($?) 
            {
                $objTable = $objDataSet.Tables[0]
                $returnObj.Logs += "Successfully executed the query after $attemptCount attempts."
                $returnObj.IsError = $false
                break;
            }
        }
        catch [System.Exception]
        {
            $returnObj.Output = $null
            $returnObj.Logs += "Error - $($_.Exception.ToString())"
            $attemptCount++
            if($attemptCount -lt $retryCount)
            {
                Start-Sleep -Seconds 30
            }
            continue;
	    }
        finally
        {
            #close the SQL connection
            $objSQLConnection.Close()
        }   
        
    } while($attemptCount -le $retryCount)
    if($objTable -eq $null)
    {    
        $returnObj.Logs += "Query Returned No Output."
    }

    #return Result Object caller
    $returnObj.Output = $objTable
	return $returnObj
}

function Test-SQLServerConnection {
    param
    (
        $SQLServerName,
        $DatabaseName
    )
    return Get-DBResult -SQLServerName $SQLServerName -SQLDatabaseName $DatabaseName -SQLCommand "SELECT @@SERVERNAME As ServerName"
}

function Get-SiteServerInfo {
    param
    (        
        $PrimarySiteCode,
        $PrimarySiteServerName,
        $SiteCode,
        $ProviderMachineName
    )
    $returnObj = New-ResultObject
    $resultData = New-Object PSObject -Property @{ConnectionInfo=$null;SiteDetails=$null;SiteProperties=$null;UpdateStatus=$null}
    try
    {
        ## Connect to central server first
        $ConnectionInfo = Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServerName
        $returnObj.Logs += $ConnectionInfo.Logs
        if($ConnectionInfo.IsError -eq $false)
        {          

            ## Get Site details
            $resultData.SiteDetails = Get-CMSite -SiteCode $SiteCode

            ## Get Updates Status
            $CMUpdates = Get-CMSiteUpdate -Fast
            $UpdateStatus = @()
            foreach($CMUpdate in $CMUpdates)
            {
                $Installed = $false
                ## 196612 = Installed
                if($CMUpdate.State -eq 196612) { $Installed = $true }
                $UpdateStatus += New-Object PSObject -Property @{Name=$CMUpdate.Name;Installed=$Installed;ClientVersion=$CMUpdate.ClientVersion;DateCreated=$CMUpdate.DateCreated;DateReleased=$CMUpdate.DateReleased;Description=$CMUpdate.Description;FullVersion=$CMUpdate.FullVersion;LastUpdateTime=$CMUpdate.LastUpdateTime;MoreInfoLink=$CMUpdate.MoreInfoLink;PackageGuid=$CMUpdate.PackageGuid;State=$CMUpdate.State}
            }
            $UpdateStatus = $UpdateStatus | Sort DateReleased -desc
            $resultData.UpdateStatus = $UpdateStatus


            Disconnect-SiteServer
        

            ## Connect to site server
            $ConnectionInfo = Connect-SiteServer -SiteCode $SiteCode -ProviderMachineName $ProviderMachineName
            $returnObj.Logs += $ConnectionInfo.Logs
            if($ConnectionInfo.IsError -eq $false)
            {
                $resultData.ConnectionInfo = $ConnectionInfo.Output
                ## Get site properties from registry
                $resultData.SiteProperties = Invoke-Command -ComputerName $resultData.ConnectionInfo.ProviderMachineName { Get-ItemProperty HKLM:\SOFTWARE\Microsoft\SMS\Setup } -ErrorAction SilentlyContinue

                ## Disconnect back to site server
                Disconnect-SiteServer

                $returnObj.Output = $resultData
                $returnObj.IsError = $false
            }
            else
            {
                $returnObj.Logs += "Unable to connect to site server!"
            }
        }
        else
        {
            $returnObj.Logs += "Unable to connect to $PrimarySiteCode server!"
        }
    }
    catch [System.Exception]
    {
        Disconnect-SiteServer
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }    
    return $returnObj
}

function Confirm-Accessibility {
	param
	(
		$computerName,
		$port = $null,
		$retryCount = 3,
		$pingInterval = 60 #seconds...
	)
	
	$returnObj = New-ResultObject
	$attemptCount = 1
	$returnObj.Logs += "Pinging server: [$computerName]..."
	do
	{
		try
		{
			$ip = [System.Net.Dns]::GetHostByName($computerName)
			$addr = $ip.AddressList[0].IPAddressToString
			if ($addr -eq $null) 
			{
				$returnObj.Logs += "Unable to get IPAddress from DNS query, Total Attempts: [$attemptCount]"
				$attemptCount += 1
			}
			$returnObj.Logs += "Resolved Address to : $addr"		
			$oPing = new-object System.Net.NetworkInformation.Ping
			$response = $oPing.Send($addr)
			if ($response.Status -eq "Success")
			{
				$returnObj.Logs += "Ping successful to Server: [$computerName]..."				
				if ($port -ne $null) 
				{
					$connChk=$false
					$returnObj.Logs += "Checking for connectivity to port : [$port]..."
					$oPort = new-object System.Net.Sockets.TcpClient($addr,$port)
					if ($oPort.Connected) 
					{ 
						$returnObj.Logs += "Port connectivity confirmed for port : $port"
						$oPort.Close()
                        $returnObj.Output = $true
                        $returnObj.IsError = $false
                        break;
					} 
					else 
					{
						$returnObj.Logs += "Unable to connect to port : [$port] on server: [$computerName]..."
						$returnObj.Output = $false
					}
				}				
			}
			else
			{
				$returnObj.Logs += "Ping computer: [$computerName] response: [$($response.Status)], Total Attempts: [$attemptCount]"
				$attemptCount += 1
				Start-Sleep -Seconds $pingInterval
			}
		}
		catch [System.Exception]
		{
			$returnObj.Logs += "Exception while pinging computer: [$computerName], Total Attempts: [$attemptCount]"
			$attemptCount += 1
			Start-Sleep -Seconds $pingInterval
		}
	} while($attemptCount -le $retryCount)
	
	return $returnObj
}

function Start-PSSession {
    param
    (
        $ComputerName
    )
    $returnObj = New-ResultObject
    try
    {
        $returnObj.Logs += "Attempting to establish PSSession to computer - [$ComputerName]"
        $Session = New-PSSession -ComputerName $ComputerName
        $returnObj.Output = $Session
        $returnObj.IsError = $false
        $returnObj.Logs += "Successfully established PSSession to computer - [$ComputerName]"
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Test-Connectivity {
    param
    (
        $ComputerName,
        [switch]$ReturnPSSession
    )
    $returnObj = New-ResultObject
    $ConnectionOutput = New-Object PSObject -Property @{ComputerName=$ComputerName;CanPing=$false;CanEstablishPSSession=$false;PSSession=$null}
    
    ## Ping
    $PingResult = Confirm-Accessibility -computerName $ComputerName
    $returnObj.Logs += $PingResult.Logs
    $ConnectionOutput.CanPing = $returnObj.Output
    if($PingResult.IsError -eq $false)
    {
        ## Check if we can establish PSSession
        $SessionResult = Start-PSSession -ComputerName $ComputerName
        $returnObj.Logs += $SessionResult.Logs        
        if($SessionResult.IsError -eq $false)
        {
            $ConnectionOutput.CanEstablishPSSession = $true
            if($ReturnPSSession)
            {
                $ConnectionOutput.PSSession = $SessionResult.Output
            }
        }
    }
    $returnObject.output = $ConnectionOutput
    return $returnObject
}

## Returns - Windows operating system version, local admin group members, shared folders, logical disks, Scheduled tasks, management groups, AzureSecpack, IPAK details, Windows features and roles
function Get-SystemDetails {
    param
    (
        [Parameter(Position=0, ParameterSetName="ComputerName")]
        $ComputerName,
        [Parameter(Position=0, ParameterSetName="PSSession")]
        $PSSession
    )
    $returnObj = New-ResultObject
    $resultData = New-Object PSObject -Property @{ComputerName=$ComputerName;OSDetails=$null;LocalAdminGroupDetails=$null;SharedFolders=$null;LogicalDisks=$null;ScheduledTasks=$null;ManagementGroups=$null;IPAKDetails=$null;WindowsFeatures=$null;AzSecPackMonitorAgentPresent=$null}
    try
    {
        if(!$PSSession) 
        {
            $PSSessionDetails = Start-PSSession -ComputerName $ComputerName
            $returnObj.Logs += $PSSessionDetails.Logs
            $PSSession = $PSSessionDetails.Output
            $ComputerName = $PSSession.ComputerName
        }
        if($PSSession -eq $null)
        {
            $returnObj.Logs += "Error - Unable to establish PSSession"
        }
        else
        {
            $resultData.OSDetails = Invoke-Command -Session $PSSession -ScriptBlock { [Environment]::OSVersion } -ErrorAction SilentlyContinue
            $resultData.LocalAdminGroupDetails = Invoke-Command -Session $PSSession -ScriptBlock { net localgroup administrators } -ErrorAction SilentlyContinue
            $resultData.SharedFolders = Get-WmiObject -class Win32_Share -ComputerName $ComputerName -ErrorAction SilentlyContinue
            $resultData.ManagementGroups = Invoke-Command -Session $PSSession -ScriptBlock { (New-Object -ComObject AgentConfigManager.MgmtSvcCfg).GetManagementGroups() } -ErrorAction SilentlyContinue
            $resultData.WindowsFeatures = Invoke-Command -Session $PSSession { Import-Module ServerManager; Get-WindowsFeature | ? {$_.Installed -eq $true} } -ErrorAction SilentlyContinue
            $returnObj.IsError = $false
        }
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    $returnObj.Output = $resultData
    return $returnObj
}

function Get-FirewallRules {
    param
    (
        [Parameter(Position=0, ParameterSetName="ComputerName")]
        $ComputerName,
        [Parameter(Position=0, ParameterSetName="PSSession")]
        $PSSession,        
        [int[]]$Ports
    )
    $returnObj = New-ResultObject
    try
    {
        if(!$PSSession) 
        {
            $PSSessionDetails = Start-PSSession -ComputerName $ComputerName
            $returnObj.Logs += $PSSessionDetails.Logs
            $PSSession = $PSSessionDetails.Output
            $ComputerName = $PSSession.ComputerName
        }
        if($PSSession -eq $null)
        {
            $returnObj.Logs += "Error - Unable to establish PSSession"
        }
        else
        {
            $returnObj.Output = Invoke-Command -Session $PSSession -ArgumentList @(,$Ports) -ScriptBlock { param($Ports) Get-NetFirewallPortFilter | ? {$_.LocalPort -in $Ports} | Get-NetFirewallRule } -ErrorAction SilentlyContinue
            $returnObj.IsError = $false
        }
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-SQLServerDetails {
    param
    (
        [Parameter(Position=0, ParameterSetName="ServerName")]
        $ServerName
    )
    $returnObj = New-ResultObject
    $resultData = New-Object PSObject -Property @{ServerName=$ServerName;SqlVersion=$null;ServiceDetails=$null;SqlRolesAndPermissions=$null;SqlJobDetails=$null}
    $SqlLoginAndRoleQuery = "DECLARE @name sysname,
                            @sql nvarchar(4000),
                            @maxlen1 smallint,
                            @maxlen2 smallint,
                            @maxlen3 smallint

                            IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE '#tmpTable%')
                            DROP TABLE #tmpTable

                        CREATE TABLE #tmpTable 
                        (
                            DBName sysname NOT NULL ,
                            UserName sysname NOT NULL,
                            RoleName sysname NOT NULL
                        )

                        DECLARE c1 CURSOR for 
                            SELECT name FROM master.sys.databases

                        OPEN c1
                        FETCH c1 INTO @name
                        WHILE @@FETCH_STATUS >= 0
                        BEGIN
                            SELECT @sql = 
                            'INSERT INTO #tmpTable
                            SELECT N'''+ @name + ''', a.name, c.name
                            FROM [' + @name + '].sys.database_principals a 
                            JOIN [' + @name + '].sys.database_role_members b ON b.member_principal_id = a.principal_id
                            JOIN [' + @name + '].sys.database_principals c ON c.principal_id = b.role_principal_id
                            WHERE a.name != ''dbo'''
                            EXECUTE (@sql)
                            FETCH c1 INTO @name
                        END
                        CLOSE c1
                        DEALLOCATE c1

                        SELECT @maxlen1 = (MAX(LEN(COALESCE(DBName, 'NULL'))) + 2)
                        FROM #tmpTable

                        SELECT @maxlen2 = (MAX(LEN(COALESCE(UserName, 'NULL'))) + 2)
                        FROM #tmpTable

                        SELECT @maxlen3 = (MAX(LEN(COALESCE(RoleName, 'NULL'))) + 2)
                        FROM #tmpTable

                        SET @sql = 'SELECT LEFT(DBName, ' + LTRIM(STR(@maxlen1)) + ') AS ''DBName'', '
                        SET @sql = @sql + 'LEFT(UserName, ' + LTRIM(STR(@maxlen2)) + ') AS ''UserName'', '
                        SET @sql = @sql + 'LEFT(RoleName, ' + LTRIM(STR(@maxlen3)) + ') AS ''RoleName'' '
                        SET @sql = @sql + 'FROM #tmpTable '
                        SET @sql = @sql + 'ORDER BY DBName, UserName'
                        EXEC(@sql)"

    $SqlJobQuery = "SELECT 
                                [sJOB].[job_id] AS [JobID]
                                , [sJOB].[name] AS [JobName]
                                , [sDBP].[name] AS [JobOwner]
                                , [sCAT].[name] AS [JobCategory]
                                , [sJOB].[description] AS [JobDescription]
                                , CASE [sJOB].[enabled]
                                    WHEN 1 THEN 'Yes'
                                    WHEN 0 THEN 'No'
                                  END AS [IsEnabled]
                                , [sJOB].[date_created] AS [JobCreatedOn]
                                , [sJOB].[date_modified] AS [JobLastModifiedOn]
                                , [sSVR].[name] AS [OriginatingServerName]
                                , [sJSTP].[step_id] AS [JobStartStepNo]
                                , [sJSTP].[step_name] AS [JobStartStepName]
                                , CASE
                                    WHEN [sSCH].[schedule_uid] IS NULL THEN 'No'
                                    ELSE 'Yes'
                                  END AS [IsScheduled]
                                , [sSCH].[schedule_uid] AS [JobScheduleID]
                                , [sSCH].[name] AS [JobScheduleName]
                                , CASE [sJOB].[delete_level]
                                    WHEN 0 THEN 'Never'
                                    WHEN 1 THEN 'On Success'
                                    WHEN 2 THEN 'On Failure'
                                    WHEN 3 THEN 'On Completion'
                                  END AS [JobDeletionCriterion]
                            FROM
                                [msdb].[dbo].[sysjobs] AS [sJOB]
                                LEFT JOIN [msdb].[sys].[servers] AS [sSVR]
                                    ON [sJOB].[originating_server_id] = [sSVR].[server_id]
                                LEFT JOIN [msdb].[dbo].[syscategories] AS [sCAT]
                                    ON [sJOB].[category_id] = [sCAT].[category_id]
                                LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sJSTP]
                                    ON [sJOB].[job_id] = [sJSTP].[job_id]
                                    AND [sJOB].[start_step_id] = [sJSTP].[step_id]
                                LEFT JOIN [msdb].[sys].[database_principals] AS [sDBP]
                                    ON [sJOB].[owner_sid] = [sDBP].[sid]
                                LEFT JOIN [msdb].[dbo].[sysjobschedules] AS [sJOBSCH]
                                    ON [sJOB].[job_id] = [sJOBSCH].[job_id]
                                LEFT JOIN [msdb].[dbo].[sysschedules] AS [sSCH]
                                    ON [sJOBSCH].[schedule_id] = [sSCH].[schedule_id]
                            ORDER BY [JobName]"
    try
    {
        $SqlVersionOutput = Get-DBResult -SQLServerName $ServerName -SQLDatabaseName "master" -SQLCommand "SELECT @@VERSION AS SqlVersion"
        $returnObj.Logs += $SqlVersionOutput.Logs
        if($SqlVersionOutput.IsError -eq $false)
        {            
            $resultData.SqlVersion = $SqlVersionOutput.Output.SqlVersion
            $resultData.ServiceDetails = Get-WmiObject -Query "SELECT Name, StartName, StartMode, State FROM Win32_Service WHERE NAME LIKE 'SQL%'" -ComputerName $ServerName -ErrorAction SilentlyContinue

            ## Roles and permissions
            $SqlRolesAndPermissions = Get-DBResult -SQLServerName $ServerName -SQLDatabaseName "master" -SQLCommand $SqlLoginAndRoleQuery
            $returnObj.Logs += $SqlRolesAndPermissions.Logs
            $resultData.SqlRolesAndPermissions = $SqlRolesAndPermissions.Output
            
            ## SQL Jobs    
            $SqlJobDetails = Get-DBResult -SQLServerName $ServerName -SQLDatabaseName "master" -SQLCommand $SqlJobQuery
            $returnObj.Logs += $SqlJobDetails.Logs
            $resultData.SqlJobDetails = $SqlJobDetails.Output

            ## Finally set IsError false
            $returnObj.IsError = $false
        }
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    $returnObj.Output = $resultData
    return $returnObj
}

function Get-EventLogData {
    param
    (
        [Parameter(Mandatory=$true)]
        [String[]]$ComputerNames,
        [Parameter(Mandatory=$true)]
        [String]$LogName,
        [String[]]$Source,
        [String]$Message,
        [ValidateSet("Error","FailureAudit","Information","SuccessAudit","Warning")]
        [String]$EntryType,
        [DateTime]$After,
        [DateTime]$Before
    )
    $returnObj = New-ResultObject
    $EventLogData = @()
    try
    {
        foreach($ComputerName in $ComputerNames)
        {
            try
            {
                $wmiAfter = ([WMI]'').ConvertFromDateTime($After)                
                $wmiWHERE = "LogFile='{0}' AND TimeGenerated>='{1}' AND Type = '{2}'" -f $LogName, $wmiAfter, $EntryType
                if($Before)
                {
                    $wmiBefore = ([WMI]'').ConvertFromDateTime($Before)
                    $wmiWHERE += " AND TimeGenerated < '{0}'" -f $wmiBefore
                }
                if($Source)
                {
                    $wmiWHERE += " AND SourceName < '{0}'" -f $Source
                }
                if($Message)
                {
                    $wmiWHERE += " AND Message LIKE '%$Message'"
                }
                $WMIQuery =  "SELECT * FROM Win32_NTLogevent WHERE {0}" -f $wmiWHERE
                $NameSpace = "Root\CIMV2"
                $wmi = [WMISearcher]""
                $wmi.options.timeout = New-Object System.TimeSpan(0, 2, 0) # TimeSpan(Hr,Min,Sec)
                $wmi.Query = $wmiQuery
                $wmi.scope.path = "\\$ComputerName\$NameSpace"
                $EventLogs = $wmi.Get()
                $EventLogs = $EventLogs | Select -First 25
                $EventLogData += New-Object PSObject -Property @{ComputerName=$ComputerName;EventLogs=$EventLogs}            
            }
            catch [System.Exception]
            {
                $returnObj.Logs += "Error while getting event log from computer $ComputerName - $($_.Exception.ToString())"
            }
        }
        $returnObj.Output = $EventLogData
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-FileLogs {
    param
    (
        [Parameter(Mandatory=$true)]
        [String[]]$ComputerNames,
        [Parameter(Mandatory=$true)]
        [String[]]$FileNames,
        [String[]]$Filters
    )
    $returnObj = New-ResultObject
    $FileLogData = @()
    try
    {
        foreach($ComputerName in $ComputerNames)
        {
            $FileLogs = @()
            try
            {                
                foreach($FileName in $FileNames)
                {
                    try
                    {
                        if($FileName.Contains(":"))
                        {
                            $FileToRead = "\\{0}\{1}" -f $ComputerName, $FileName.Replace(":","$")
                        }
                        else
                        {
                            $FileToRead = $FileName
                        }
                        if(!(Test-Path $FileToRead -ErrorAction SilentlyContinue))
                        {
                            $FileExists = $false
                            $LogData = $null
                        }
                        else
                        {
                            $FileExists = $true
                            if($Filters)
                            {
                                $FileContent = Get-Content $FileToRead -ErrorAction SilentlyContinue
                                if($FileContent)
                                {
                                    $LogData = $FileContent | Select-String -Pattern $Filters -AllMatches
                                }
                            }
                        }
                        $FileLogs += New-Object PSObject -Property @{FileName=$FileName;Exists=$FileExists;LogData=$LogData}
                    }
                    catch [System.Exception]
                    {
                        $returnObj.Logs += "Error while getting file content for file: $FileName from computer $ComputerName - $($_.Exception.ToString())"
                    }
                }
            }
            catch [System.Exception]
            {
                $returnObj.Logs += "Error while getting file content from computer $ComputerName - $($_.Exception.ToString())"
            }
            $FileLogData += New-Object PSObject -Property @{ComputerName=$ComputerName;FileLogs=$FileLogs}
        }
        $returnObj.Output = $FileLogData
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-ServiceDetails {
    param
    (
        [Parameter(Position=0, ParameterSetName="ComputerName")]
        $ComputerName,
        $ServiceNames
    )
    $returnObj = New-ResultObject
    try
    {
        $WmiQuery = "SELECT Name, StartName, StartMode, State FROM Win32_Service"
        $ServiceDetails = Get-WmiObject -Query $WmiQuery -ComputerName $ComputerName -ErrorAction SilentlyContinue
        $returnObj.Output = $ServiceDetails | ? {$_.Name -in $ServiceNames}
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-LatestCrashDumpInfo {
    param
    (
        [Parameter(Position=0, ParameterSetName="ComputerName")]
        $ComputerName,
        $CrashDumpPath,
        [DateTime]$UpgradeDateTime,
        $Filter
    )
    $returnObj = New-ResultObject
    $resultObj = New-Object PSObject -Property @{RootFolderExists=$false;CrashDumpFoldersExist=$false;LatestCrashDumpFolderExists=$false;LastWriteTime=$null;FolderName=$null;UpgradeDate=$UpgradeDateTime}
    try
    {
        if($CrashDumpPath.Contains(":"))
        {
            $CrashDumpPath = "\\{0}\{1}" -f $ComputerName, $CrashDumpPath.Replace(":","$")
        }
        if((Get-ChildItem $CrashDumpPath -ErrorAction SilentlyContinue))
        {
            $resultObj.RootFolderExists = $true
            $CrashdumpFolders = @(Get-ChildItem $CrashDumpPath -Directory -Filter $Filter)
            if(($CrashdumpFolders -ne $null) -and ($CrashdumpFolders.Count -gt 0) -and ($CrashdumpFolders[0] -ne $null))
            {
                $resultObj.CrashDumpFoldersExist = $true
                $LatestCrashdumpFolder = $CrashdumpFolders | Sort LastWriteTime -desc | select -First 1
                if($LatestCrashdumpFolder.LastWriteTime -ge $UpgradeDateTime)
                {
                    $resultObj.LatestCrashDumpFolderExists = $true                    
                }
                $resultObj.LastWriteTime = $LatestCrashdumpFolder.LastWriteTime
                $resultObj.FolderName = $LatestCrashdumpFolder.Name
            }
            $returnObj.Output = $resultObj
            $returnObj.IsError = $false
        }
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-ComponentStatusMessages {
    param
    (
        $SQLServerName,
        $SQLDBName,
        $SiteCode,
        [int]$DaysOld,
        [string[]]$IgnoreComponents
    )
    $returnObj = New-ResultObject
    try
    {
        $LogFrom = (Get-Date).AddDays(-$DaysOld)
        if($IgnoreComponents)
        {
            $IgnoreComponentSet = "('{0}')" -f ($IgnoreComponents -join "','")
        }
        $Query = "Select ModuleName,
        CASE Severity
            WHEN 1073741824 THEN 'Error'
            WHEN 2147483648 THEN 'Warning'
        END AS Severity,
        MessageID,MachineName,Component,SiteCode,Time as TimeLogged from v_StatusMessage as stat WITH (NOLOCK)
        left outer join v_StatMsgAttributes  as att WITH (NOLOCK) on stat.recordid = att.recordid 
        left outer join v_StatMsgInsStrings  as ins WITH (NOLOCK) on stat.recordid = ins.recordid 
        WHERE (stat.Time>='$LogFrom') AND (SEVERITY=1073741824 OR SEVERITY=2147483648) AND (SiteCode='$SiteCode')"
        if($IgnoreComponentSet -ne $null)
        {
            $Query += " AND (Component NOT IN $IgnoreComponentSet)"
        }
        $Query += " order by stat.Time Desc" 
        $ComponentLogs = Get-DBResult -SQLServerName $SQLServerName -SQLDatabaseName $SQLDBName -SQLCommand $Query
        $returnObj.Logs += $ComponentLogs.Logs
        if($ComponentLogs.IsError -eq $false)
        {
            $returnObj.Output = $ComponentLogs.Output.Rows
            $returnObj.IsError = $false
        }
    }
    catch [System.Exception]
    {        
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }    
    return $returnObj
}

function Get-ComponentStatusMessagesForSUP {
    param
    (
        $SQLServerName,
        $SQLDBName,
        $SiteCode,
        $SUPMachineNameSubstring,
        [int]$DaysOld,
        [string[]]$IgnoreComponents
    )
    $returnObj = New-ResultObject
    try
    {
        $LogFrom = (Get-Date).AddDays(-$DaysOld)
        if($IgnoreComponents)
        {
            $IgnoreComponentSet = "('{0}')" -f ($IgnoreComponents -join "','")
        }
        $Query = "Select ModuleName,
        CASE Severity
            WHEN 1073741824 THEN 'Error'
            WHEN 2147483648 THEN 'Warning'
        END AS Severity,
        MessageID,MachineName,Component,SiteCode,Time as TimeLogged from v_StatusMessage as stat WITH (NOLOCK)
        left outer join v_StatMsgAttributes  as att WITH (NOLOCK) on stat.recordid = att.recordid 
        left outer join v_StatMsgInsStrings  as ins WITH (NOLOCK) on stat.recordid = ins.recordid 
        WHERE (stat.Time>='$LogFrom') AND (SEVERITY=1073741824 OR SEVERITY=2147483648) AND (SiteCode='$SiteCode')
        AND (MachineName LIKE '%$SUPMachineNameSubstring%')"
        if($IgnoreComponentSet -ne $null)
        {
            $Query += " AND (Component NOT IN $IgnoreComponentSet)"
        }
        $Query += " order by stat.Time Desc" 
        $ComponentLogs = Get-DBResult -SQLServerName $SQLServerName -SQLDatabaseName $SQLDBName -SQLCommand $Query
        $returnObj.Logs += $ComponentLogs.Logs
        if($ComponentLogs.IsError -eq $false)
        {
            $returnObj.Output = $ComponentLogs.Output.Rows
            $returnObj.IsError = $false
        }
    }
    catch [System.Exception]
    {        
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }    
    return $returnObj
}

function Get-InboxAndOutBoxLogs {
    param
    (
        $ComputerName,
        $ExpectedInboxBoxAndOutBoxLogCheckParams,
        [DateTime]$UpgradeDate
    )
    $returnObj = New-ResultObject
    $resultObject = @()
    try
    {
        foreach($Key in $ExpectedInboxBoxAndOutBoxLogCheckParams.Keys)
        {
            $fileName = $ExpectedInboxBoxAndOutBoxLogCheckParams[$Key]["FileName"]
            $fileDisplayName = Split-Path $fileName -Leaf
            $patterns = $ExpectedInboxBoxAndOutBoxLogCheckParams[$Key]["Patterns"]           
            $expectedValue = $ExpectedInboxBoxAndOutBoxLogCheckParams[$Key]["ExpectedValue"]
            $FileLogs = Get-FileLogs -ComputerNames $ComputerName -FileNames $fileName -Filters $patterns
            $returnObj.Logs += $FileLogs.Logs
            ## Process files to generate result object
            if($FileLogs.IsError -eq $false)
            {
                $LogOutputs = $fileLogs.Output[0].FileLogs[0].LogData
                foreach($LogOutput in $LogOutputs)
                {
                    foreach($pattern in $patterns)
                    {
                        if($LogOutput -match $pattern)
                        {
                            $LogLine = "{0} - {1}" -f $fileDisplayName, $matches[1]
                            $LogValue = $matches[2]
                            $TimeLogged = [DateTime]($matches[3])
                            $resultObject += New-Object PSObject -Property @{Monitor=$Key;LogLine=$LogLine;LogValue=$LogValue;TimeLogged=$TimeLogged;LogOutput=$LogOutput;Threshold=$expectedValue}
                        }
                    }
                }
            }            
        }
        $resultObject = $resultObject | ? {$_.TimeLogged -ge $UpgradeDate}
        $returnObj.Output = $resultObject
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-SQLServerErrorLogs {
    param
    (
        $SQLServerName,
        $LogFrom,
        $IgnorePattern
    )
    $returnObj = New-ResultObject
    try
    {
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
        $SQLServer = New-Object Microsoft.SQLServer.Management.Smo.Server $SQLServerName
        $ErrorLogs = $SQLServer.ReadErrorLog(0) | ? {$_.LogDate -ge $LogFrom}
        $ErrorLogs = $ErrorLogs | ? {$_.Text -match "Error"}
        $ErrorLogs = $ErrorLogs | ? {$_.Text -notmatch $IgnorePattern} | Sort LogDate -desc
        $returnObj.Output = $ErrorLogs
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-WSUSSyncStatus {
    param
    (
        $SiteCode,
        $ProviderServerName
    )
    $returnObj = New-ResultObject
    try
    {
        ## Connect to site server
        $connecResult = Connect-SiteServer -SiteCode $SiteCode -ProviderMachineName $ProviderServerName
        if($connecResult.IsError -eq $false)
        {
            $arrObjWSUSSyncStatus = Get-CMSoftwareUpdateSyncStatus
            ## Convert PSObject to Hashtable
            $arrHahOutput = @()
            foreach($ObjWSUSSyncStatus in $arrObjWSUSSyncStatus)
            {
                $LastSyncState = @{$true="Completed";$false='Failed'}[$ObjWSUSSyncStatus.LastSyncState -eq 6702]
                $ReplicationLinkStatus = @{$true="Active";$false='Failed'}[$ObjWSUSSyncStatus.ReplicationLinkStatus -eq 2]
                $hashOutput = @{SiteCode=$ObjWSUSSyncStatus.SiteCode;
                                LastSyncState=$LastSyncState;
                                ReplicationLinkStatus=$ReplicationLinkStatus;
                                LastSync=$ObjWSUSSyncStatus.LastSyncStateTime;
                                SyncCatalogVersion=$ObjWSUSSyncStatus.SyncCatalogVersion
                                }
                $arrHahOutput += $hashOutput
            }
            $returnObj.Output = $arrHahOutput
            $returnObj.IsError = $false
            Disconnect-SiteServer
        }
    }
    catch [System.Exception]
    {
        Disconnect-SiteServer
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-ReplicationStatus {
    param
    (
        $SiteCode,
        $ProviderServerName
    )
    $returnObj = New-ResultObject
    try
    {
        ## Connect to site server
        $connecResult = Connect-SiteServer -SiteCode $SiteCode -ProviderMachineName $ProviderServerName
        $output = @()
        $replicationStatus = Get-CMDatabaseReplicationStatus
        foreach($SiteReplicationStatusInfo in $replicationStatus)
        {
            $siteReplicationStatus = @{
                                            ParentSite = $SiteReplicationStatusInfo.Site1
                                            ChildSite = $SiteReplicationStatusInfo.Site2
                                            LinkStatus = @{$true="Link Active"; $false="Link not active"}[$SiteReplicationStatusInfo.LinkStatus -eq 2]
                                            ParentSiteState = @{$true="Replication Active";$false="Replication not active"}[$SiteReplicationStatusInfo.Site1Status -eq 125]
                                            ChildSiteState = @{$true="Replication Active";$false="Replication not active"}[$SiteReplicationStatusInfo.Site2Status -eq 125]
                                        }
            $siteGlobalSyncStatus = @{
                                            ParentSite = $SiteReplicationStatusInfo.Site1
                                            ChildSite = $SiteReplicationStatusInfo.Site2
                                            ParentToChildGlobalSyncTime = $SiteReplicationStatusInfo.Site1ToSite2GlobalSyncTime
                                            ChildToParentGlobalSyncTime = $SiteReplicationStatusInfo.Site2ToSite1GlobalSyncTime
                                            InitializationPercentage = $SiteReplicationStatusInfo.GlobalInitPercentage
                                       }
            $output += New-Object PSObject -Property @{SiteReplicationStatus=$siteReplicationStatus;SiteGlobalSyncStatus=$siteGlobalSyncStatus}
        }

        $returnObj.Output = $Output
        $returnObj.IsError = $false

        ## Disconnect to site server
        Disconnect-SiteServer
    }
    catch [System.Exception]
    {
        Disconnect-SiteServer
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Publish-PieChart {
    param
    (
        [hashtable]$Params,
        $OutputFileName
    )
 
    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization") | Out-Null

    #Create our chart object
    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
    $Chart.Width = 300
    $Chart.Height = 250
    $Chart.Left = 10
    $Chart.Top = 10
 
    #Create a chartarea to draw on and add this to the chart
    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $Chart.ChartAreas.Add($ChartArea)
    [void]$Chart.Series.Add("Data") 
 
    #Add a datapoint for each value specified in the parameter hash table
    if($Params.Passed -gt 0)
    {
        $datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $Params.Passed)
        $datapoint.Color = [System.Drawing.Color]::Green
        $datapoint.AxisLabel = "Passed ($($Params.Passed))"
        $Chart.Series["Data"].Points.Add($datapoint)
    }

    if($Params.Failed -gt 0)
    {
        $datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $Params.Failed)
        $datapoint.Color = [System.Drawing.Color]::Red
        $datapoint.AxisLabel = "Failed ($($Params.Failed))"
        $Chart.Series["Data"].Points.Add($datapoint)
    }

    if($Params.Manual -gt 0)
    {
        $datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $Params.Manual)
        $datapoint.Color = [System.Drawing.Color]::Gray
        $datapoint.AxisLabel = "Manual ($($Params.Manual))"
        $Chart.Series["Data"].Points.Add($datapoint)
    }    
 
    $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
    $Chart.Series["Data"]["PieLabelStyle"] = "Outside"
    $Chart.Series["Data"]["PieLineColor"] = "Black"
 
    #Set the title of the Chart
    $Title = new-object System.Windows.Forms.DataVisualization.Charting.Title
    $Chart.Titles.Add($Title)
    $TotalCases = $Params.Passed + $Params.Failed + $Params.Manual
    $Chart.Titles[0].Text = "QC result - Total $TotalCases cases"
    $Chart.SaveImage($OutputFileName,"png")
    
}

function EncodeHtml {
    param
    (
        $Value
    )
    if([String]::IsNullOrEmpty($Value) -eq $true)
    {
        $Value = "&nbsp;"
    }
    else
    {
        [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
        $Value = [System.Web.HttpUtility]::HtmlEncode($Value)
    }
    return $Value
}

function ConvertTo-HtmlReport {
    param
    (
        $Head,
        $PreContent,
        $TestResult
    )    
    $recordsHtml = "<table class='tableR' cellspacing='2' cellpadding='2'>"
    $recordsHtml += "<tr class='trR'><th class='thR'>Category</th><th class='thR'>Test Suite</th><th class='thR'>Test Case</th><th class='thR'>Result</th><th class='thR'>Time to execute</th><th class='thR'>FailureMessage</th></tr>"
    $GroupByCategory = $TestResult | Group Describe
    foreach($Category in $GroupByCategory)
    {
        $recordsHtml += "<tr class='trR' valign='top'>"
        $recordsHtml += "<td class ='tdR' rowspan='{0}'>{1}</td>" -f $Category.Group.Count, (EncodeHtml($Category.Name))
        $GroupBySuite = $Category.Group| Group Context
        foreach($Suite in $GroupBySuite)
        {
            $recordsHtml += "<td class ='tdR' rowspan='{0}'>{1}</td>" -f $Suite.Group.Count, (EncodeHtml($Suite.Name))
            for($i=0;$i-lt$Suite.Group.Count;$i++)
            {            
                $TestCase = $Suite.Group[$i]                
                $BGColor = @{Passed="green";Failed="red";Skipped="gray"}[$TestCase.Result]
                $ResultText = @{Passed="Passed";Failed="Failed";Skipped="Manual"}[$TestCase.Result]	
                $TestCaseResultHtml = "<td class ='tdR' bgcolor='$BGColor' align='center'><font color='white'><b>$ResultText</b></font></td>"
                $TestCaseHtml = "<td class ='tdR'>{0}</td>{1}<td class ='tdR'>{2}</td><td class ='tdR'>{3}</td>" -f (EncodeHtml($TestCase.Name)), $TestCaseResultHtml, (EncodeHtml($TestCase.Time)), (EncodeHtml($TestCase.FailureMessage))
                if($i -eq 0)
                {
                    $TestCaseHtml += "</tr>"
                }
                else
                {
                    $TestCaseHtml = "<tr class='trR'>{0}</tr>" -f $TestCaseHtml
                }
                $recordsHtml += $TestCaseHtml
            }
        }
    }
    $recordsHtml += "</table>"
    $reportHtml = "<html><head>{0}</head><body>{1}{2}</body></html>" -f $Head, $PreContent, $recordsHtml
    return $reportHtml
}

function Export-QCReport {
    param
    (
        $QCTitle,
        $TestResults,
        $OutputPath,
        $QCStart,
        $QCEnd        
    )
    $timeStamp = (Get-Date).ToString("yyyy-MM-dd hh mm ss")
    $ReportPath = "{0}\Reports\{1}" -f $OutputPath, $timeStamp
    if(!(Test-Path $ReportPath -ErrorAction SilentlyContinue))
    {
        New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
    }
    $OutputHtmlFileName = "{0}\QCReport.htm" -f $ReportPath
    $OutputCSVFileName = "{0}\QCReport.csv" -f $ReportPath
    $OutputPieChartFileName = "{0}\QCPiechart.png" -f $ReportPath

    ## Total time taken
    $QCTime = $QCEnd - $QCStart
    $TotalTimeTaken = "{0} minutes, {1} seconds" -f $QCTime.Minutes, $QCTime.Seconds
    
    ## Header
    $Header = @"
        <style>
        body { background-color:#E5E4E2; font-family:Calibri;font-size:10pt; }
        .tdR, .thR { border:1px solid black; border-collapse:collapse; white-space:pre; }
        .thR { color:white;     background-color:black; }
        .tableR, .trR, .tdR, .thR { padding: 2px; margin: 0px ;white-space:pre; }
        .tableR { width:95%;margin-left:5px; margin-bottom:20px;}
        h2 {
            font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
            border-collapse: collapse;
            color:#6D7B8D;
        }
        </style>
"@

    ## Body - Pre-context
    $PreContext = "<h2>$QCTitle</h2>"
    $PreContext += "<p><table border='0' cellpadding='2' cellspacing='2'><tr><td><b>QC Start:</b></td><td>{0}</td><td><b>QC End:</b></td><td>{1}</td><td><b>Total time taken:</b></td><td>{2}</td></tr></table></p>" -f $QCStart, $QCEnd, $TotalTimeTaken


    ## Body - pie chart
    [int]$Manual = $TestResults.PendingCount + $TestResults.SkippedCount
    $Params = @{
                    Passed = $TestResults.PassedCount
                    Failed = $TestResults.FailedCount
                    Manual = $Manual
                }
    Publish-PieChart -Params $Params -OutputFileName $OutputPieChartFileName
    

    $PreContextForFile = $PreContext + "<p><img src='$($OutputPieChartFileName)' Alt='QC result - pie Chart'/></p>"
    $PreContext += "<p><img src='cid:QCPiechart.png' Alt='QC result - pie Chart'/></p>"
    ## Body - Main result table
    $ResultHtml = ConvertTo-HtmlReport -Head $Header -PreContent $PreContext -TestResult $TestResults.TestResult

    $ResultHtmlForFile = ConvertTo-HtmlReport -Head $Header -PreContent $PreContextForFile -TestResult $TestResults.TestResult
    
    ## Export report to Html
    $ResultHtmlForFile | Out-File $OutputHtmlFileName -Force | Out-Null

    ## Export report to CSV
    $TestResult = $TestResults.TestResult
    $TestResult = $TestResult | Select @{N='Category';E={$_.Describe}}, @{N='TestSuite';E={$_.Context}}, @{N='TestCase';E={$_.Name}}, Result, @{N='Timetoexecute';E={$_.Time}}, FailureMessage
    $TestResult | Select Category, TestSuite, TestCase, Result, Timetoexecute, FailureMessage | Sort Category, TestSuite, TestCase | Export-Csv $OutputCSVFileName -NoTypeInformation -Force | Out-Null

    return $OutputCSVFileName
}

function Get-SUPServerAndUrls {
    param
    (
        $PrimarySiteCode,
        $PrimarySiteServer,
        $SiteCode
    )
    $returnObj = New-ResultObject
    try
    {
        Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServer | Out-Null
        $AllSups = Get-CMSiteRole -RoleName "SMS Software Update Point" -AllSite | Select NetworkOSPath, SiteCode        
        $SUPServers = @()
        if($AllSups -ne $null)
        {
            foreach($Sup in $AllSups)
            {
                if($Sup.SiteCode -eq $SiteCode)
                {
                    $SUPServer = $Sup.NetworkOSPath.Replace("\\","")
                    $wuident = "http://{0}/selfupdate/wuident.cab" -f $SUPServer
                    $client = "http://{0}/clientwebservice/client.asmx" -f $SUPServer
                    $SimpleAuth = "http://{0}/SimpleAuthWebService/SimpleAuth.asmx" -f $SUPServer
                
                    $SUPServers += @{ServerName = $SUPServer; wuident = $wuident; client= $client; SimpleAuth=$SimpleAuth;}           
                }
            }
        }
        $returnObj.Output = $SUPServers
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    finally
    {
        Disconnect-SiteServer
    }
    return $returnObj
}

function Get-FSPServers{
    param
    (
        $PrimarySiteCode,
        $PrimarySiteServer,
        $SiteCode
    )
    $returnObj = New-ResultObject
    try
    {
        Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServer | Out-Null
        $FSPs = Get-CMSiteRole -RoleName "SMS Fallback Status Point" -SiteCode $SiteCode | Select NetworkOSPath, SiteCode
        $FSPServers = @()
        if($FSPs -ne $null)
        { 
        foreach($FSP in $FSPs)
        {
            
                $FSPServer = $FSP.NetworkOSPath.Replace("\\","")
                $FSPServers += @{ServerName = $FSPServer}
            
        }
        }
        $returnObj.Output = $FSPServers
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    finally
    {
        Disconnect-SiteServer
    }
    return $returnObj
}

function Get-DMPServers{
    param
    (
        $PrimarySiteCode,
        $PrimarySiteServer,
        $SiteCode
    )
    $returnObj = New-ResultObject
    try
    {
        Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServer | Out-Null
        $DMPs = Get-CMSiteRole -RoleName "SMS Enrollment Server" -SiteCode $SiteCode | Select NetworkOSPath, SiteCode
        $DMPServers = @()
        if($DMPs -ne $null)
         {
        foreach($DMP in $DMPs)
        {
            
                $DMPServer = $DMP.NetworkOSPath.Replace("\\","")
                $DMPServers += @{ServerName = $DMPServer}
            
        }
       }
        $returnObj.Output = $DMPServers
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    finally
    {
        Disconnect-SiteServer
    }
    return $returnObj
}

function Get-Package{
    param
    (
        $PrimarySiteCode,
        $PrimarySiteServer,
        $SiteCode,
        $DistributionPointName,
        $DistributionPointGroupName,
        $PackageFolderPath,
        $PackageFolderName
    )
    $returnObj = New-ResultObject
    try
    {
                <#Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServer | Out-Null
                $PackageName = "QCTestPkg_" + [datetime]::Now.ToString('HH:mm')
                $Package = New-CMPackage –Name $PackageName –Path $SourcePath
                $PackageId = $Package.PackageID
                Set-CMPackage -Id $PackageId -DistributionPriority Low | Out-Null
                New-CMProgram -PackageId $PackageId -StandardProgramName $StandardProgramName "Edge" -CommandLine "MicrosoftEdgeSetup.exe" | Out-Null
                Start-CMContentDistribution -PackageId $PackageId -DistributionPointName $DistributionPointName -DistributionPointGroupName $DistributionPointGroupName | Out-Null
                ##Sleeping for 5 minutes to distribute pacakges to dp's
                Start-Sleep -Seconds 300
                $DistributionStatus = Get-CMDistributionStatus -Id $PackageId
                $ReplicationSuccess=$DistributionStatus.NumberSuccess
                $ReplicationInprog=$DistributionStatus.NumberInProgress
                
                $Package = Get-CMPackage -Id $PackageId
                $Path = $PackageFolderPath + '\' + $PackageFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $PackageFolderName -Path $PackageFolderPath
                  }
                Move-CMObject -InputObject $Package -FolderPath $Path
                
                $TestSet = @()
                $TestSet += @{PackageName = $PackageName; 
                              PackageId = $PackageId;
                              StandardProgramName=$StandardProgramName;
                              DistributionStatus=$DistributionStatus;
                              ReplicationSuccess=$ReplicationSuccess;
                              ReplicationInprog=$ReplicationInprog
                              
                            }
                            
        #>
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    finally
    {
        Disconnect-SiteServer
    }
    return $returnObj
}

function Get-AppsPackage{
    param
    (
        
        $DistributionPointName,
        $DistributionPointGroupName,
        $PackageFolderPath,
        $PackageFolderName,
        $SourcePath,
        $DeployCollectionName
    )
    $returnObj = New-ResultObject


    try
    {
                $PackageName = "QCTestPkg_" + [datetime]::Now.ToString('HH:mm')
                $Package = New-CMPackage –Name $PackageName –Path $SourcePath
                $PackageId = $Package.PackageID
                Set-CMPackage -Id $PackageId -DistributionPriority Low | Out-Null
                New-CMProgram -PackageId $PackageId -StandardProgramName "Edge" -CommandLine "MicrosoftEdgeSetup.exe" | Out-Null
                Start-CMContentDistribution -PackageId $PackageId -DistributionPointName $DistributionPointName -DistributionPointGroupName $DistributionPointGroupName | Out-Null
                ##Sleeping for 5 minutes
                Start-Sleep -Seconds 300
                $DistributionStatus = Get-CMDistributionStatus -Id $PackageId
                $ReplicationSuccess=$DistributionStatus.NumberSuccess
                $ReplicationInprog=$DistributionStatus.NumberInProgress
                $Package = Get-CMPackage -Id $PackageId
                $DeploymentStatus = Start-CMPackagedeployment -PackageName $PackageName -ProgramName "Edge" -CollectionName $DeployCollectionName -StandardProgram -DeployPurpose Available -FastNetworkOption RunProgramFromDistributionPoint -SlowNetworkOption RunProgramFromDistributionPoint
                $DeploymentStatus = Get-CMPackageDeployment -PackageId $PackageId
                $Path = $PackageFolderPath + '\' + $PackageFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $PackageFolderName -Path $PackageFolderPath
                  }
                Move-CMObject -InputObject $Package -FolderPath $Path
                $PkgFolder=Get-Item -Path $Path
                $PSChildName=$PkgFolder.PSChildName

                $TestSet = @()
                $TestSet += @{PackageName = $PackageName; 
                              PackageId = $PackageId;
                              StandardProgramName=$StandardProgramName;
                              DistributionStatus=$DistributionStatus;
                              DeploymentStatus=$DeploymentStatus;
                              PSChildName=$PSChildName;
                              ReplicationSuccess=$ReplicationSuccess
                            }

        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {

        $returnObj.Logs += "Error - $($_.Exception.ToString())"

    }

    return $returnObj
}

function Create-PkgDownloadContentLocally{
    param
    (
        
        $DistributionPointName,
        $DistributionPointGroupName,
        $PackageFolderName,
        $DeployCollectionName,
        $PackageFolderPath,
        $SourcePath
    )
    $returnObj = New-ResultObject
    try
    {
                $PackageName = "QCTestPkg_" + [datetime]::Now.ToString('HH:mm')
                $Package = New-CMPackage –Name $PackageName –Path $SourcePath
                $PackageId = $Package.PackageID
                Set-CMPackage -Id $PackageId -DistributionPriority Low | Out-Null
                New-CMProgram -PackageId $PackageId -StandardProgramName "Edge" -CommandLine "MicrosoftEdgeSetup.exe" | Out-Null
                Start-CMContentDistribution -PackageId $PackageId -DistributionPointName $DistributionPointName -DistributionPointGroupName $DistributionPointGroupName | Out-Null
                ##Sleeping for 5 minutes
                Start-Sleep -Seconds 300
                $DistributionStatus = Get-CMDistributionStatus -Id $PackageId
                $ReplicationSuccess=$DistributionStatus.NumberSuccess
                $ReplicationInprog=$DistributionStatus.NumberInProgress
                $DeploymentStatus = Start-CMPackagedeployment -PackageName $PackageName -ProgramName "Edge" -CollectionName $DeployCollectionName -StandardProgram -DeployPurpose Available -FastNetworkOption DownloadContentFromDistributionPointAndRunLocally -SlowNetworkOption DownloadContentFromDistributionPointAndLocally
                $DeploymentStatus = Get-CMPackageDeployment -PackageId $PackageId
                $Package = Get-CMPackage -Id $PackageId
                
                $Path = $PackageFolderPath + '\' + $PackageFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $PackageFolderName -Path $PackageFolderPath
                  }
                Move-CMObject -InputObject $Package -FolderPath $Path
                $TestSet = @()
                $TestSet += @{PackageName = $PackageName; 
                              PackageId = $PackageId;
                              StandardProgramName=$StandardProgramName;
                              DistributionStatus=$DistributionStatus;
                              DeploymentStatus=$DeploymentStatus;
                              ReplicationSuccess=$ReplicationSuccess;
                              ReplicationInprog=$ReplicationInprog

                            }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-Application{
    param
    (
       
        $DistributionPointGroupName,
        $DeployCollectionName,
        $ApplicationFolderName,
        $ApplicationFolderPath,
        $AppSourcePath

        
    )
    $returnObj = New-ResultObject
    try
    {
                $ApplicationName = "QCAppTest_" + [datetime]::Now.ToString('HH:mm')
                $Id=New-CMApplication -Name $ApplicationName -LocalizedName $ApplicationName
                $ApplicationID = $Id.CI_ID
                $DeploymentType=Add-CMDeploymentType -ApplicationName $ApplicationName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation $AppSourcePath -MsiInstaller -DeploymentTypeName "App1"
                $DisplayName=$DeploymentType.LocalizedDisplayName
                Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName
                $AppId=New-CMApplicationDeployment -CollectionName $DeployCollectionName -Name $ApplicationName -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -Verbose
                $AppModelId=$AppId.AppModelID
                $Application=Get-CMApplication -Name $ApplicationName
                Export-CMApplication -Name $ApplicationName -Path "I:\test.zip" -IgnoreRelated -OmitContent -Comment "Application export" -Force
                
                $Path = $ApplicationFolderPath + '\' + $ApplicationFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $ApplicationFolderName -Path $ApplicationFolderPath
                  }
                Move-CMObject -InputObject $Application -FolderPath $Path
                $folderPath  = "I:\test.zip"
                If(!(test-path $folderPath))
                  {
                  $Exported="Application not Exported successfully"
                  }
                  else
                  {
                   $Exported="Application Exported successfully"
                  }

                $TestSet = @()
                $TestSet += @{ApplicationName = $ApplicationName; 
                              ApplicationID = $ApplicationID;
                              DisplayName=$DisplayName;
                              AppModelId = $AppModelId;
                              Exported = $Exported;
                              folderPath=$folderPath

                            }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-AppxApplication{
    param
    (
       
        $DistributionPointGroupName,
        $DistributionPointName,
        $DeployCollectionName,
        $ApplicationFolderName,
        $ApplicationFolderPath,
        $AppxAppSourcePath

        
    )
    $returnObj = New-ResultObject
    try
    {
                $ApplicationName = "QCAppxAppTest_" + [datetime]::Now.ToString('HH:mm')
                $Id=New-CMApplication -Name $ApplicationName -LocalizedName $ApplicationName
                $ApplicationID = $Id.CI_ID
                $DeploymentType=Add-CMDeploymentType -ApplicationName $ApplicationName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation $AppxAppSourcePath -Windows8AppInstaller -DeploymentTypeName "MSX App"
                $DisplayName=$DeploymentType.LocalizedDisplayName
                Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName
                $AppId=New-CMApplicationDeployment -CollectionName $DeployCollectionName -Name $ApplicationName -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -Verbose
                $AppModelId=$AppId.AppModelID
                $Application=Get-CMApplication -Name $ApplicationName
                $Path = $ApplicationFolderPath + '\' + $ApplicationFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $ApplicationFolderName -Path $ApplicationFolderPath
                  }
                Move-CMObject -InputObject $Application -FolderPath $Path

                $TestSet = @()
                $TestSet += @{ApplicationName = $ApplicationName; 
                              ApplicationID = $ApplicationID;
                              DisplayName=$DisplayName;
                              AppModelId = $AppModelId
                              

                            }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-AppwithDeeplink{
    param
    (
       
        $DistributionPointGroupName,
        $DistributionPointName,
        $UserCollectionName,
        $ApplicationFolderName,
        $ApplicationFolderPath,
        $AppxAppSourcePath

        
    )
    $returnObj = New-ResultObject
    try
    {
                $ApplicationName = "QCDeeplinkAppTest_" + [datetime]::Now.ToString('HH:mm')
                $Id=New-CMApplication -Name $ApplicationName -LocalizedName $ApplicationName
                $ApplicationID = $Id.CI_ID
                $DeploymentType = Add-CMDeploymentType -ApplicationName $ApplicationName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation 'https://www.microsoft.com/en-us/store/apps/microsoft-power-bi/9nblgggzlxn1' -WinPhone8DeeplinkInstaller -DeploymentTypeName 'DeeplinkAppTest'
                $DisplayName=$DeploymentType.LocalizedDisplayName
                #Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName
                $AppId=New-CMApplicationDeployment -CollectionName $UserCollectionName -Name $ApplicationName -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -Verbose
                $AppModelId=$AppId.AppModelID
                $Application=Get-CMApplication -Name $ApplicationName
                $Path = $ApplicationFolderPath + '\' + $ApplicationFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $ApplicationFolderName -Path $ApplicationFolderPath
                  }
                Move-CMObject -InputObject $Application -FolderPath $Path

                $TestSet = @()
                $TestSet += @{ApplicationName = $ApplicationName; 
                              ApplicationID = $ApplicationID;
                              DisplayName=$DisplayName;
                              AppModelId = $AppModelId
                              

                            }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-DependencyApp{
    param
    (
       
        $DistributionPointGroupName,
        $DistributionPointName,
        $DeployCollectionName,
        $ApplicationFolderName,
        $ApplicationFolderPath,
        $AppSourcePath,
        $DependencySource

        
    )
    $returnObj = New-ResultObject
    try
    {
                $ApplicationName = "QCContosoTestApp1" + [datetime]::Now.ToString('HH:mm')
                $Id=New-CMApplication -Name $ApplicationName -LocalizedName $ApplicationName
                $ApplicationID = $Id.CI_ID
                $DeploymentType=Add-CMDeploymentType -ApplicationName $ApplicationName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation $DependencySource -MsiInstaller -DeploymentTypeName "Test App 1"
                $DisplayName=$DeploymentType.LocalizedDisplayName
                Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName
                $AppId=New-CMApplicationDeployment -CollectionName $DeployCollectionName -Name $ApplicationName -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -Verbose
                $AppModelId=$AppId.AppModelID
                $Application=Get-CMApplication -Name $ApplicationName
                $Path = $ApplicationFolderPath + '\' + $ApplicationFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $ApplicationFolderName -Path $ApplicationFolderPath
                  }
                Move-CMObject -InputObject $Application -FolderPath $Path
                ##Create dependency Application
                $DependentAppName = "QCContosoTestApp2" + [datetime]::Now.ToString('HH:mm')
                $Id=New-CMApplication -Name $DependentAppName -LocalizedName $DependentAppName
                $ApplicationID = $Id.CI_ID
                $DeploymentType=Add-CMDeploymentType -ApplicationName $DependentAppName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation $AppSourcePath -MsiInstaller -DeploymentTypeName "Test App 2"
                $DisplayName=$DeploymentType.LocalizedDisplayName
                Start-CMContentDistribution -ApplicationName $DependentAppName -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName
                $AppId=New-CMApplicationDeployment -CollectionName $DeployCollectionName -Name $DependentAppName -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -Verbose
                $AppModelId=$AppId.AppModelID
                $Application=Get-CMApplication -Name $DependentAppName
                $Dependency=Get-CMDeploymentType -ApplicationName $DependentAppName |New-CMDeploymentTypeDependencyGroup -GroupName TestApp |Add-CMDeploymentTypeDependency -DeploymentTypeDependency (Get-CMDeploymentType -ApplicationName $ApplicationName) -IsAutoInstall $true
                $DependentAppName=$Dependency.LocalizedDisplayName
                $DependentAppID=$Dependency.CI_ID
                Move-CMObject -InputObject $Application -FolderPath $Path
                $TestSet = @()
                $TestSet += @{DependentAppName = $DependentAppName;
                              DependentAppID = $DependentAppID

                            }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-SupersededApp{
    param
    (
       
        $DistributionPointGroupName,
        $DistributionPointName,
        $DeployCollectionName,
        $ApplicationFolderName,
        $ApplicationFolderPath,
        $AppxAppSourcePath,
        $SupersedSource,
        $DependencySource

        
    )
    $returnObj = New-ResultObject
    try
    {
                $ApplicationName = "QCAppxSupersedenceApp_" + [datetime]::Now.ToString('HH:mm')
                $Id=New-CMApplication -Name $ApplicationName -LocalizedName $ApplicationName
                $ApplicationID = $Id.CI_ID
                $DeploymentType=Add-CMDeploymentType -ApplicationName $ApplicationName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation $AppxAppSourcePath -Windows8AppInstaller -DeploymentTypeName "MSX App"
                $DisplayName=$DeploymentType.LocalizedDisplayName
                $supseded = Get-CMDeploymentType -ApplicationName $ApplicationName
                Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName
                $AppId=New-CMApplicationDeployment -CollectionName $DeployCollectionName -Name $ApplicationName -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -Verbose
                $AppModelId=$AppId.AppModelID
                $Application=Get-CMApplication -Name $ApplicationName
                $Path = $ApplicationFolderPath + '\' + $ApplicationFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $ApplicationFolderName -Path $ApplicationFolderPath
                  }
                Move-CMObject -InputObject $Application -FolderPath $Path

                #Create Supersedent Apx App
                $SupersedAppName = "QCAppxSupersedingApp_" + [datetime]::Now.ToString('HH:mm')
                $Id=New-CMApplication -Name $SupersedAppName -LocalizedName $SupersedAppName
                $SuperAppID = $Id.CI_ID
                $DeploymentType=Add-CMDeploymentType -ApplicationName $SupersedAppName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation $SupersedSource -Windows8AppInstaller -DeploymentTypeName "MSX App"
                $DisplayName=$DeploymentType.LocalizedDisplayName
                $supseding = Get-CMDeploymentType -ApplicationName $SupersedAppName
                $Superseding = Add-CMDeploymentTypeSupersedence -SupersedingDeploymentType $supseding -SupersededDeploymentType $supseded -IsUninstall $false
                $supersedingStatus=$Superseding.IsSuperseding
                Start-CMContentDistribution -ApplicationName $SupersedAppName -DistributionPointGroupName $DistributionPointGroupName -DistributionPointName $DistributionPointName
                $AppId=New-CMApplicationDeployment -CollectionName $DeployCollectionName -Name $SupersedAppName -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -Verbose
                $AppModelId=$AppId.AppModelID
                $Application=Get-CMApplication -Name $SupersedAppName
                $Path = $ApplicationFolderPath + '\' + $ApplicationFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $ApplicationFolderName -Path $ApplicationFolderPath
                  }
                Move-CMObject -InputObject $Application -FolderPath $Path

                $TestSet = @()
                $TestSet += @{SupersedAppName = $SupersedAppName; 
                              ApplicationID = $ApplicationID;
                              DisplayName=$DisplayName;
                              SuperAppID = $SuperAppID;
                              supersedingStatus = $supersedingStatus
                              

                            }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Check-DCMEvaluation{
    
    $returnObj = New-ResultObject
    try
    {
                $DCMEvaluation = Get-ExecutionPolicy
                if($DCMEvaluation -eq 'RemoteSigned')
                {
                 Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
                 $DCMEvaluation = Get-ExecutionPolicy
                 }
                $TestSet = @()
                $TestSet += @{DCMEvaluation = $DCMEvaluation
                              }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-GlobalConditions{
   param
    (
       
        $GlobalConditionName,
        $GlobalcondFileName,
        $GlobalCondWqlName,
        $DistributionPointGroupName,
        $DistributionPointName,
        $DeployCollectionName,
        $ApplicationFolderName,
        $ApplicationFolderPath,
        $AppSourcePath
        
    )
    
    $returnObj = New-ResultObject
    try
    {
                ###create Global condition type Registry
                $RegCondition = Get-CMGlobalCondition -Name $GlobalConditionName
                $CIID = $RegCondition.CI_UniqueID
                $LocalizedDisplayName = $RegCondition.LocalizedDisplayName
                if($LocalizedDisplayName -eq $GlobalConditionName)
                {
                  Remove-CMGlobalCondition -Name $GlobalConditionName -Force
                }
               
                  $GloCondition = New-CMGlobalCondition -Name $GlobalConditionName -DeviceType Windows -RegistryHive LocalMachine -KeyName 'Test' -Description 'Created by Automation for QC'
                  $GloConditionID = $GloCondition.CI_UniqueID
                  $GloConditionType = $GloCondition.DataType

                ###create Global condition type File

                $FileCondition = Get-CMGlobalCondition -Name $GlobalcondFileName
                $CIID = $FileCondition.CI_UniqueID
                $LocalizedDisplayName = $FileCondition.LocalizedDisplayName
                if($LocalizedDisplayName -eq $GlobalcondFileName)
                {
                  Remove-CMGlobalCondition -Name $GlobalcondFileName -Force
                }

                 #Create the text file for global condition type file
                 $OutputPath = "$PSScriptRoot" 
                 #$timeStamp = (Get-Date).ToString("yyyy-MM-dd hh mm ss")
                 $ReportPath = "{0}\GlobalCondFolder" -f $OutputPath
                 if(!(Test-Path $ReportPath -ErrorAction SilentlyContinue))
                  {
                    New-Item -ItemType Directory -Path $ReportPath -Force
                   }
                 $GlobalConditionFile = "{0}\GlobalConditionFile.txt" -f $ReportPath
               
                  $GloConditionFile = New-CMGlobalConditionFile -Name $GlobalcondFileName -FilePath $ReportPath -Description 'Test global condition type file for QC'
                  $GloConditionFileID = $GloConditionFile.CI_UniqueID
                  $GloConditionFileType = $GloConditionFile.DataType
                
                ###create Global condition type WqlQuery
                $WqlCondition = Get-CMGlobalCondition -Name $GlobalCondWqlName
                $CIID = $WqlCondition.CI_UniqueID
                $LocalizedDisplayName = $WqlCondition.LocalizedDisplayName
                if($LocalizedDisplayName -eq $GlobalCondWqlName)
                {
                  Remove-CMGlobalCondition -Name $GlobalCondWqlName -Force
                }
                $GloConditionWql = New-CMGlobalConditionWqlQuery -Name $GlobalCondWqlName -DataType String -Namespace 'root\cimv2' -Class 'win32_computersystem' -Property 'model'
                $GloConditionWqlID = $GloConditionWql.CI_UniqueID
                $GloConditionWqlType = $GloConditionWql.DataType
                $TestSet = @()
                $TestSet += @{GloConditionID = $GloConditionID;
                              GloConditionType = $GloConditionType;
                              ApplicationName = $ApplicationName;
                              GloConditionFileID = $GloConditionFileID;
                              GloConditionFileType = $GloConditionFileType;
                              GloConditionWqlID = $GloConditionWqlID ;
                              GloConditionWqlType = $GloConditionWqlType
                              }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-DirectMembershipCollection{
    param
    (
        $PrimarySiteCode,
        $PrimarySiteServer,
        $SiteCode,
        $Computers,
        $LimitingCollectionName,
        $CollectionFolderName,
        $CollectionFolderPath
          
    )
    $returnObj = New-ResultObject
    try
    {
                $ConnectionInfo = Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServer
                $CollectionName = "QCCheckDirectCollection_" + [datetime]::Now.ToString('HH:mm')
                $Collection = New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollectionName
                $collectionId = $Collection.CollectionID
                foreach($Computer in $Computers) {
                 Add-CMDeviceCollectionDirectMembershipRule  -CollectionId $collectionId -ResourceId $(get-cmdevice -Name $Computer).ResourceID
                 }
                $DeviceCollectionDirectMembershipRule=Get-CMDeviceCollectionDirectMembershipRule -CollectionId $collectionId
                $Path = $CollectionFolderPath + '\' + $CollectionFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $CollectionFolderName -Path $CollectionFolderPath
                  }
                $Collection1 = Get-CMDeviceCollection -Id $collectionId
                Move-CMObject -InputObject $Collection1 -FolderPath $Path
                $TestSet = @()
                $TestSet += @{CollectionName = $CollectionName; 
                              CollectionId = $collectionId;
                              DeviceCollectionDirectMembershipRule = $DeviceCollectionDirectMembershipRule
                              }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    finally
    {
        Disconnect-SiteServer
    }
    return $returnObj
}

function Create-CollectionWithQueryMembership{
    param
    (        
        $LimitingCollectionName,
        $DPMachineNameSubstring        
    )
    $returnObj = New-ResultObject
    try
    {
        
                $CollectionName = "QCCheckQueryCollection_" + [datetime]::Now.ToString('HH:mm:ss')
                $Collection = New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollectionName
                $collectionId = $Collection.CollectionID
                $QueryExpression = "select SMS_R_System.ResourceNames from  SMS_R_System where SMS_R_System.ResourceNames like '%$DPMachineNameSubstring%'"
                Add-CMDeviceCollectionQueryMembershipRule -RuleName $CollectionName -CollectionId $collectionId -QueryExpression $QueryExpression | Out-Null
                $DeviceCollectionQueryMembership = Get-CMDeviceCollectionQueryMembershipRule -CollectionId $collectionId
                $CollectionReplicationStatus = Get-CMDeviceCollection -Id $collectionId
                $Id=Remove-CMDeviceCollection -Id $collectionId -Force
                $TestSet = @()
                $TestSet += @{CollectionName = $CollectionName; 
                              CollectionId = $collectionId;
                              DeviceCollectionQueryMembership=$DeviceCollectionQueryMembership;
                              CollectionReplicationStatus=$CollectionReplicationStatus;
                              Id = $Id
                            }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-CollectionWithInculdeMembership{
    param
    (
        
        $LimitingCollectionName,
        $IncludeCollectionName,
        $CollectionFolderName,
        $CollectionFolderPath
        
    )
    $returnObj = New-ResultObject
    try
    {
                
                $CollectionName = "QCCheckIncludeCollection_" + [datetime]::Now.ToString('HH:mm:ss')
                $Collection = New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName $LimitingCollectionName
                $collectionId = $Collection.CollectionID
                Add-CMDeviceCollectionIncludeMembershipRule -CollectionId $collectionId -IncludeCollectionName $IncludeCollectionName | Out-Null
                $DeviceCollectionIncludeMembership = Get-CMDeviceCollectionIncludeMembershipRule -CollectionId $collectionId
                $Collection1 = Get-CMDeviceCollection -Id $collectionId
                
                $Path = $CollectionFolderPath + '\' + $CollectionFolderName
                If(!(test-path $Path))
                  {
                    New-Item -Name $CollectionFolderName -Path $CollectionFolderPath
                  }
                Move-CMObject -InputObject $Collection1 -FolderPath $Path
                $TestSet = @()
                $TestSet += @{CollectionName = $CollectionName; 
                              CollectionId = $collectionId;
                              DeviceCollectionIncludeMembership=$DeviceCollectionIncludeMembership
                             
                            }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Get-ExchangeConnectorServer{
    param
    (
        $PrimarySiteCode,
        $PrimarySiteServer,
        $SiteCode
    )
    $returnObj = New-ResultObject
    try
    {
        Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServer | Out-Null
        $ExchangeConnector = Get-CMExchangeServer -SiteCode $SiteCode | Select ExchangeServer, SiteCode, ServerType
        $ExchangeServers = @()
        if($ExchangeConnector)
        {
            $ExchangeServers += @{ExchangeServer = $ExchangeConnector.ExchangeServer; ServerType=$ExchangeConnector.ServerType}
        }
        $returnObj.Output = $ExchangeServers
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    finally
    {
        Disconnect-SiteServer
    }
    return $returnObj
}

function Get-AppPools {
    param
    (
        $PrimarySiteCode,
        $PrimarySiteServer,
        $SiteCode,
        $ExpectedAppPoolNames
    )
    $returnObj = New-ResultObject
    try
    {
        Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServer | Out-Null
        $MPServersList = Get-CMSiteRole -RoleName "SMS Management Point" -SiteCode $SiteCode | Select NetworkOSPath, SiteCode
        $AppPools = @()
        foreach($MPServer in $MPServersList)
        {
            
            $MPServer = $MPServer.NetworkOSPath.Replace("\\","")
            $MPAppPool=Invoke-Command -ComputerName $MPServer -ScriptBlock {
                Import-Module WebAdministration
                Get-ChildItem IIS:\AppPools\* | select Name, State
                }
            foreach($AppPool in $MPAppPool)
            {
                if($AppPool.Name -in $ExpectedAppPoolNames)
                {
                    $AppPools += @{PoolName = $AppPool.Name; PoolState = $AppPool.State; MPServer = $MPServer; ExpectedState = "Started" }
                }
            }                                
        }
        $returnObj.Output = $AppPools
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    finally
    {
        Disconnect-SiteServer
    }
    return $returnObj
}

function Get-ScanCmpltdCount{
	    param
    (
        $SiteSQLServerName,
        $SiteSQLDBName
    )
    $returnObj = New-ResultObject
    try
    {
       $SqlQuery = "declare @NoHrs Int = 4
        declare @olddate datetime
        declare @NullVal datetime
        set @olddate=DATEADD(HOUR,-@NoHrs, getutcdate())
        set @NullVal = CONVERT(datetime,'1/1/1980')
        declare @dn1 table (clients numeric, SiteCode varchar(3),statename varchar(20))
        declare @dn2 table (SiteCode varchar(3), totals numeric)
        declare @dn3 table (SiteCode varchar(3), pclients numeric, tstatename varchar(50))
        insert into @dn1(clients,SiteCode,statename)
        select count(*)as clients,site.sms_assigned_sites0 as SiteCode,statename 
        from v_updateScanStatus upp 
        join v_statenames stat on stat.stateid = upp.lastscanstate 
        join v_RA_System_SMSAssignedSites site on site.resourceid = upp.resourceid
        JOIN v_GS_OPERATING_SYSTEM OS on OS.ResourceID = UPP.ResourceID
        join v_GS_POWER_MANAGEMENT_CAPABILITIES pow on upp.ResourceID = pow.ResourceID
        and stat.topictype ='501' and upp.lastscanpackagelocation like'http%'
        and lastscantime >@olddate
        where statename in ('Scan Completed','Scan Failed') --and site.sms_assigned_sites0 in ('PS1','PS2')
        and OS.Caption0 not like '%Microsoft Windows 10%Technical Preview%' -- excluding Win10 TP
        and LastErrorCode != '-2016409966' --excluding GP Conflict errors
        and (pow.PreferredPMProfile0 IS NOT NULL and pow.PreferredPMProfile0 != 2) -- 2 and NULL are for Laptops. Rest are desktops.
        group by upp.lastscanstate,stat.statename,site.sms_assigned_sites0 
        order by site.sms_assigned_sites0,clients desc
        insert into @dn2(SiteCode,totals)
        select SiteCode as SiteCode, SUM(clients) from @dn1 group by SiteCode
        insert into @dn3(SiteCode,pclients,tstatename)
        select t1.SiteCode as SiteCode,(clients/totals*100),statename from @dn1 as t1, @dn2 as t2 where t1.SiteCode = t2.SiteCode 
        select * from @dn3 PIVOT (sum(pclients) for [tstatename] in ([Scan completed],[Scan failed]) ) as A"

        $ScanCount = Invoke-Sqlcmd -ServerInstance $SiteSQLServerName -Database $SiteSQLDBName -Query $SqlQuery -ErrorAction SilentlyContinue
        $ScanResults = @()
        if($ScanCount)
        {
            $ScanResult = $ScanCount.'Scan completed'
            $ScanResults += @{ScanResult = $ScanResult; SQLServerName = $SiteSQLServerName; UnexpectedScanCount = 0}
        }
        $returnObj.Output = $ScanResults
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

    function Get-MPServers{
    param
    (
        $PrimarySiteCode,
        $PrimarySiteServer,
        $SiteCode
    )
    $returnObj = New-ResultObject
    try
    {
        Connect-SiteServer -SiteCode $PrimarySiteCode -ProviderMachineName $PrimarySiteServer | Out-Null
        $MPServersList = Get-CMSiteRole -RoleName "SMS Management Point" -SiteCode $SiteCode | Select NetworkOSPath, SiteCode
        $MPServers = @()
        foreach($MPServer in $MPServersList)
        {
            
                $MPServer = $MPServer.NetworkOSPath.Replace("\\","")
                $MPServers += @{ServerName = $MPServer}
        }
        $returnObj.Output = $MPServers
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    finally
    {
        Disconnect-SiteServer
    }
    return $returnObj
}

function Get-ClientVersion{
	param
    (
        $SiteSQLServerName,
        $SiteSQLDBName,
        $ExpectedClientVersion,
        $SQLServerClientsCollection
    )
    $returnObj = New-ResultObject
    try
    {
    $SqlQuery = "select top 1 name, ClientVersion from [dbo].[$SQLServerClientsCollection] where ClientVersion = '$ExpectedClientVersion'"
    $ClientVersion = Invoke-Sqlcmd -ServerInstance $SiteSQLServerName -Database $SiteSQLDBName -Query $SqlQuery
    $VersionResult= $ClientVersion.'ClientVersion'
    $returnObj.Output = $VersionResult
    $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

function Get-LastHWScan{
	param
    (
        $SiteSQLServerName,
        $SiteSQLDBName  
    )
    $returnObj = New-ResultObject
    try
    {
    Start-Sleep -Seconds 600
$SqlQuery = "select vrs.name0 , ch.LastHW from v_CH_ClientSummary ch
Join V_R_System vrs on vrs.ResourceID = ch.ResourceID
where vrs.name0='$env:COMPUTERNAME'"
$LastHWScan = Invoke-Sqlcmd -ServerInstance $SiteSQLServerName -Database $SiteSQLDBName -Query $SqlQuery
$Result = @()
$HWResult= $LastHWScan.'LastHW'
$ComputerName=$LastHWScan.name0
$Results += @{HWResult = $HWResult;
              ComputerName = $ComputerName
               }

        $returnObj.Output = $Results
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
  }

  function InitiatePolicies{
	    
    $returnObj = New-ResultObject
    try
    {

    $HardwareInventoryCycle = Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}"
    $HWResult=$HardwareInventoryCycle.PSComputerName
    $DiscoveryDataCollectionCycle = Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000003}"
    $DiscoveryDataResult = $DiscoveryDataCollectionCycle.PSComputerName
    $MachinePolicyEvaluationCycle = Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}"
    $MachinePolicyResult = $MachinePolicyEvaluationCycle.PSComputerName
    $Results = @()
    $Results += @{HWResult = $HWResult;
                  DiscoveryDataResult = $DiscoveryDataResult;
                  MachinePolicyResult = $MachinePolicyResult
                }

        $returnObj.Output = $Results
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

#region for Security & Compliance
function Create-ADR{
    param
    (
        
        $DPGroupName,
        $CollectionName,
        $ADRDescription,
        $ArticleId,
        $DeployPackageLocation,
        $Languages,
        $ADRName
          
    )
    $returnObj = New-ResultObject
   try
    {
        
                
                # Create Software Update Deployment Package
                $ADRPkg = Get-CMSoftwareUpdateDeploymentPackage -Name $ADRName
                $Name = $ADRPkg.Name
                if($Name -eq $ADRName)
                {
                  Remove-CMSoftwareUpdateDeploymentPackage -Name $ADRName -Force
                }
               
                $NewDeploymentPackage = New-CMSoftwareUpdateDeploymentPackage -Name $ADRName -Path $DeployPackageLocation
                Start-CMContentDistribution -DeploymentPackageId $NewDeploymentPackage.PackageID -DistributionPointGroupName $DPGroupName
                ##Create ADR
                $ADR = Get-CMSoftwareUpdateAutoDeploymentRule -Name $ADRName
                $Name = $ADR.Name
                if($Name -eq $ADRName)
                {
                  Remove-CMSoftwareUpdateAutoDeploymentRule -Name $ADRName -Force
                }
                $NewADR = New-CMSoftwareUpdateAutoDeploymentRule `
                          -Name $ADRName `
                          -Description $ADRDescription `
                          -CollectionName $CollectionName `
                          -AddToExistingSoftwareUpdateGroup $False `
                          -EnabledAfterCreate $False `
                          -VerboseLevel AllMessages `
                          -ArticleId $ArticleId `
                          -Superseded $False `
                          -UpdateClassification "Security Updates" `
                          -RunType DoNotRunThisRuleAutomatically `
                          -UseUtc $False `
                          -UserNotification DisplaySoftwareCenterOnly  `
                          -SuppressRestartServer $True `
                          -SuppressRestartWorkstation $True `
                          -GenerateFailureAlert $False `
                          -GenerateSuccessAlert $False `
                          -DeploymentPackageName $ADRName `
                          -Location $DeployPackageLocation `
                          -DownloadFromInternet $True `
                          -LanguageSelection $Languages `
                          -DownloadFromMicrosoftUpdate $False `
                          -NoInstallOnUnprotected $False `
                          -NoInstallOnRemote $False `
                          -DeployWithoutLicense $True `
                          -AvailableImmediately $True `
                          -DeadlineImmediately $True 
                $NewADRName = $NewADR.Name
                Invoke-CMSoftwareUpdateAutoDeploymentRule -Name $NewADRName
                $ADRNew = Get-CMSoftwareUpdateAutoDeploymentRule -Name $NewADRName
                $LastErrorCode = $ADRNew.LastErrorCode
                $TestSet = @()
                $TestSet += @{NewADRName = $NewADRName; 
                              LastErrorCode = $LastErrorCode
                              
                              }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    
        
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Get-SUG{
    param
    (
        
        $ADRName
        
    )
    $returnObj = New-ResultObject
   try
    {
                $SUGs = (get-cmsoftwareupdategroup).LocalizedDisplayName
                $Pattern = $ADRName +' '+ (Get-Date).ToString("yyyy-MM-dd") 
                foreach($Name In $SUGs){ if($Name -match $Pattern) { $SugName="$($Name)"}}
                $Sug = Get-CMSoftwareUpdategroup -Name $SugName
                $LocalizedDisplayName = $Sug.LocalizedDisplayName
                
                  
                $TestSet = @()
                $TestSet += @{LocalizedDisplayName = $LocalizedDisplayName 
                              
                              
                              }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    
        
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-SUG{
    param
    (
        
        $DPGroupName,
        $CollectionName,
        $SugName,
        $ArticleId,
        $DeployPackageLocation,
        $ADRName
        
          
    )
    $returnObj = New-ResultObject
   try
    {
        
                # Create Software Update Deployment Package
                $SugPkg = Get-CMSoftwareUpdateDeploymentPackage -Name $ADRName
                $PackageID = $SugPkg.PackageID
                if($SugPkg -eq $null)
                {
                 $NewDeploymentPackage = New-CMSoftwareUpdateDeploymentPackage -Name $ADRName -Path $DeployPackageLocation
                 Start-CMContentDistribution -DeploymentPackageId $NewDeploymentPackage.PackageID -DistributionPointGroupName $DPGroupName
                 $PackageID = $NewDeploymentPackage.PackageID
                }
               
                ##Create Software Update Group
                $CMUpdate = Get-CMSoftwareUpdate -ArticleId $ArticleId
                $SUGMembers = $CMUpdate.CI_ID
                $Sug = Get-CMSoftwareUpdategroup -Name $SugName
                $LocalizedDisplayName = $Sug.LocalizedDisplayName
                if($LocalizedDisplayName -eq $SugName)
                {
                  Remove-CMSoftwareUpdategroup -Name $SugName -Force
                }
                $SUG = New-CMSoftwareUpdategroup -Name $SugName -UpdateID $SUGMembers
                $NewSug = $SUG.LocalizedDisplayName 
                $SUGCIID = $SUG.CI_ID
                $SugDeployment = New-CMSoftwareUpdateDeployment `
                                 -SoftwareUpdateGroupName $SugName `
                                 -CollectionName $CollectionName `
                                 -DeploymentName 'QCAutoDeploy' `
                                 -DeploymentType 'Required' `
                                 -SendWakeUpPacket $False `
                                 -VerbosityLevel AllMessages `
                                 -TimeBasedOn LocalTime `
                                 -UserNotification DisplaySoftwareCenterOnly `
                                 -SavedPackageId $PackageID `
                  
                  
                $TestSet = @()
                $TestSet += @{NewSug = $NewSug; 
                              SUGCIID = $SUGCIID
                              
                              }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    
        
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}

function Create-SUGDeployment{
    param
    (
        $SugName,
        $CollectionName
    )
    $returnObj = New-ResultObject
   try
    {
        
                ##Create Depoyment for existing SUG
                $SugDeployment = New-CMSoftwareUpdateDeployment `
                                 -SoftwareUpdateGroupName $SugName `
                                 -CollectionName $CollectionName `
                                 -DeploymentName 'SecondDeploytoExistingSUG' `
                                 -DeploymentType 'Required' `
                                 -SendWakeUpPacket $False `
                                 -VerbosityLevel AllMessages `
                                 -TimeBasedOn LocalTime `
                                 -UserNotification DisplaySoftwareCenterOnly
                
                $DeploymentID = $SugDeployment.AssignmentID              
                $DeploymentName = $SugDeployment.AssignmentName
                $QuickScan=Invoke-CMEndpointProtectionScan -DeviceCollectionName $CollectionName -ScanType Quick
                  
                $TestSet = @()
                $TestSet += @{DeploymentName = $DeploymentName; 
                              DeploymentID = $DeploymentID;
                              QuickScan = $QuickScan
                              
                              }
                            
        
        $returnObj.Output = $TestSet
        $returnObj.IsError = $false
    }
    
        
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
}
#endregion

#region SecurityCompliance Client Side functions
function InitiateSecurityPolicies{
	    
    $returnObj = New-ResultObject
    try
    {

    $SoftwareUpdatesEvaluationCycle = Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000108}"
    $SoftwareEvaluationCycleResult=$SoftwareUpdatesEvaluationCycle.PSComputerName
    $SoftwareUpdateScanCycle = Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000113}"
    $SoftwareUpdateScanCycleResult = $SoftwareUpdateScanCycle.PSComputerName
    $Results = @()
    $Results += @{SoftwareEvaluationCycleResult = $SoftwareEvaluationCycleResult;
                  SoftwareUpdateScanCycleResult = $SoftwareUpdateScanCycleResult
                  
                }

        $returnObj.Output = $Results
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

function Get-ScanLogs {
    param
    (
        
        $ExpectedLogScanFile,
        $ExpectedScanStatus
    )
    $returnObj = New-ResultObject
    $FileLogData = @()
    try
    {
      $FileData = Get-Content $ExpectedLogScanFile -ErrorAction SilentlyContinue
      if($FileData)
        {
          $Log = $FileData | Select-String -Pattern $ExpectedScanStatus -AllMatches
         }
         
          $FileLogData += @{Log = $Log
                  }
                       
      
        $returnObj.Output = $FileLogData
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get-SoftwareUpdateLogs {
    param
    (
        
        $ExpectedErrorLogDeploymentFile,
        $ExpectedErrorPattern
    )
    $returnObj = New-ResultObject
    $FileLogData = @()
    try
    {
      $FileContent = Get-Content $ExpectedErrorLogDeploymentFile -ErrorAction SilentlyContinue
      if($FileContent)
        {
          $LogData = $FileContent | Select-String -Pattern $ExpectedErrorPattern -AllMatches
         }
         
          $FileLogData += @{LogData = $LogData
                  }
                       
      
        $returnObj.Output = $FileLogData
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get_EPAgentGeneratedPolicies {
    param
    (
        
        $ExpectedErrorLogDeploymentFile,
        $ExpectedErrorPattern
    )
    $returnObj = New-ResultObject
    $FileLogData = @()
    try
    {
      $EPAgentGeneratedPolicies = Get-Item -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\CCM\EPAgent\GeneratedPolicy -ErrorAction SilentlyContinue  | select Property -ExpandProperty Property
      if($EPAgentGeneratedPolicies -eq $null)
      {
        $EPAgentGeneratedPolicies = Get-Item -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\CCM\EPAgent\LastAppliedPolicy -ErrorAction SilentlyContinue  | select Property -ExpandProperty Property
      }
         
          $FileLogData += @{EPAgentGeneratedPolicies = $EPAgentGeneratedPolicies}                        
      
        $returnObj.Output = $FileLogData
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

function Get_GuidFolder {
    param
    (
        
        $WindowsDefender
        
    )
    $returnObj = New-ResultObject
    $FileData = @()
    try
    {
      $GuidFolderName = Get-ChildItem $WindowsDefender | select Name -ExpandProperty Name -Last 1
      $GuidFolderDateTime=Get-ChildItem $WindowsDefender | select LastWriteTime -ExpandProperty LastWriteTime -Last 1
      
         
          $FileData += @{GuidFolderName = $GuidFolderName;
                         GuidFolderDateTime = $GuidFolderDateTime
                            }  
                       
      
        $returnObj.Output = $FileData
        $returnObj.IsError = $false
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

#endregion

<#
[BEGIN] Template Function

function Do-Something {
    param
    (
        [Parameter(Position=0, ParameterSetName="ComputerName")]
        $ComputerName,
        [Parameter(Position=0, ParameterSetName="PSSession")]
        $PSSession
    )
    $returnObj = New-ResultObject
    try
    {
        if(!$PSSession) 
        {
            $PSSessionDetails = Start-PSSession -ComputerName $ServerName
            $returnObj.Logs += $PSSessionDetails.Logs
            $PSSession = $PSSessionDetails.Output
            $ComputerName = $PSSession.ComputerName
        }
        if($PSSession -eq $null)
        {
            $returnObj.Logs += "Error - Unable to establish PSSession"
        }
        else
        {
            ## Main logic
        }
    }
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    return $returnObj
}

[END] Template Function
#>
