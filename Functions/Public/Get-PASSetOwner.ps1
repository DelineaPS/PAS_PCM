###########
#region ### global:Get-PASSetOwner # Gets likely owner of a PASSet object.
###########
function global:Get-PASSetOwner
{
    <#
    .SYNOPSIS
    Gets likely owner of a PASSet object.

    .DESCRIPTION
	Gets the likely owner/creator of a PASSet object. Since there is no "Created By" or "Owned By" 
	property on a Set object in PAS, the best way to determine who created it is by looking for a 
	individual user that has non-inherited permissions and has every permission on the Set object.
	This is the tool's Best Guess estimate as to who created/owns the Set object.

	If an Owner Candidate is found, store the value in the PotentialOwner property.

    .PARAMETER Sets
	The PASSet objects to determine the owner. Will only accept PASSet type objects.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom class object that provides the set target 
	and the results of who possibly owns this Set.

    .EXAMPLE
    C:\PS> Get-PASSetOwner -Sets $PASSets
	For the provided PASSet objects, determine who possibly created/owns this PASSet. If an Owner 
	Candidate is found, store the value in the PotentialOwner property.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PAS Sets to determine the owner", ParameterSetName = "Set")]
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
			$result = $set.determineOwner()

			$obj | Add-Member -MemberType NoteProperty -Name Results -Value $result
		}
		Catch
		{
			# if an error occurred during the get, create a new PASException and return that with the relevant data
			$e = New-Object PASPCMException -ArgumentList ("Error during determineOwner() on PASSet object.")
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
		Write-Progress -Activity "Determining Owner" -Status ("{0} out of {1} Complete" -f $i,$Sets.Count) -PercentComplete $Completed
		# returning the result
		$_
	}# | ForEach-Object -Begin { $i = 0 } -Process {

	# clean up some memory
	[System.GC]::GetTotalMemory($true) | Out-Null
	[System.GC]::Collect()

	return $AllData
}# function global:Get-PASSetOwner
#endregion
###########