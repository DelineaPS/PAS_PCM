###########
#region ### global:Review-PASSetPermissions # Reviews the permissions for PASSet objects
###########
function global:Review-PASSetPermissions
{
    <#
    .SYNOPSIS
    Reviews the Permissions model for PASSet objects.

    .DESCRIPTION
	This cmdlet produces the output of Review Permissions method on PASSet objects. These 
	reviewed permissions will be added to the .ReviewedPermissions property.

    .PARAMETER Sets
	The PASSet objects to review permissions. Will only accept PASSet type objects.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom class object that provides the set target 
	and the results of the review Permissions output.

    .EXAMPLE
    C:\PS> Review-PASSetPermissions -Sets $PASSets
	For the provided PASSet objects, reviews the permissions of the set and provide it
	as part of the returned output.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PAS Sets to get recent activity", ParameterSetName = "Set")]
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
			$result = $set.getSetActivity()

			$obj | Add-Member -MemberType NoteProperty -Name Results -Value $true
		}
		Catch
		{
			# if an error occurred during the get, create a new PASException and return that with the relevant data
			$e = New-Object PASPCMException -ArgumentList ("Error during getSetActivity() on PASSet object.")
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
		Write-Progress -Activity "Getting Set Activity" -Status ("{0} out of {1} Complete" -f $i,$Sets.Count) -PercentComplete $Completed
		# returning the result
		$_
	}# | ForEach-Object -Begin { $i = 0 } -Process {

	# clean up some memory
	[System.GC]::GetTotalMemory($true) | Out-Null
	[System.GC]::Collect()

	return $AllData
}# function global:Review-PASSetPermissions
#endregion
###########