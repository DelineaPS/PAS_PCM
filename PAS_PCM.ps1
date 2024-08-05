#######################################
#region ### MAIN ######################
#######################################

# setting the user and repo to target
$User = "dnlrv"
$Repo = "PAS_PCM"

# enter in any files you definitely want ignored
$FilesToIgnore = "LICENSE","README.md","PAS_PCM_local.ps1"

# version check if desired
if ($PSVersionTable.PSVersion.ToString() -lt 7.4)
{
	Write-Error "PowerShell version 7.4+ required."
	Exit 1
}#>

# setting Url values
$MainTreeUrl   = "https://api.github.com/repos/$User/$Repo/git/trees/main?recursive=1"
$BaseScriptUrl = "https://raw.githubusercontent.com/$User/$Repo/main/"

# get the main tree
$MainTree = Invoke-RestMethod -Method Get -Uri $MainTreeUrl

# get the directories and files as separate lists
$Directories = $MainTree.tree | Where-Object -Property type -eq tree | Select-Object -ExpandProperty path
$Files       = $MainTree.tree | Where-Object -Property type -eq blob | Select-Object -ExpandProperty path

# removing the files specified above
$FileUrlPaths = $Files | Where-Object {$FilesToIgnore -notcontains $_}

# ArrayList to hold ScriptBlocks
$PAS_PCMScriptBlocks = New-Object System.Collections.ArrayList

# for each directory in the repo
foreach ($directory in $Directories)
{
	# get the scripts that are in this directory, but use regex to ignore anything that starts with an underscore (_)
	$thisdirectoryscripts = $FileUrlPaths | Where-Object {$_ -match "$($directory)/(?!_)([a-zA-Z]+\-?[a-zA-Z]+\.ps1)"}

	# for each script found
	foreach ($script in $thisdirectoryscripts)
	{
		# set the url for the download
		$uri = ("{0}{1}" -f $BaseScriptUrl, $script)

		# new temp object for the ScriptBlock ArrayList
		$obj = New-Object PSCustomObject

		# getting the contents of that url as a download
		$scriptblock = ([ScriptBlock]::Create(((Invoke-WebRequest -Uri $uri).Content)))
	
		# setting properties
		$obj | Add-Member -MemberType NoteProperty -Name Name        -Value (($script.Split("/")[-1]))
		$obj | Add-Member -MemberType NoteProperty -Name Type        -Value $directory
		$obj | Add-Member -MemberType NoteProperty -Name Uri         -Value $uri
		$obj | Add-Member -MemberType NoteProperty -Name ScriptBlock -Value $scriptblock
	
		# adding our temp object to our ArrayList
		$PAS_PCMScriptBlocks.Add($obj) | Out-Null

		# and dot source it
		. $scriptblock
	}# foreach ($script in $thisdirectoryscripts)
}# foreach ($directory in $Directories)

# setting our ScriptBlock ArrayList to global
$global:PAS_PCMScriptBlocks = $PAS_PCMScriptBlocks

# initializing a List[PASConnection] if it is empty or null
$global:PASConnections = New-Object System.Collections.Generic.List[PASConnection]

#######################################
#endregion ############################
#######################################