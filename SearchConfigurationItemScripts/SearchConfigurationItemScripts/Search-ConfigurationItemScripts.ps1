<#
.SYNOPSIS
    Search SCCM Configure Item Scripts for keywords
.DESCRIPTION
    Powershell script used to used to search through Configuration Item
    Scripts in SCCM for a list of keywords.
    It works by connecting to SCCM and searches through the scripts of each 
    Configuration Item for the keywords. An HTML Report is also generated in 
    the local filepath with the results.
.PARAMETER SiteCode
    SCCM Site Code
.PARAMETER SiteServer
    SCCM Site Server
.PARAMETER KeyWords
    The list of keywords you want to search for in all of the scripts
.NOTES
    Version:        1.0
    Creation date:  04/20/2023
    Purpose/Change: Open Source example
#>

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

function Search-ConfigurationItemScripts($KeyWords)
{
    Write-Output "Getting all Configuration Items"
    $CIs = Get-CMConfigurationItem -Fast
    foreach ($CI in $CIs)
    {
        Add-LogInfo -LogLevel Information -LogMsg "Looking into CI - $($CI.LocalizedDisplayName)"
        $Setting = $CI | Get-CMComplianceSetting
        if ($setting.SourceType -eq "Script")
        {
            $ScriptLanguage = $Setting.DiscoveryScript.ScriptLanguage
            $ScriptContent = $Setting.DiscoveryScript.Script
            foreach($KeyWord in $KeyWords.split(","))
            {
                if ($ScriptContent.ToLower() -like "*$($KeyWord.ToLower())*") 
                {
                    Write-Output "Found KeyWord - $($KeyWord) in Configuration Item - $($CI.LocalizedDisplayName)"
                    $global:SearchResults += [PSCustomObject] @{KeyWord=$KeyWord
                        Name=$CI.LocalizedDisplayName 
                        ObjectType="Configuration Item"}
                }
            }
        }
    }
}

Write-Output "------------------- Starting Search Configuration Item Scripts Automation -------------------"
$ErrorActionPreference = "Stop"
$SiteCode = "" #Enter SCCM Site Code
$SiteServer = "" #Enter SCCM Site Server Fully Qualified Domain Name
$KeyWords = "" #Enter your comma separated keywords in the string
Write-Output "KeyWord(s) are - $KeyWords"
$global:SearchResults = @()

#Connect to SCCM
Connect-ConfigMgrProvider -SiteCode $SiteCode -SiteServer $SiteServer
Search-ConfigurationItemScripts -KeyWords $KeyWords
Write-Output "Final Search Results: $($global:SearchResults)"
$ExecutionResultTable = Create-HTMLTable -TableData $global:SearchResults
$Body = "<b>Configuration Item Scripts Search Results</b><br>"
$Body += $ExecutionResultTable
$Body | ConvertTo-Html | Out-File -FilePath .\Search-ConfigurationItemScripts-Report.html