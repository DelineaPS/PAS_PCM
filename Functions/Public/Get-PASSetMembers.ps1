###########
#region ### global:Get-PASSetMembers # Gets the members of the PASSet.
###########
function global:Get-PASSetMembers
{
    <#
    .SYNOPSIS
    Gets the members of the PASSet.

    .DESCRIPTION
	Gets the members of a PASSet object. This will query the appropriate PAS tables for a small
	bit of information regarding each member of this Set. This information will be stored in
	the SetMembers property.

    .PARAMETER Sets
	The PASSet objects to get members. Will only accept PASSet type objects.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom class object that provides the set target 
	and the results of getting the Set Members.

    .EXAMPLE
    C:\PS> Get-PASSetMembers -Sets $PASSets
	For the provided PASSet objects, Get a small amount of informaiton about the members, and
	store them in the SetMembers property.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PAS Sets to get members", ParameterSetName = "Set")]
		[PASSet[]]$Sets
    )

    # verifying an active PAS connection
    Verify-PASConnection

	# multithreaded get on each set object
	$AllData = $Sets | ForEach-Object -Parallel {

		# aliasing and reasserting connection and script information
		$set = $_
		$PASConnection         = $using:PASConnection
		$PASSessionInformation = $using:PASSessionInformation

		# for each script in our PAS_PCMScriptBlocks
		foreach ($script in $using:PAS_PCMScriptBlocks)
		{
			# add it to this thread as a script, this makes all classes and functions available to this thread
			. $script.ScriptBlock
		}

		$obj = New-Object PSObject

		$obj | Add-Member -MemberType NoteProperty -Name SetName -Value $set.Name

		Try
		{
			# if the Set is not a Dynamic Set
			if ($set.SetType -ne "SqlDynamic")
			{
				# get the members of this set
				$set.GetMembers()
				$result = $true
			}
			else
			{
				$result = "Dynamic Set"
			}

			$obj | Add-Member -MemberType NoteProperty -Name Results -Value $result
		}
		Catch
		{
			# if an error occurred during the get, create a new PASException and return that with the relevant data
			$e = New-Object PASPCMException -ArgumentList ("Error during GetMembers() on PASSet object.")
			$e.AddExceptionData($_)
			$e.AddData("result",$result)
			$e.AddData("set",$set)
			$obj | Add-Member -MemberType NoteProperty -Name Results -Value $e
		}# Catch
		Finally
		{
			# nulling values to free memory
			$result = $null
			$set = $null
		}

		# return the returner object
		$obj
		
	} |# $Sets | ForEach-Object -Parallel {
	ForEach-Object -Begin { $i = 0 } -Process { 
			
		$Completed = $($i/($Sets | Measure-Object | Select-Object -ExpandProperty Count)*100)
		# incrementing result count
		$i++
		# update progress bar
		Write-Progress -Activity "Getting Set Members" -Status ("{0} out of {1} Complete" -f $i,$Sets.Count) -PercentComplete $Completed
		# returning the result
		$_
	}# | ForEach-Object -Begin { $i = 0 } -Process {

	# clean up some memory
	[System.GC]::GetTotalMemory($true) | Out-Null
	[System.GC]::Collect()

	return $AllData
}# function global:Get-PASSetMembers
#endregion
###########