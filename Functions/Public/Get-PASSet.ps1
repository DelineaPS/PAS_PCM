###########
#region ### global:Get-PASSet # CMDLETDESCRIPTION : Gets Sets from the PAS tenant :
###########
function global:Get-PASSet
{
    <#
    .SYNOPSIS
    Gets a Set object from a connected PAS tenant.

    .DESCRIPTION
    Gets an Set object from a connected PAS tenant. This returns a PASSet class object containing properties about
    the Set object. By default, Get-PASSet without any parameters will get all Set objects in the PAS. 
    In addition, the PASSet class also contains methods to help interact with that Set.

    The additional methods are the following:

    .getPASObjects()
	Returns the members of this Set as the relevant PASObjects. For example, PASAccount objects
	for an Account Set.

    .PARAMETER Type
    Gets only Sets of this type. Currently only "System","Database","Account", or "Secret" is supported.

    .PARAMETER Name
    Gets only Sets with this name.

    .PARAMETER Uuid
    Gets only Sets with this UUID.

    .PARAMETER Limit
    Limits the number of potential Set objects returned.

	.PARAMETER Skip
	Used with the -Limit parameter, skips the number of records before returning results.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a PASSet class object.

    .EXAMPLE
    C:\PS> Get-PASSet
    Gets all Set objects from the Delinea PAS.

    .EXAMPLE
    C:\PS> Get-PASSet -Limit 10
    Gets 10 Set objects from the Delinea PAS.

	.EXAMPLE
	C:\PS> Get-PASSecret -Limit 10 -Skip 10
	Get the next 10 Set objects in the tenant, skipping the first 10.

    .EXAMPLE
    C:\PS> Get-PASSet -Type Account
    Get all Account Sets.

    .EXAMPLE
    C:\PS> Get-PASSet -Name "Security Team Accounts"
    Gets the Set with the name "Security Team Accounts".

    .EXAMPLE
    C:\PS> Get-PASSet -Uuid "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    Get an Set object with the specified UUID.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The type of Set to search.", ParameterSetName = "Type")]
        [ValidateSet("System","Database","Account","Secret")]
        [System.String]$Type,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the Set to search.", ParameterSetName = "Name")]
        [Parameter(Mandatory = $false, HelpMessage = "The name of the Set to search.", ParameterSetName = "Type")]
        [System.String]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "The Uuid of the Set to search.",ParameterSetName = "Uuid")]
        [Parameter(Mandatory = $false, HelpMessage = "The name of the Set to search.", ParameterSetName = "Type")]
        [System.String]$Uuid,

        [Parameter(Mandatory = $false, HelpMessage = "Limits the number of results.")]
        [System.Int32]$Limit,

		[Parameter(Mandatory = $false, HelpMessage = "Skip these number of records first, used with Limit.")]
		[System.Int32]$Skip
    )

	# verifying an active PAS connection
    Verify-PASConnection

    # setting the base query
    $query = "Select * FROM Sets"

    # arraylist for extra options
    $extras = New-Object System.Collections.ArrayList

    # if the All set was not used
    if ($PSCmdlet.ParameterSetName -ne "All")
    {
        # placeholder to translate type names
        [System.String] $newtype = $null

        # switch to translate backend naming convention
        Switch ($Type)
        {
            "System"   { $newtype = "Server" ; break }
            "Database" { $newtype = "VaultDatabase" ; break }
            "Account"  { $newtype = "VaultAccount" ; break }
            "Secret"   { $newtype = "DataVault" ; break }
            default    { }
        }# Switch ($Type)

        # appending the WHERE 
        $query += " WHERE "

        # setting up the extra conditionals
        if ($PSBoundParameters.ContainsKey("Type")) { $extras.Add(("ObjectType = '{0}'" -f $newtype)) | Out-Null }
        if ($PSBoundParameters.ContainsKey("Name")) { $extras.Add(("Name = '{0}'"       -f $Name))    | Out-Null }
        if ($PSBoundParameters.ContainsKey("Uuid")) { $extras.Add(("ID = '{0}'"         -f $Uuid))    | Out-Null }

        # join them together with " AND " and append it to the query
        $query += ($extras -join " AND ")
    }# if ($PSCmdlet.ParameterSetName -ne "All")

	# if Limit was used, append it to the query
	if ($PSBoundParameters.ContainsKey("Limit")) 
	{ 
		$query += (" LIMIT {0}" -f $Limit) 

		# if Offset was used, append it to the query
		if ($PSBoundParameters.ContainsKey("Skip"))
		{
			$query += (" OFFSET {0}" -f $Skip) 
		}
	}# if ($PSBoundParameters.ContainsKey("Limit")) 

    Write-Verbose ("SQLQuery: [{0}]" -f $query)

    # making the query
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

			$set = $null

			$obj = New-Object PSObject

			Try
			{
				# create a new PAS Account object
				$set = New-Object PASSet -ArgumentList ($query)

				# if the Set is not a Dynamic Set
				if ($set.SetType -ne "SqlDynamic")
				{
					# get the members of this set
					$set.GetMembers()
				}
	
				# determin the potential owner of the Set
				$set.determineOwner() | Out-Null
				
				# add it to our temporary returner object
				$obj | Add-Member -MemberType NoteProperty -Name Sets -Value $set
			}
			Catch
			{
				# if an error occurred during New-Object, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New PASSet object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch
			Finally
			{
				# nulling values to free memory
				$set = $null
				$query = $null
			}

			# return the returner object
			$obj
		} | # $AllData = $basesqlquery | Foreach-Object -Parallel {
		ForEach-Object -Begin { $i = 0 } -Process { 
			
			$Completed = $($i/($basesqlquery | Measure-Object | Select-Object -ExpandProperty Count)*100)
			# incrementing result count
			$i++
			# update progress bar
			Write-Progress -Activity "Getting Sets" -Status ("{0} out of {1} Complete" -f $i,$basesqlquery.Count) -PercentComplete $Completed
			# returning the result
			$_
		} #>
	}# if ($basesqlquery -ne $null)
	else
	{
		return $false
	}

	
	if ($AllData.Exceptions.Count -gt 0)
	{
		$global:PASErrorStack = $AllData.Exceptions
	}#>

	# clean up some memory
	[System.GC]::GetTotalMemory($true) | Out-Null
	[System.GC]::Collect()

	return $AllData.Sets
}# function global:Get-PASSet
#endregion
###########