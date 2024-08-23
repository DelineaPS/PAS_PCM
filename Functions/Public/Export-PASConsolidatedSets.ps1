###########
#region ### global:Export-PASConsolidatedSets # CMDLETDESCRIPTION : Prepares a .csv compatiable report on the consolidated set/folder structure :
###########
function global:Export-PASConsolidatedSets
{
    <#
    .SYNOPSIS
    Prepares a .csv compatiable report on the consolidated set/folder structure.

    .DESCRIPTION
	This cmdlet takes consolidated PAS Sets for a Secret Server Import and produces a csv like object that
	can be exported for review or other uses.

	The returned object will simply be compressed of three properties:

	For each account,
	  - FromSet - The Set the acount came from
	  - Account - The account name
	  - ToFolder - The recommended folder the account should go into
	
    .PARAMETER ConsolidatedSets
	The Consolidated PAS Sets to generate this csv object.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom PSObject object.

    .EXAMPLE
    C:\PS> Export-PASConsolidatedSets -ConsolidatedSets $ConsolidatedSets
	Takes the provided PAS Consolidated Sets and produces a by-account summary of the consolidation effort.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Consolidated Sets to report.")]
		[PSObject]$ConsolidatedSets
    )

	# getting all the subfolders
	$SetFolders = $ConsolidatedSets.SubFolder.Split(",") | Select-Object -Unique

	# ArrayList for our returned object
	$ConsolidatedReport = New-Object System.Collections.ArrayList

	# for each set folder
	foreach ($setfolder in $SetFolders)
	{
		# new rows ArrayList
		$rows = New-Object System.Collections.ArrayList

		# adding in all the rows that have this setfolder with this name
		$rows.AddRange(@($ConsolidatedSets | Where-Object -Property SubFolder -like "*$setfolder*")) | Out-Null

		# for each row we have
		foreach ($row in $rows)
		{
			# for each account in that row
			foreach ($account in $row.AccountIDs)
			{
				
				# new temp object
				$obj = New-Object PSObject

				# adding in the rest of the fields
				$obj | Add-member -MemberType NoteProperty -Name FromSet -Value $setfolder
				$obj | Add-Member -MemberType NoteProperty -Name Account -Value $account.SSName
				$obj | Add-Member -MemberType NoteProperty -Name AccountID -Value $account.ID
				$obj | Add-Member -MemberType NoteProperty -Name ToFolder -Value $row.SubFolder

				# if this entry isn't in the returning ArrayList, add it
				if (-Not ($ConsolidatedReport | Where-Object {$_.FromSet -eq $obj.FromSet -and $_.Account -eq $obj.Account -and $_.ToFolder -eq $obj.ToFolder}))
				{
					$ConsolidatedReport.Add($obj) | Out-Null
				}
			}# foreach ($account in $row.Accounts)
		}# foreach ($row in $rows)
	}# foreach ($setfolder in $SetFolders)

	return $ConsolidatedReport | Sort-Object Accounts,FromSet | Get-Unique -AsString
}# function global:Export-PASConsolidatedSets