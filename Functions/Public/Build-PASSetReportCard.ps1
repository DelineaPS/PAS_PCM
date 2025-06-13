###########
#region ### global:Build-PASSetReportCard # CMDLETDESCRIPTION : Builds a metric report card for a PAS Set :
###########
function global:Build-PASSetReportCard
{
    <#
    .SYNOPSIS
    Builds a report card for a particular PAS Set. Can be time-intensive with larger Sets.

    .DESCRIPTION
	This cmdlet builds a custom object that will hold a large amount of information about a PAS Set. This
	information includes permissions about the Set, its Members, and Member Permissions. It can also attempt
	to find any member conflicts that occur with other PAS Sets.

	This report card object can assist with analysis of member objects to help determine what accounts may
	be considered appropriate for a data migration.

	The final report card text will be stored in the .AnalysisReport property of the object.

	These report cards may take some time to generate, especially if the Set has a large number
	of account objects in them. 

    .PARAMETER Name
    Gets Sets by these names. This can be comma separated for multiple Sets. 

    .PARAMETER Sets
	Gets Sets by their Set objects. This can be an array of PASSet objects.

    .PARAMETER SetConflicts
    Attempt to determine Set Conflicts with the report card. Can only be used if $global:PASSetConflicts exists.
	Use Find-PASSetConflicts first.

    .INPUTS
    You can pipe PASSet objects into this cmdlet.

    .OUTPUTS
    This function outputs a custom PSObject object.

    .EXAMPLE
    C:\PS> Build-PASSetReportCard -Name "BlueCrab Accounts"
    Gets the PAS Set "BlueCrab Accounts" first (via Get-PASSet), then attempts to build the 
	report card for this Set.

    .EXAMPLE
    C:\PS> Build-PASSetReportCard -Sets $BlueCrabSet
    Builds the report card for the PAS Set stored in the $BlueCrabSet variable. This version
	is faster to complete that using the -Name parameter version.

	.EXAMPLE
    C:\PS> Build-PASSetReportCard -Sets $BlueCrabSet -SetConflicts
    Builds the report card for the PAS Set stored in the $BlueCrabSet variable. This version
	is faster to complete that using the -Name parameter version. This will also attempt to
	determine if there are any Set Conflicts for the members of the $BlueCrabSet object. This
	version needs Find-PASSetConflicts to be executed first.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (

		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The name of the Set to Get", ParameterSetName = "Name")]
		[System.String[]]$Name,

		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Set to get the Report Card", ParameterSetName = "Set")]
		[PASSet[]]$Sets,

		[Parameter(Mandatory = $false, HelpMessage = "The Set Conflicts to use")]
		[Switch]$SetConflicts
    )

	# verifying an active PAS connection
    Verify-PASConnection

	if (-Not ($SetConflicts.IsPresent))
	{
		Write-Warning ("-SetConflicts was not specified. Skipping Set Conflict determination.")
	}

	if ($SetConflicts.IsPresent -and ($global:PASSetConflicts -eq $null))
	{
		Write-Warning ("-SetConflicts was specified, but `$global:PASSetConflicts was not found.")
		Write-Warning ("Run Find-PASSetConflicts first and try again.")
		return
	}

	# ArrayList to hold our objects
	$SetArray = New-Object System.Collections.ArrayList

	# if we are using the name parameter, get those Set objects
	if ($PSBoundParameters.ContainsKey('Name'))
	{
		foreach ($n in $Name)
		{
			Write-Verbose ("Adding Set [{0}] by Name" -f $n)
			$SetArray.Add((Get-PASSet -Name $n)) | Out-Null
		}
	}# if ($PSBoundParameters.ContainsKey('Name'))
	else # otherwise add the 
	{
		Write-Verbose ("Adding [{0}] PASSet objects." -f $Sets.Count)
		$SetArray.AddRange(@($Sets)) | Out-Null
	}

	# creating an ArrayList for the return output
	$ReportCards = New-Object System.Collections.ArrayList

	# for each set we are working with
	foreach ($set in $SetArray)
	{
		# if it isn't a VaultAccount set, then skip it
		if ($set.ObjectType -ne "VaultAccount")
		{
			Write-Host ("Set [{0}] is not a VaultAccount Set, skipping." -f $set.Name)
			continue
		}

		Write-Host ("Working Set [{0}]" -f $Set.Name)
		# ArrayList to store the report card text output
		$AnalysisOutput = New-Object System.Collections.ArrayList

		# starting values for time
		$AnalysisStartTime = (Get-Date)
		$AnalysisEndTime   = $null

		# anytime we see additions to $AnalysisOutput, it is for the report card text
		$AnalysisOutput.Add(("Set : [{0}]" -f $Set.Name)) | Out-Null
		$AnalysisOutput.Add(("#####################################")) | Out-Null

		# review the permissions on the Set
		$SetPermissions = $Set.reviewPermissions()

		# get the account objects for this set
		$SetMemberObjects = Get-PASAccount -Uuid $Set.MembersUuid

		# if there are members
		if ($SetMemberObjects -ne $false)
		{
			# multithreaded grab to review permissions on each account object in this Set
			$MemberPermissions = $SetMemberObjects | Foreach-Object -Parallel {

				# aliasing and reasserting connection and script information
				$member = $_
				$PASConnection         = $using:PASConnection
				$PASSessionInformation = $using:PASSessionInformation

				# for each script in our PAS_PCMScriptBlocks
				foreach ($script in $using:PAS_PCMScriptBlocks)
				{
					# add it to this thread as a script, this makes all classes and functions available to this thread
					. $script.ScriptBlock
				}

				# have the acocunt review the permissions on itself
				$member.reviewPermissions()
			} 
		}
		else
		{
			Write-Host ("  - Set [{0}] has 0 accounts." -f $Set.Name)
			continue
		}

		# more text additions to the text report card
		$AnalysisOutput.Add((" >>> Set to Folder <<<")) | Out-Null
		$AnalysisOutput.Add(($SetPermissions | Select-Object PrincipalName,PASPermissions,SSPermissions)) | Out-Null

		$AnalysisOutput.Add((("Number of Accounts in Set: [{0}]" -f $SetMemberObjects.Count))) | Out-Null

		$AnalysisOutput.Add((("Accounts in this set have the following default checkout lifetimes:"))) | Out-Null
		$AnalysisOutput.Add(($SetMemberObjects.PolicyOptions | Where-Object -Property PolicyOption -eq "/PAS/VaultAccount/DefaultCheckoutTime" | Group-Object -Property PolicyValue | Select-Object @{label="Minutes";Expression={$_.Name}},Count | Out-String)) | Out-Null
		
		$AnalysisOutput.Add((("Accounts in this set have the following Password Rotation Duration:"))) | Out-Null
		$AnalysisOutput.Add(($SetMemberObjects.PolicyOptions | Where-Object -Property PolicyOption -eq "/PAS/ConfigurationSetting/VaultAccount/PasswordRotateDuration" | Group-Object -Property PolicyValue | Select-Object @{label="Minutes";Expression={$_.Name}},Count | Out-String)) | Out-Null
		
		$AnalysisOutput.Add((("Number of Unique Secret Templates: [{0}]" -f ($SetMemberObjects | Select-Object -ExpandProperty SSSecretTemplate -Unique | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null

		$AnalysisOutput.Add((("Unique Secret Templates: [{0}]" -f ($SetMemberObjects | Select-Object -ExpandProperty SSSecretTemplate -Unique) -join ","))) | Out-Null

		$AnalysisOutput.Add((("The Following Objects exist as part of this set:"))) | Out-Null

		$AnalysisOutput.Add(($SetMemberObjects | Group-Object -Property Username | Select-Object @{label="Username";Expression={$_.Name}},Count | Out-String)) | Out-Null

		$AnalysisOutput.Add((("Number of Managed Accounts in this Set: [{0}]" -f ($SetMemberObjects | Sort-Object -Property SSName -Unique | Where-Object -Property isManaged -eq $true | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null
		$AnalysisOutput.Add((("Number of Unmanaged Accounts in this Set: [{0}]" -f ($SetMemberObjects | Sort-Object -Property SSName -Unique | Where-Object -Property isManaged -eq $false | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null

		$AnalysisOutput.Add(("Number of Objects where Parent Object Last Health Check > 365+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.SourceLastHealthCheck -lt (Get-Date).AddDays(-365)}) | Measure-Object | Select-Object -ExpandProperty Count))) | Out-Null
		$AnalysisOutput.Add(("Number of Objects where Parent Object Last Health Check > 90+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.SourceLastHealthCheck -lt (Get-Date).AddDays(-90)}) | Measure-Object | Select-Object -ExpandProperty Count))) | Out-Null
		$AnalysisOutput.Add(("Number of Objects where Parent Object Last Health Check > 60+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.SourceLastHealthCheck -lt (Get-Date).AddDays(-60)}) | Measure-Object | Select-Object -ExpandProperty Count))) | Out-Null
		$AnalysisOutput.Add(("Number of Objects where Parent Object Last Health Check > 30+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.SourceLastHealthCheck -lt (Get-Date).AddDays(-30)}) | Measure-Object | Select-Object -ExpandProperty Count))) | Out-Null
		$AnalysisOutput.Add(("Number of Objects where Parent Object Last Health Check < 30 days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.SourceLastHealthCheck -gt (Get-Date).AddDays(-30)}) | Measure-Object | Select-Object -ExpandProperty Count))) | Out-Null
		$AnalysisOutput.Add(("Number of Objects where Parent Object Last Health Check < 10 days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.SourceLastHealthCheck -gt (Get-Date).AddDays(-10)}) | Measure-Object | Select-Object -ExpandProperty Count))) | Out-Null

		$AnalysisOutput.Add((("Number of Object where Object itself Last Health Check > 365+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.LastHealthCheck -lt (Get-Date).AddDays(-365)}) | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null
		$AnalysisOutput.Add((("Number of Object where Object itself Last Health Check > 90+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.LastHealthCheck -lt (Get-Date).AddDays(-90)}) | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null
		$AnalysisOutput.Add((("Number of Object where Object itself Last Health Check > 60+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.LastHealthCheck -lt (Get-Date).AddDays(-60)}) | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null
		$AnalysisOutput.Add((("Number of Object where Object itself Last Health Check > 30+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.LastHealthCheck -lt (Get-Date).AddDays(-30)}) | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null
		$AnalysisOutput.Add((("Number of Object where Object itself Last Health Check < 30+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.LastHealthCheck -gt (Get-Date).AddDays(-30)}) | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null
		$AnalysisOutput.Add((("Number of Object where Object itself Last Health Check < 10+ days : [{0}]" -f (($SetMemberObjects | Where-Object {$_.LastHealthCheck -gt (Get-Date).AddDays(-10)}) | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null

		$AnalysisOutput.Add((" >>> Parent Object Health Status <<<")) | Out-Null
		$AnalysisOutput.Add(($SetMemberObjects.SourceHealthStatus | Group-Object | Select-Object @{label="Response";Expression={$_.Name}},Count | Out-String)) | Out-Null

		$AnalysisOutput.Add((" >>> Account Health Check <<<")) | Out-Null
		$AnalysisOutput.Add(($SetMemberObjects.Healthy | Group-Object | Select-Object @{label="Response";Expression={$_.Name}},Count | Out-String)) | Out-Null

		$AnalysisOutput.Add((" >>> Account Credential Type <<<")) | Out-Null
		$AnalysisOutput.Add(($SetMemberObjects | Group-Object -Property CredentialType | Select-Object @{label="CredentialType";Expression={$_.Name}},Count | Out-String)) | Out-Null

		$LikelyCreators  = $SetMemberObjects.PermissionRowAces | Where-Object {$_.isInherited -eq $false -and $_.PrincipalType -eq "User" -and $_.PASPermission.GrantInt -eq 1769725}
		
		$AnalysisOutput.Add((" >>> Likely Creators <<<")) | Out-Null
		$AnalysisOutput.Add((("Likely Creators Count: [{0}]" -f $LikelyCreators.Count))) | Out-Null
		$AnalysisOutput.Add((("----------------------"))) | Out-Null
		$AnalysisOutput.Add(($LikelyCreators | Group-Object -Property PrincipalName | Select-Object Name,Count | Out-String)) | Out-Null

		# if SetConflicts was used
		if ($SetConflicts.IsPresent)
		{
			# add text
                        $AnalysisOutput.Add((" >>> Set Conflicts <<<")) | Out-Null

			$AnalysisOutput.Add((("Number of Accounts in Set: [{0}]" -f $set.MembersUuid.Count))) | Out-Null

			# try to determine conflicting member accounts
			if ($conflictingmembers = $global:PASSetConflicts | Where-Object {$_.Type -eq "VaultAccount" -and $SetMemberObjects.SSname -contains $_.Name})
			{
				$AnalysisOutput.Add((("- conflicts found."))) | Out-Null

				$conflictingsets = New-Object System.Collections.ArrayList

				$uniqueconflictingsets = $conflictingmembers | Select-Object -Property InSets -Unique

				foreach ($conflict in $uniqueconflictingsets)
				{
					$j = $conflict.InSets.Split(",")

					foreach ($i in $j)
					{
						if ($i -ne $Set.Name -and $uniqueconflictingsets -notcontains $i)
						{
							$conflictingsets.Add($i) | Out-Null
						}
					}
				}# foreach ($conflict in $uniqueconflictingsets)

				$AnalysisOutput.Add((("Total conflicting sets     : [{0}]" -f ($conflictingsets    | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null
				$AnalysisOutput.Add((("Total conflicting accounts : [{0}]" -f ($conflictingmembers | Measure-Object | Select-Object -ExpandProperty Count)))) | Out-Null
				
				foreach ($conflictingset in $conflictingsets)
				{
					$AnalysisOutput.Add((("- Conflicting Set [{0}] has [{1}] conflicts." -f ($conflictingset, ($conflictingmembers | Where-Object {$_.InSets -like "*$conflictingset*"}).Count)))) | Out-Null
				}
			
			}# if ($conflictingmembers = $global:PASSetConflicts | Where-Object {$_.Type -eq "VaultAccount" -and $SetMemberObjects.SSname -contains $_.Name})
			else
			{
				$AnalysisOutput.Add((("- No conflicts found!"))) | Out-Null
			}
		}# if ($SetConflicts.IsPresent)

		# noninherits are principals that don't have an inherited permission (from global rules or Set inheritence)
		$Noninherits = $MemberPermissions | Where-Object {$_.isInherited -eq $false}

		$AnalysisOutput.Add(("")) | Out-Null
		$AnalysisOutput.Add((" >>> Odditity Principals <<<")) | Out-Null; $AnalysisOutput.Add(("")) | Out-Null

		# odditity members are members have a specific assignment on an individual account object in a set
		$OdditityMembers = $SetMemberObjects | Where-Object {$_.PermissionRowAces.isInherited -eq $false -and $_.PermissionRowAces.PASPermission.GrantInt -ne 1769725}

		# if there are odditiy members
		if (($OdditityMembers | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
		{
			$AnalysisOutput.Add((("Odditity Principals found!"))) | Out-Null
			
			foreach ($member in $OdditityMembers)
			{
				$AnalysisOutput.Add(((" - For account : [{0}]" -f $member.SSName))) | Out-Null
				
				foreach ($permissionrowace in ($member.PermissionRowAces | Where-Object {$_.isInherited -eq $false -and $_.PASPermission.GrantInt -ne 1769725}))
				{
					$AnalysisOutput.Add((("   - Principal [{0}] has the following permissions:" -f $permissionrowace.PrincipalName))) | Out-Null
					$AnalysisOutput.Add((("   - Permisions: [{0}]" -f $permissionrowace.PASPermission.GrantString))) | Out-Null
				}
			}# foreach ($member in $OdditityMembers)
		}# if (($OdditityMembers | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
		else
		{
			$AnalysisOutput.Add(("No Odditity Principals found.")) | Out-Null
		}

		# multithreaded grab to review permissions on each account object in this Set
		$AccountActivity = $SetMemberObjects | ForEach-Object -Parallel {

			# aliasing and reasserting connection and script information
			$obj = $_
			$PASConnection         = $using:PASConnection
			$PASSessionInformation = $using:PASSessionInformation

			# for each script in our PAS_PCMScriptBlocks
			foreach ($script in $using:PAS_PCMScriptBlocks)
			{
				# add it to this thread as a script, this makes all classes and functions available to this thread
				. $script.ScriptBlock
			}

			# have the acocunt get its own account activity
			$obj.getAccountActivity()
		} |# $SetMemberObjects | ForEach-Object -Parallel {
		ForEach-Object -Begin { $i = 0 } -Process { 
				
			$Completed = $($i/($SetMemberObjects | Measure-Object | Select-Object -ExpandProperty Count)*100)
			# incrementing result count
			$i++
			# update progress bar
			Write-Progress -Activity "Getting Account Activity" -Status ("{0} out of {1} Complete" -f $i,$SetMemberObjects.Count) -PercentComplete $Completed -CurrentOperation ("Current: [{0}]" -f $_.SSName)
			# returning the result
			$_
		}# | ForEach-Object -Begin { $i = 0 } -Process {

		# if there is AccountActivity found
		if ($SetMemberObjects.AccountActivity -ne $null)
		{
			$AnalysisOutput.Add(("Recent Account Activity by Date")) | Out-Null
			$AnalysisOutput.Add(($SetMemberObjects.AccountActivity | Select-Object @{label="When";Expression={$_.When.ToShortDateString()}} | Group-Object -Property When | Select-Object @{label="Date";Expression={$_.Name}},Count | Out-String)) | Out-Null
			
			$AnalysisOutput.Add(("Recent Account Activity by EventType")) | Out-Null
			$AnalysisOutput.Add(($SetMemberObjects.AccountActivity | Group-Object -Property EventType | Select-Object @{label="Date";Expression={$_.Name}},Count | Out-String)) | Out-Null
		}
		
		### Wrapping Up ###
		$AnalysisEndTime = (Get-Date)

		$FinalSetObject = New-Object PSObject

		$FinalSetObject | Add-Member -MemberType NoteProperty -Name SetName           -Value $Set.Name
		$FinalSetObject | Add-Member -MemberType NoteProperty -Name Set               -Value $Set
		$FinalSetObject | Add-Member -MemberType NoteProperty -NAme SetPermissions    -Value $SetPermissions
		$FinalSetObject | Add-Member -MemberType NoteProperty -Name Members           -Value $SetMemberObjects
		$FinalSetObject | Add-Member -MemberType NoteProperty -Name MemberPermissions -Value $MemberPermissions
		$FinalSetObject | Add-Member -MemberType NoteProperty -Name LikelyCreators    -Value $LikelyCreators

		if ($SetConflicts.IsPresent)
		{
			$FinalSetObject | Add-Member -MemberType NoteProperty -Name Conflicts -Value $conflictingmembers
		}

		$FinalSetObject | Add-Member -MemberType NoteProperty -Name Noninherits       -Value $Noninherits
		$FinalSetObject | Add-Member -MemberType NoteProperty -Name OdditityMembers   -Value $OdditityMembers

		$FinalSetObject | Add-Member -MemberType NoteProperty -Name StartTime         -Value $AnalysisStartTime
		$FinalSetObject | Add-Member -MemberType NoteProperty -Name EndTime           -Value $AnalysisEndTime
		$FinalSetObject | Add-Member -MemberType NoteProperty -Name AnalysisRunTime   -Value ($AnalysisEndTime - $AnalysisStartTime)
		$FinalSetObject | Add-Member -MemberType NoteProperty -Name AnalysisReport    -Value $AnalysisOutput
		
		$ReportCards.Add($FinalSetObject) | Out-Null
	}

	# clean up some memory
	[System.GC]::GetTotalMemory($true) | Out-Null
	[System.GC]::Collect()

	return $ReportCards
}# function global:Build-PASSetReportCard
#endregion
###########