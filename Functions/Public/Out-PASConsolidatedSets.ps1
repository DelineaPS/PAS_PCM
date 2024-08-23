###########
#region ### global:Out-PASConsolidatedSets # CMDLETDESCRIPTION : Outputs the Consolidated Sets to txt and JSON files :
###########
function global:Out-PASConsolidatedSets
{
    <#
    .SYNOPSIS
    Outputs the Consolidated Sets to txt and JSON files.

    .DESCRIPTION
	This cdmlet takes Consolidated PAS Sets for a Secret Server Import and produces text files that report
	which accounts are suggested for Secret Server Folders. This is for the purpose of determining if the
	suggested consolidation is acceptable for the PAS Vault to Secret Server Vault migration effort.

	This also produces a JSON file with all of the account data so that this information can be acted upon
	via Get-PASAccount.
	
    .PARAMETER ConsolidatedSets
	The Consolidated PAS Sets to output file information.

	.PARAMETER TargetDirectory
	The target directory to output file information. Current directory is default if this parameter 
	is not specified.

	.PARAMETER JSONFileName
	The name of the json file that contains the consolidated information. Current filename is
	"_ConsolidatedSets.json" if this parameter is not specified.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function does not output anything.

    .EXAMPLE
    C:\PS> Out-PASConsolidatedSets -ConsolidatedSets $ConsolidatedSets -TargetDirectory "EPIC Sets" -JSONFileName "EPICSets.json"
	Takes the $ConsolidatedSets and creates output text files for migration review in the Target Directory
	"EPIC Sets" (from the current directory). This will also produce the json file "EPICSets.json" in the same
	directory for future use.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Consolidated Sets to output files.")]
		[PSObject]$ConsolidatedSets,

		[Parameter(Mandatory = $false, HelpMessage = "The target directory to create the files.")]
        [System.String]$TargetDirectory = ".",

		[Parameter(Mandatory = $false, HelpMessage = "The name json file that contains the consolidated set information.")]
        [System.String]$JSONFileName = "_ConsolidatedSets.json"
    )
	
	# if the provided $TargetDirectory doesn't exist, 
	if (-Not (Test-Path -Path $TargetDirectory))
	{
		# report not found and exit
		Write-Host ("Target directory [{0}] not found.")
		return $false
	}

	# for each ConsolidatedSet given to us
	foreach ($ConsolidatedSet in $ConsolidatedSets)
	{
		# new temp ArrayList for output
		$output = New-Object System.Collections.ArrayList

		# get the subfolder name
		$subfoldername = $ConsolidatedSet.SubFolder

		# adding principals
		$output.Add("Principals") | Out-Null
		$output.Add("----------") | Out-Null
		$output.Add(($ConsolidatedSet.Principals | Sort-Object PrincipalName,PASPermissions,SSPermissions | Get-Unique -AsString)) | Out-Null
		
		# line break
		$output.Add("") | Out-Null

		# then add the accounts
		$output.Add("Accounts") | Out-Null
		$output.Add("--------") | Out-Null
		$output.AddRange(@($ConsolidatedSet.Accounts | Sort-Object)) | Out-Null

		# now output the text file in our target directory
		$output | Out-File ("{0}\{1}.txt" -f $TargetDirectory, $subfoldername)
	}# foreach ($ConsolidatedSet in $ConsolidatedSets)

	# finally output the ConsolidatedSets as a json file in the same directory
	$ConsolidatedSets | ConvertTo-Json -Depth 3 | Out-File ("{0}\{1}" -f $TargetDirectory, $JSONFileName)
}# function global:Out-PASConsolidatedSets