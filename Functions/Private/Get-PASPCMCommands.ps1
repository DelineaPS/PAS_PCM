###########
#region ### global:Get-PASPCMCommands # CMDLETDESCRIPTION : Displays all public cmdlets from the PAS_PCM module with a short description :
###########
function global:Get-PASPCMCommands
{
    <#
    .SYNOPSIS
    Displays all public cmdlets from the PAS_PCM module with a short description.

    .DESCRIPTION
	This cmdlet prints to console the names of all public cmdlets in this module with a short description of what the cmdlets
	do.

	This cmdlet works by parsing out the contents of the text in between the following regex statement in the script's code:
	CMDLETDESCRIPTION : (.*) : 

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom object that has two properties, CmdletName and Description.

    .EXAMPLE
    C:\PS> Get-PASPCMCommands
    Displays all cmdlets from the Functions\Public folder of the PAS_PCM module with a short description.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		# no param needed
    )

	# arraylist for PASPCM command descriptions
	$PASPCMcmddescriptions = New-Object System.Collections.ArrayList

	# for each scriptblock we have in the Functions\Public folder
	foreach ($scriptblock in ($PAS_PCMScriptBlocks | Where-Object -Property Type -eq "Functions\Public" | Sort-Object -Property Name))
	{
		# get the name, codeblock, and the description from the CMDLETDESCRIPTION line in each block
		$cmdletname = ($scriptblock.Name -split ".ps1")[0]
		$codeblock  = ($scriptblock.ScriptBlock)
		$description = ($codeblock | Out-String -Stream | Select-String 'CMDLETDESCRIPTION : (.*) :','$1') -replace '^.*CMDLETDESCRIPTION : (.*) :.*$','$1'

		# create a new custom object with the name of the cmdlet at a short description
		$obj = New-Object PSObject
		$obj | Add-Member -MemberType NoteProperty -Name CmdletName -Value $cmdletname
		$obj | Add-Member -MemberType NoteProperty -Name Description -Value $description

		# adding it to our arraylist
		$PASPCMcmddescriptions.Add($obj) | Out-Null
	}# foreach ($scriptblock in ($PAS_PCMScriptBlocks | Where-Object -Property Type -eq "Functions\Public" | Sort-Object -Property Name))

	# returning our array
	return $PASPCMcmddescriptions
}# function global:Get-PASPCMCommands
#endregion
###########
