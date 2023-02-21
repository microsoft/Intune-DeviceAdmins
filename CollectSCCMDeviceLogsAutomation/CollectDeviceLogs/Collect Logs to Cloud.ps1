param
(
    [Parameter(Mandatory=$true)]
    $EscapedSASToken,
    [Parameter(Mandatory=$true)]
    $StorageURL,
    [Parameter(Mandatory=$true)]
    $FilesOrFolders
) 
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$SASToken =  [uri]::UnescapeDataString($EscapedSASToken) 

$FilesOrFoldersColletion =  $FilesOrFolders.Split(',', [StringSplitOptions]::RemoveEmptyEntries)
foreach ($FileOrFolder in $FilesOrFoldersColletion)
{
    if ((Test-Path -Path $FileOrFolder) -eq $false)
    {
        Write-Warning "'$FileOrFolders' does not exist"
        continue
    }
    $Headers = @{
        'x-ms-blob-type' = 'BlockBlob'
    }
    $FilesToUpload = Get-ChildItem -Path $FileOrFolder -Recurse |  Where-Object { ! $_.PSIsContainer } | %{$_.FullName}
    foreach ($File in $FilesToUpload)
    {
        $Uri = "{0}/$env:COMPUTERNAME/{1}{2}" -f $StorageURL, $File , $SASToken
        try 
        {
           Invoke-RestMethod  -Uri $Uri -Method Put -Headers $Headers -InFile $File | Out-Null
        }
        catch 
        {
            #file is being used by another process.
        }
    }
    Write-Output "File(s) Uploaded"
}