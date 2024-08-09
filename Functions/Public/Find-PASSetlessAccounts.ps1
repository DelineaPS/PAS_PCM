###########
#region ### global:Find-PASSetlessAccounts # Finds all VaultAccount objects in PAS that do not belong to any Set.
###########
function global:Find-PASSetlessAccounts
{
    <#
    .SYNOPSIS
    Finds all VaultAccount objects in a PAS tenant that do not belong to any Set.

    .DESCRIPTION
    This cmdlet will parse all VaultAccount Sets and their members to find any VaultAccounts that do not belong to any VaultAccount Set.

	The returned results are a custom PSObject that has two properties:

	- Name - A string, containing the parent name of the object and the name of the user account.
	- ID - A string, containing UUID of the VaultAccount object.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom class object with only 2 properties; Name, ID.

    .EXAMPLE
    C:\PS> Find-PASSetlessAccounts
	Finds all VaultAccount objects in a PAS tenant that do not belong to any Set.

    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		# no parameters defined
    )

    # verifying an active CloudSuite connection
    Verify-PASConnection

    # setting the base query
    $query = "Select ID,Name,ObjectType FROM Sets WHERE ObjectType = 'VaultAccount' AND CollectionType = 'ManualBucket'"

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

			$collection = $null
				
			Try # to create a new SetCollections object
			{
				$collection = New-Object SetCollection -ArgumentList ($query.Name, $query.ID, $query.ObjectType)
			}
			Catch
			{
				# if an error occurred during New-Object, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New SetCollection object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$e.AddData("collection",$collection)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch

			Try # to get the members of this collection, and add it to the object
			{
				$setmemberuuids = Invoke-PASAPI -APICall Collection/GetMembers -Body (@{ID=$collection.ID}|ConvertTo-Json) | Select-Object -ExpandProperty Key

				$collection.AddMembers($setmemberuuids)
			}
			Catch
			{
				# if an error occurred during the Collection/GetMembers, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New API call Collection/GetMembers object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$e.AddData("collection",$collection)
				$e.AddData("setmemberuuids",$setmemberuuids)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch
			Finally
			{
				# nulling values to free memory
				$setmemberuuids = $null
				$query = $null
			}

			$collection
		} | # $AllData = $basesqlquery | Foreach-Object -Parallel {
		ForEach-Object -Begin { $i = 0 } -Process { 
			
			$Completed = $($i/($basesqlquery | Measure-Object | Select-Object -ExpandProperty Count)*100)
			# incrementing result count
			$i++
			# update progress bar
			Write-Progress -Activity "Getting Sets and Set Members" -Status ("{0} out of {1} Complete" -f $i,$basesqlquery.Count) -PercentComplete $Completed
			# returning the result
			$_
		}# ForEach-Object -Begin { $i = 0 } -Process { 
	}# if ($basesqlquery -ne $null)
    else
    {
        return $false
    }

	# get all VaultAccount ids
	$vaultaccountids = Query-RedRock -SQLQuery "Select ID FROM VaultAccount" | Select-Object -ExpandProperty ID

	# now find those that are not in the objectstack memberuuids
	$setlessvaultaccountids = $vaultaccountids | Where-Object {-Not ($AllData.MemberUuids.Contains($_))}

	# now get the SSNames of those accounts
	if (($setlessvaultaccountids | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
	{
		$SetlessAccounts = $setlessvaultaccountids | Foreach-Object -Parallel {

			$setlessvaultaccountid = $_
			$PASConnection         = $using:PASConnection
            $PASSessionInformation = $using:PASSessionInformation

			# for each script in our PAS_PCMScriptBlocks
            foreach ($script in $using:PAS_PCMScriptBlocks)
            {
                # add it to this thread as a script, this makes all classes and functions available to this thread
                . $script.ScriptBlock
            }

			Try # to create a new SetCollections object
			{
				$namequery = Query-RedRock -SQLQuery ("SELECT (Name || '\' || User) AS Name,ID FROM VaultAccount WHERE ID = '{0}'" -f $setlessvaultaccountid) | Select-Object Name,ID
			}
			Catch
			{
				# if an error occurred during New-Object, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New PASAccount object.")
				$e.AddExceptionData($_)
				$e.AddData("setlessvaultaccountid",$setlessvaultaccountid)
				$e.AddData("namequery",$namequery)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch
			Finally
			{
				# nulling values to free memory
				$setlessvaultaccountid = $null
			}

			$namequery
		}| # $AllData = $basesqlquery | Foreach-Object -Parallel {
		ForEach-Object -Begin { $i = 0 } -Process { 
			
			$Completed = $($i/($setlessvaultaccountids | Measure-Object | Select-Object -ExpandProperty Count)*100)
			# incrementing result count
			$i++
			# update progress bar
			Write-Progress -Activity "Getting Sets and Set Members" -Status ("{0} out of {1} Complete" -f $i,$setlessvaultaccountids.Count) -PercentComplete $Completed
			# returning the result
			$_
		}# ForEach-Object -Begin { $i = 0 } -Process { 
	}# if (($setlessvaultaccountids | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
	else # otherwise
	{
		# return false
		return $false
	}

	return $SetlessAccounts
}# function global:Find-PASSetlessAccounts
#endregion
###########
#>