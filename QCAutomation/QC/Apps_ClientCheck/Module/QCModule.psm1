## Standard result object from any function in this module
function New-ResultObject {
    return New-Object PSObject -Property @{Output = $null; IsError = $true; Logs = @()}
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
        New-Item -ItemType Directory -Path $ReportPath -Force
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
    $PreContext += "<p><img src='cid:QCPiechart.png' Alt='QC result - pie Chart'/></p>"
    
    ## Body - Main result table
    $ResultHtml = ConvertTo-HtmlReport -Head $Header -PreContent $PreContext -TestResult $TestResults.TestResult
    
    ## Export report to Html
    $ResultHtml | Out-File $OutputHtmlFileName -Force

    ## Export report to CSV
    $TestResult = $TestResults.TestResult
    $TestResult = $TestResult | Select @{N='Category';E={$_.Describe}}, @{N='TestSuite';E={$_.Context}}, @{N='TestCase';E={$_.Name}}, Result, @{N='Timetoexecute';E={$_.Time}}, FailureMessage
    $TestResult | Select Category, TestSuite, TestCase, Result, Timetoexecute, FailureMessage | Sort Category, TestSuite, TestCase | Export-Csv $OutputCSVFileName -NoTypeInformation -Force

}



function Get-X64App{
	    param
    (
        $AppName
        
    )
    $returnObj = New-ResultObject
    
    try
    {
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$AppName"} | Select-Object Id, Revision, IsMachineTarget, FullName, InstallState
    $AppID = $Application.Id
    $AppRev = $Application.Revision
    $AppTarget = $Application.IsMachineTarget
    $AppFullName = $Application.FullName
    $InstallState = $Application.InstallState
    If( $InstallState -eq 'NotInstalled')
       {
         ([wmiclass]'ROOT\ccm\ClientSdk:CCM_Application').Install($AppID, $AppRev, $AppTarget, 0, 'Normal', $False) | Out-Null
         Start-Sleep -Seconds 300
        }
    
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$AppName"} | Select-Object Id, FullName, InstallState
    $AppID = $Application.Id
    $AppFullName =$Application.FullName
    $InstallState = $Application.InstallState
    $Results = @()
    $Results += @{AppFullName = $AppFullName;
              AppID = $AppID;
              InstallState = $InstallState
               }
       #$resultData += New-Object PSObject -Property @{AppID=$AppID;AppFullName=$AppFullName;InstallState=$InstallState}
    $returnObj.Output = $Results
    $returnObj.IsError = $false
    }`
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

function Get-ModernApp{
	    param
    (
        $ModerApxApp
        
    )
    $returnObj = New-ResultObject
    
    try
    {
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$ModerApxApp"} | Select-Object Id, Revision, IsMachineTarget, FullName, InstallState
    $AppID = $Application.Id
    $AppRev = $Application.Revision
    $AppTarget = $Application.IsMachineTarget
    $AppFullName = $Application.FullName
    $InstallState = $Application.InstallState
    If( $InstallState -eq 'NotInstalled')
       {
         ([wmiclass]'ROOT\ccm\ClientSdk:CCM_Application').Install($AppID, $AppRev, $AppTarget, 0, 'Normal', $False) | Out-Null
         Start-Sleep -Seconds 300
        }
    
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$ModerApxApp"} | Select-Object Id, FullName, InstallState
    $AppID = $Application.Id
    $AppFullName =$Application.FullName
    $InstallState = $Application.InstallState
    $Results = @()
    $Results += @{AppFullName = $AppFullName;
              AppID = $AppID;
              InstallState = $InstallState
               }
       #$resultData += New-Object PSObject -Property @{AppID=$AppID;AppFullName=$AppFullName;InstallState=$InstallState}
    $returnObj.Output = $Results
    $returnObj.IsError = $false
    }`
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

    function Get-ModernDeeplinkApp{
	    param
    (
        $ModerDeeplinkApp
        
    )
    $returnObj = New-ResultObject
    
    try
    {
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$ModerDeeplinkApp"} | Select-Object Id, Revision, IsMachineTarget, FullName, InstallState
    $AppID = $Application.Id
    $AppRev = $Application.Revision
    $AppTarget = $Application.IsMachineTarget
    $AppFullName = $Application.FullName
    $InstallState = $Application.InstallState
    If( $InstallState -eq 'NotInstalled')
       {
         ([wmiclass]'ROOT\ccm\ClientSdk:CCM_Application').Install($AppID, $AppRev, $AppTarget, 0, 'Normal', $False) | Out-Null
         Start-Sleep -Seconds 300
        }
    
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$ModerDeeplinkApp"} | Select-Object Id, FullName, InstallState
    $AppID = $Application.Id
    $AppFullName =$Application.FullName
    $InstallState = $Application.InstallState
    $Results = @()
    $Results += @{AppFullName = $AppFullName;
              AppID = $AppID;
              InstallState = $InstallState
               }
       #$resultData += New-Object PSObject -Property @{AppID=$AppID;AppFullName=$AppFullName;InstallState=$InstallState}
    $returnObj.Output = $Results
    $returnObj.IsError = $false
    }`
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }
function Get-AvailableApp{
	    param
    (
        $AvailableApp
        
    )
    $returnObj = New-ResultObject
    
    try
    {
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$AvailableApp"} | Select-Object Id, Revision, IsMachineTarget, FullName, InstallState, ResolvedState
    $AppID = $Application.Id
    $AppFullName =$Application.FullName
    $ResolvedState = $Application.ResolvedState
      $Results = @()
      $Results += @{AppFullName = $AppFullName;
              AppID = $AppID;
              ResolvedState = $ResolvedState
               }

    $returnObj.Output = $Results
    $returnObj.IsError = $false
    }`
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

 function Get-SupersedesApp{
	    param
    (
        $SupersedesApp
        
    )
    $returnObj = New-ResultObject
    
    try
    {
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$SupersedesApp"} | Select-Object Id, Revision, IsMachineTarget, FullName, InstallState, ResolvedState
    $AppID = $Application.Id
    $AppFullName =$Application.FullName
    $ResolvedState = $Application.ResolvedState
      $Results = @()
      $Results += @{AppFullName = $AppFullName;
              AppID = $AppID;
              ResolvedState = $ResolvedState
               }

    $returnObj.Output = $Results
    $returnObj.IsError = $false
    }`
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

    function Get-InstalledApp{
	    param
    (
        $InstalledApp
        
    )
    $returnObj = New-ResultObject
    try
    {
    $Application = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -like "$InstalledApp"} | Select-Object Id, Revision, IsMachineTarget, FullName, InstallState, ResolvedState
    $AppID = $Application.Id
    $AppFullName =$Application.FullName
    $InstallState = $Application.InstallState
     $Results = @()
     $Results += @{AppFullName = $AppFullName;
              AppID = $AppID;
              InstallState = $InstallState
               }

    $returnObj.Output = $Results
    $returnObj.IsError = $false
    }`
    catch [System.Exception]
    {
        $returnObj.Logs += "Error - $($_.Exception.ToString())"
    }
    
    return $returnObj
    }

    
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

## Create collection