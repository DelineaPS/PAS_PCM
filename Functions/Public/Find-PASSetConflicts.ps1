###########
#region ### global:Find-PASSetConflicts # Finds all Set conflicts in the PAS tenant
###########
function global:Find-PASSetConflicts
{
    <#
    .SYNOPSIS
    Finds all Set conflicts in the PAS tenant.

    .DESCRIPTION
    This cmdlet will find all objects in the PAS tenant that exist in 2 or more Sets. A Set is a collection of objects 
	in the PAS, however an object (such as an account or Text Secret) can be a member of multiple Sets. This cmdlet will
	find all Sets where an object exists in two or more Set Collections.

	The returned results are a custom PSObject that has three properties:

	- Name - A string, contains the name of the object.
	- Type - A string, the type of Set where this object is a member.
	- InSets - A string, a comma separated list of all Sets (by name) where this object is a member.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom class object with only 3 properties; Name, SetType, and inSets.

    .EXAMPLE
    C:\PS> Find-SetConflicts
	Finds all objects that exist in multiple sets in the PAS tenant.

    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		# no parameters defined
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # setting the base query
    $query = "Select ID,Name,ObjectType FROM Sets"

    Write-Verbose ("SQLQuery: [{0}]" -f $query)

    # making the query for the IDs
    $basesqlquery = Query-RedRock -SQLQuery $query

	Write-Verbose ("basesqlquery objects [{0}]" -f $basesqlquery.Count)

	# if the base sqlquery isn't null
	if ($basesqlquery -ne $null)
	{
		$AllData = $basesqlquery | Foreach-Object -Parallel {

			$query = $_
			$PASConnection         = $using:PASConnection
            $PASSessionInformation = $using:PASSessionInformation

			# for each script in our PAS_PCMScriptBlocks
            foreach ($script in $using:PAS_PCMScriptBlocks)
            {
                # add it to this thread as a script, this makes all classes and functions available to this thread
                . $script.ScriptBlock
            }

			$obj = New-Object PSObject
				
			Try # to create a new SetCollections object
			{
				$collection = New-Object SetCollection -ArgumentList ($query.Name, $query.ID, $query.ObjectType)
				$obj | Add-Member -MemberType NoteProperty -Name Collections -Value $collection
			}
			Catch
			{
				# if an error occurred during New-Object, create a new PASPCMException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New SetCollection object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$e.AddData("collection",$collection)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch

			Try # to get the members of this collection, and add it to the object
			{
				$setmemberuuids = Invoke-PASAPI -APICall Collection/GetMembers -Body (@{ID=$obj.Collections.ID}|ConvertTo-Json) | Select-Object -ExpandProperty Key

				$obj.Collections.AddMembers($setmemberuuids)
			}
			Catch
			{
				# if an error occurred during New-Object, create a new PASPCMException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during Get Collection Members object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$e.AddData("setmemberuuids",$setmemberuuids)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch

			$obj
		}| # $AllData = $basesqlquery | Foreach-Object -Parallel {
		ForEach-Object -Begin { $i = 0 } -Process { 
			
			$Completed = $($i/($basesqlquery | Measure-Object | Select-Object -ExpandProperty Count)*100)
			# incrementing result count
			$i++
			# update progress bar
			Write-Progress -Activity "Getting Set Conflicts" -Status ("{0} out of {1} Complete" -f $i,$basesqlquery.Count) -PercentComplete $Completed -CurrentOperation ("Current: [{0}]" -f $_.SSName)
			# returning the result
			$_
		}# ForEach-Object -Begin { $i = 0 } -Process { 
		# find those uuids that appear in 2 or more sets' memberuuids
		$conflictinguuids = $AllData.Collections.MemberUuids | Group-Object | Where-Object {$_.Count -gt 1} | Select-Object -ExpandProperty Name

		$Conflicts = $conflictinguuids | Foreach-Object -Parallel {

			$conflictinguuid = $_
			$PASConnection         = $using:PASConnection
            $PASSessionInformation = $using:PASSessionInformation

			# for each script in our PAS_PCMScriptBlocks
            foreach ($script in $using:PAS_PCMScriptBlocks)
            {
                # add it to this thread as a script, this makes all classes and functions available to this thread
                . $script.ScriptBlock
            }

			$inSets = $($using:AllData).Collections | Where-Object -Property MemberUuids -contains $conflictinguuid

			# narrow down to the set type
			$settype = $inSets | Select-Object -ExpandProperty ObjectType -Unique -First 1

			# placeholder for the name
			$namequery = $null

			# base on which set type it is, get the name of the object using its uuid
			Switch ($settype)
			{
				"VaultAccount" { $namequery = Query-RedRock -SQLQuery ("SELECT (Name || '\' || User) AS Name FROM VaultAccount WHERE ID = '{0}'" -f $conflictinguuid) | Select-Object -ExpandProperty Name; break }
				"Server"       { $namequery = Query-RedRock -SQLQuery ("SELECT Name FROM Server WHERE ID = '{0}'" -f $conflictinguuid) | Select-Object -ExpandProperty Name; break }
				"DataVault"    { $namequery = Query-RedRock -SQLQuery ("SELECT SecretName FROM DataVault WHERE ID = '{0}'" -f $conflictinguuid) | Select-Object -ExpandProperty Name; break }
				default        { $namequery = "UNKNOWNTYPE"; break }
			}# Switch ($settype)

			# custom object to hold the new information
			$obj = New-Object PSObject

			# setting up the information
			$obj | Add-Member -MemberType NoteProperty -Name Name -Value $namequery
			$obj | Add-Member -MemberType NoteProperty -Name Type -Value $settype
			$obj | Add-Member -MemberType NoteProperty -Name InSets -Value ($inSets.Name -join ",")

			$obj
		} | # $Conflicts = $conflictinguuids | Foreach-Object -Parallel {
		ForEach-Object -Begin { $i = 0 } -Process { 
			
			$Completed = $($i/($basesqlquery | Measure-Object | Select-Object -ExpandProperty Count)*100)
			# incrementing result count
			$i++
			# update progress bar
			Write-Progress -Activity "Determining Set Conflicts" -Status ("{0} out of {1} Complete" -f $i,$basesqlquery.Count) -PercentComplete $Completed -CurrentOperation ("Current: [{0}]" -f $_.SSName)
			# returning the result
			$_
		}# ForEach-Object -Begin { $i = 0 } -Process { 
	}# if ($basesqlquery -ne $null)

	if ($AllData.Exceptions.Count -gt 0)
	{
		$global:PASErrorStack = $AllData.Exceptions
	}#>

	$global:PASSetConflicts = $Conflicts

	return $Conflicts
}# function global:Find-SetConflicts
#endregion
###########