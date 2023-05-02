<#
.SYNOPSIS
    Search Proactive Remediation Scripts for keywords
.DESCRIPTION
    Powershell script used to search through Proacive Remediation
    Scripts in Intune for a list of keywords. 
    It works by getting a Graph API token using an MSI Client Id
    and searches through the scripts of each Intune object using the Graph API.
    An HTML Report is also generated in the local filepath with the results.
.PARAMETER ClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Proactive Remediation Scripts
.PARAMETER KeyWords
    The list of keywords you want to search for in all of the scripts
.NOTES
    Version:        1.0
    Creation date:  4/20/2023
    Purpose/Change: Open Source example
#>

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

function Get-MsiAuthHeaders
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
    $Headers =  @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $AccessToken
    }
    return $Headers
}

function Search-ProactiveRemediationScripts($KeyWords) 
{
    try 
    {
        $ClientId = "" #Enter your Client Id for getting access token
        #This Client Id must have Graph API permission: DeviceManagementConfiguration.Read.All
        
        Write-Output "Getting microsoft graph api access headers using client id - $($ClientId)"
        $Headers = Get-MsiAuthHeaders -ResourceUri "https://graph.microsoft.com" -ClientId $ClientId
        $ProactiveRemediationsURI = " https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
        $ProactiveRemediations = Invoke-RestMethod -Uri "$ProactiveRemediationsURI" -Method Get -Headers $Headers -ErrorAction Stop -Verbose:$false
        foreach($ProactiveRemediation in $ProactiveRemediations.value)
        {
            $ProactiveRemediationURI = " https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($ProactiveRemediation.id)"
            $ProactiveRemediationReturn = Invoke-RestMethod -Uri $ProactiveRemediationURI -Method Get -Headers $Headers -ErrorAction Stop -Verbose:$false
            $DetectionScript = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($ProactiveRemediationReturn.detectionScriptContent))
            $RemediationScript = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($ProactiveRemediationReturn.remediationScriptContent))
            
            foreach($KeyWord in $KeyWords.split(","))
            {
                if ($DetectionScript -and $DetectionScript.ToLower() -like "*$($KeyWord.ToLower())*")
                {
                    Write-Output "Found KeyWord - $($KeyWord) in Proactive Remediation Detection Script - $($ProactiveRemediation.displayName)"
                    $global:SearchResults += [PSCustomObject] @{KeyWord=$KeyWord
                        Name=$ProactiveRemediation.displayName 
                        ObjectType="Proactive Remediation Detection Script"}
                }
                if ($RemediationScript -and $RemediationScript.ToLower() -like "*$($KeyWord.ToLower())*")
                {
                    Write-Output "Found KeyWord - $($KeyWord) in Proactive Remediation Remediation Script - $($ProactiveRemediation.displayName)"
                    $global:SearchResults += [PSCustomObject] @{KeyWord=$KeyWord
                        Name=$ProactiveRemediation.displayName 
                        ObjectType="Proactive Remediation Remediation Script"}
                }
            }
        }
    }
    catch {
        Write-Error $_
    }
}

Write-Output "------------------- Starting Search Proactive Remediation Scripts Automation -------------------"
$KeyWords = "" #Enter your comma separated keywords in the string
Write-Output "KeyWord(s) are - $KeyWords"
$global:SearchResults = @()
Search-ProactiveRemediationScripts -KeyWords $KeyWords
Write-Output "Final Search Results: $($global:SearchResults)"
$ExecutionResultTable = Create-HTMLTable -TableData $global:SearchResults
$Body = "<b>Proactive Remediation Scripts Search Results</b><br>"
$Body += $ExecutionResultTable
$Body | ConvertTo-Html | Out-File -FilePath .\Search-ProactiveRemediationScripts-Report.html