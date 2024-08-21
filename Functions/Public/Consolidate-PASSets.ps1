###########
#region ### global:Consolidate-PASSets # CMDLETDESCRIPTION : Consolidates PAS Sets into a recommended folder structure for Secret Server Import :
###########
function global:Consolidate-PASSets
{
    <#
    .SYNOPSIS
    Consolidates PAS Sets into a recommended folder structure for Secret Server Import.

    .DESCRIPTION
	This cmdlet takes PAS Set Report Cards and consolidates them into a recommended folder structure for importing
	into Secret Server.

	By providing this cmdlet Set Report Cards, this will create a folder structure based on principal-permission
	separation. Consider the following PAS Sets:

	- Set 1 which has Accounts01-05, with Permissions A,B,C set to the Security Team.
	- Set 2 which has Accounts04-08, with Permissions A,B set to the Database Team.

	In this scenario Accounts04 and Accounts05 have overlap between the two Sets. This is known as a Set Conflict.
	This cmdlet will resolve these conflict via a method called "doublestacking" where overlapping account access
	will be provisioned as a new folder recommendation with stacking principal-permission access. From the above
	example, the following will be presented as a result:

	- Set 1 Folder will have Accounts01-03, with Permissions A,B,C set to the Security Team.
	- Set 2 Folder with have Accounts06-08, with Permissions A,B set to the Database Team.
	- Set 1/2 Folder will have Accounts04-05, with Permissions A,B,C set to the Security Team, and
	    Permissions A,B set to the Database Team.
	
	The output provided will be a custom object intended to be used as guidance for recommended folder structure
	and permissions during PAS Vault to Secret Server Cloud Vault migration.
	
    .PARAMETER SetReportCards
	The PAS Set Report Cards to provide for consolidation.

    .PARAMETER RemoveThese
	Removes the specified principals from the Principals column in the resulting object. This would be used
	to remove principals that have global access and would appear on every account. This simply removes those
	principals from being listed in the Princials property.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom PSObject object.

    .EXAMPLE
    C:\PS> Consolidate-PASSets -SetReportCards $SetReportCards
	Takes the provided PAS Set Report Cards and consolidates them into a recommended folder structure, using the 
	doublestacking method to resolve Set Conflicts.

    .EXAMPLE
    C:\PS> Consolidate-PASSets -SetReportCards $SetReportCards -RemoveThese "System Administrator","cloudadmin@domain"
	Takes th provided PAS Set Report Cards and consolidates them into a recommended folder structure, using the 
	doublestacking method to resolve Set Conflicts. Removes the principals "System Administrator" and "cloudadmin@domain"
	from being listed in any Principal columns.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Set Report Cards to consolidate.")]
		[PSObject[]]$SetReportCards,

		[Parameter(Mandatory = $false, HelpMessage = "Remove these principals from the Principals property on the returned object.")]
		[System.String[]]$RemoveThese
    )

	# some arraylists for storing data
	$AllSetReportCards = New-Object System.Collections.ArrayList
	$Conflicters       = New-Object System.Collections.ArrayList
	$Consolidation     = New-Object System.Collections.ArrayList

	# for each setname in the provided report cards
	foreach ($setname in $SetReportCards.SetName)
	{
		Write-Verbose ("Working with candidate [{0}]" -f $setname)

		# getting that set report card
		$thissetreportcard = $SetReportCards | Where-Object -Property SetName -eq $setname

		# add it to our all stack
		$AllSetReportCards.Add($thissetreportcard) | Out-Null

		# get the conflicts, if any
		$conflicts = $thissetreportcard.Conflicts

		# add ti our conflicters ArrayList
		$Conflicters.AddRange(@($conflicts)) | Out-Null
	}# foreach ($setname in $SetReportCards.SetName)

	# now get non conflicters
	$Nonconflicters = $SetReportCards.Members | Where-Object {$_.SSName -notin ($SetReportCards.COnflicts.Name | Select-Object -Unique)}

	# get the inset subfolders for our conflicters
	$SubFolders = $Conflicters | Select-Object -ExpandProperty InSets -Unique

	# for each subfolder for our conflicters
	foreach ($subfolder in $SubFolders)
	{
		# get the conflicts that relate to this subfolder
		$conflicts = $Conflicters | Where-Object -Property InSets -eq $subfolder

		# ArrayList for storing principals
		$principals = New-Object System.Collections.ArrayList

		# for each set in the conflict
		foreach ($set in ($conflicts.InSets.Split(",")))
		{
			# get the principal permissions for this set
			$a = ($AllSetReportCards | Where-Object -Property SetName -eq $set).SetPermissions | Select-Object PrincipalName,PASPermissions,SSPermissions

			# if -RemovedThese was used, remove those principals
			if ($PSBoundParameters.ContainsKey('RemoveThese'))
			{
				$a = $a | Where-Object {$RemoveThese -notcontains $_.PrincipalName}
			}

			# adding the unique principals to the principals ArrayList
			$principals.AddRange(@($a | Sort-Object PrincipalName,PASPermissions | Get-Unique -AsString)) | Out-Null
		}

		# new temp object for adding to our Consolidation ArrayList
		$obj = New-Object PSObject

		# adding properties and adding it to the Consolidation ArrayList
		$obj | Add-Member -MemberType NoteProperty -Name SubFolder -Value $subfolder
		$obj | Add-Member -MemberType NoteProperty -Name Accounts -Value $conflicts.Name
		$obj | Add-Member -MemberType NoteProperty -Name Principals -Value $principals
		$obj | Add-Member -MemberType NoteProperty -Name fromConflicting -Value $true
		$Consolidation.Add($obj) | Out-Null
	}# foreach ($subfolder in $SubFolders)

	### now for nonconflicters

	# for each nonconflicter
	foreach ($nonconflict in $NonConflicters)
	{
		# get the set report card where the account appears in
		$set = $AllSetReportCards | Where-Object {$_.Members.SSName -contains $nonconflict.SSName}

		# get the principal set permissions for this report card
		$principals = $set.SetPermissions | Select-Object PrincipalName,PASPermissions,SSPermissions

		# if -RemoveThese was used, remove those principals
		if ($PSBoundParameters.ContainsKey('RemoveThese'))
		{
			$principals = $principals | Where-Object {$RemoveThese -notcontains $_.PrincipalName}
		}

		# new temp object for adding to our Consolidation ArrayList
		$obj = New-Object PSObject

		# adding properties and adding it to the Consolidation ArrayList
		$obj | Add-Member -MemberType NoteProperty -Name SubFolder -Value $set.SetName
		$obj | Add-Member -MemberType NoteProperty -Name Accounts -Value $nonconflict.SSName
		$obj | Add-Member -MemberType NoteProperty -Name Principals -Value $principals
		$obj | Add-Member -MemberType NoteProperty -Name fromConflicting -Value $false
		$Consolidation.Add($obj) | Out-Null
	}# foreach ($nonconflict in $NonConflicters)

	# final ArrayList for the return
	$ConsolidatedSets = New-Object System.Collections.ArrayList	

	# for each subfolder that is unique
	foreach ($subfolder in ($Consolidation.SubFolder | Select-Object -Unique))
	{
		# get these consolidated sets
		$these = $Consolidation | Where-Object -Property SubFolder -eq $subfolder

		# new temp object
		$obj = New-Object PSObject

		# adding in the same properties as before, but making sure they are unique by removing duplicate entries
		$obj | Add-Member -MemberType NoteProperty -Name SubFolder -Value $subfolder
		$obj | Add-Member -MemberType NoteProperty -Name Accounts -Value ($these.Accounts | Select-Object -Unique)
		$obj | Add-member -MemberType NoteProperty -Name Principals -Value ($these.Principals | Sort-Object PrincipalName,PASPermissions | Get-Unique -AsString)
		$obj | Add-Member -MemberType NoteProperty -Name fromConflicting -Value ($these.fromConflicting | Select-Object -Unique)

		# adding it to our ConsolidatedSets return ArrayList
		$ConsolidatedSets.Add($obj) | Out-Null
	}# foreach ($subfol in ($Consolidation.SubFolder | Select-Object -Unique))

	return $ConsolidatedSets
}# function global:Consolidate-PASSets