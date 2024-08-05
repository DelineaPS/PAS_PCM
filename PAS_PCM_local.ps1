#######################################
#region ### MAIN ######################
#######################################

# version check if desired
if ($PSVersionTable.PSVersion.ToString() -lt 7.4)
{
	Write-Error "PowerShell version 7.4+ required."
	Exit 1
}#>

# getting directories
$Directories = Get-ChildItem -Recurse -Directory

# getting current Directory
$CurrentDirectory = Get-Location | Select-Object -ExpandProperty Path

# ArrayList to hold all our scripts
$PAS_PCMScripts = New-Object System.Collections.ArrayList

# ArrayList to hold ScriptBlocks
$PAS_PCMScriptBlocks = New-Object System.Collections.ArrayList

# for each directory we found
foreach ($directory in $Directories)
{
	# get the items in that directory
	$foldercontents = Get-ChildItem -Path $directory

	# use regex to only match .ps1 scripts that do NOT start with an underscore (_)
	$folderscripts = $foldercontents | Where-Object {$_.FullName -match '^.*\\(?!_)([a-zA-Z]+\-?[a-zA-Z]+\.ps1)$'}

	# add the short folder name as an extra property
	$folderscripts | Add-Member -MemberType NoteProperty -Name ScriptType -Value ($directory.FullName -replace "^$([Regex]::Escape($CurrentDirectory))\\(.*)$",'$1')
	
	# add it to our script ArrayList
	$PAS_PCMScripts.AddRange(@($folderscripts)) | Out-Null
}# foreach ($directory in $Directories)

# for each script we found
foreach ($script in $PAS_PCMScripts)
{
	# get the contents of the script
    $scriptcontents = Get-Content $script.FullName -Raw

    # new temp object for the ScriptBlock ArrayList
    $obj = New-Object PSCustomObject

    # getting the scriptblock
    $scriptblock = ([ScriptBlock]::Create(($scriptcontents)))

    # setting properties
    $obj | Add-Member -MemberType NoteProperty -Name Name        -Value $script.Name
	$obj | Add-Member -MemberType NoteProperty -Name Type        -Value $script.ScriptType
    $obj | Add-Member -MemberType NoteProperty -Name Path        -Value $script.FullName
    $obj | Add-Member -MemberType NoteProperty -Name ScriptBlock -Value $scriptblock

    # adding our temp object to our ArrayList
    $PAS_PCMScriptBlocks.Add($obj) | Out-Null

    # and dot source it
    . $scriptblock
}# foreach ($script in $PAS_PCMScripts)

# setting our ScriptBlock ArrayList to global
$global:PAS_PCMScriptBlocks = $PAS_PCMScriptBlocks

# initializing a List[PASConnection] if it is empty or null
$global:PASConnections = New-Object System.Collections.Generic.List[PASConnection]


#######################################
#endregion ############################
#######################################