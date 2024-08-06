###########
#region ### global:Get-PASAccount # Gets a PAS Account object
###########
function global:Get-PASAccount
{
    <#
    .SYNOPSIS
    Gets an Account object from a connected PAS tenant.

    .DESCRIPTION
    Gets an Account object from a connected PAS tenant. This returns a PASAccount class object containing properties about
    the Account object. By default, Get-PASAccount without any parameters will get all Account objects in the PAS. 
    In addition, the PASAccount class also contains methods to help interact with that Account.

    The additional methods are the following:

    .CheckInPassword()
      - Checks in a password that has been checked out by the CheckOutPassword() method.
    
    .CheckOutPassword()
      - Checks out the password to this Account.
    
    .ManageAccount()
      - Sets this Account to be managed by the PAS.

    .UnmanageAccount()
      - Sets this Account to be un-managed by the PAS.

    .UpdatePassword([System.String]$newpassword)
      - Updates the password to this Account.
    
    .VerifyPassword()
      - Verifies if this password on this Account is correct.
    
    If this function gets all Accounts from the PAS Tenant, then everything will also be saved into the global
    $PASAccountBank variable. This makes it easier to reference these objects without having to make additional 
    API calls.

    .PARAMETER Type
    Gets only Accounts of this type. Currently only "Local","Domain","Database", or "Cloud" is supported.

    .PARAMETER SourceName
    Gets only Accounts with the name of the Parent object that hosts this account. For local accounts, this would
    be the hostname of the system the account exists on. For domain accounts, this is the name of the domain.

    .PARAMETER UserName
    Gets only Accounts with this as the username.

    .PARAMETER Uuid
    Gets only Accounts with this UUID.

    .PARAMETER Limit
    Limits the number of potential Account objects returned.
	
	.PARAMETER Skip
    Used with the -Limit parameter, skips the number of records before returning results.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a PASAccount class object.

    .EXAMPLE
    C:\PS> Get-PASAccount
    Gets all Account objects from the Delinea PAS.

    .EXAMPLE
    C:\PS> Get-PASAccount -Limit 10
    Gets 10 Account objects from the Delinea PAS.
	
	.EXAMPLE
    C:\PS> Get-PASAccount -Limit 10 -Skip 10
    Get the next 10 account objects in the tenant, skipping the first 10.

    .EXAMPLE
    C:\PS> Get-PASAccount -Type Domain
    Get all domain-based Accounts.

    .EXAMPLE
    C:\PS> Get-PASAccount -Username "root"
    Gets all Account objects with the username, "root".

    .EXAMPLE
    C:\PS> Get-PASAccount -SourceName "LINUXSERVER01.DOMAIN.COM"
    Get all Account objects who's source (parent) object is LINUXSERVER01.DOMAIN.COM.

	.EXAMPLE
	C:\PS> Get-PASAccount -SourceName "LINUXSERVER01.DOMAIN.COM" -Username "root"
    Get the root account objects who's source (parent) object is LINUXSERVER01.DOMAIN.COM.

    .EXAMPLE
    C:\PS> Get-PASAccount -Uuid "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    Get an Account object with the specified UUID.

    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $false, HelpMessage = "The type of Account to search.", ParameterSetName = "Search")]
        [ValidateSet("Local","Domain","Database","Cloud")]
        [System.String]$Type,

        [Parameter(Mandatory = $false, HelpMessage = "The name of the Source of the Account to search.", ParameterSetName = "Search")]
        [System.String]$SourceName,

        [Parameter(Mandatory = $false, HelpMessage = "The name of the Account to search.", ParameterSetName = "Search")]
        [System.String]$UserName,

        [Parameter(Mandatory = $false, HelpMessage = "The Uuid of the Account to search.",ParameterSetName = "Uuid")]
        [System.String[]]$Uuid,

        [Parameter(Mandatory = $false, HelpMessage = "A limit on number of objects to query.", ParameterSetName = "All")]
		[Parameter(Mandatory = $false, HelpMessage = "A limit on number of objects to query.", ParameterSetName = "Search")]
        [System.Int32]$Limit,

		[Parameter(Mandatory = $false, HelpMessage = "Skip these number of records first, used with Limit.", ParameterSetName = "All")]
		[Parameter(Mandatory = $false, HelpMessage = "Skip these number of records first, used with Limit.", ParameterSetName = "Search")]
        [System.Int32]$Skip
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # setting the base query
    $query = "Select * FROM VaultAccount"

    # arraylist for extra options
    $extras = New-Object System.Collections.ArrayList

    # if the All set was not used
    if ($PSCmdlet.ParameterSetName -ne "All")
    {
        # appending the WHERE 
        $query += " WHERE "

        # setting up the extra conditionals
        if ($PSBoundParameters.ContainsKey("Type"))
        {
            Switch ($Type)
            {
                "Cloud"    { $extras.Add("CloudProviderID IS NOT NULL") | Out-Null ; break }
                "Domain"   { $extras.Add("DomainID IS NOT NULL") | Out-Null ; break }
                "Database" { $extras.Add("DatabaseID IS NOT NULL") | Out-Null ; break }
                "Local"    { $extras.Add("Host IS NOT NULL") | Out-Null ; break }
            }
        }# if ($PSBoundParameters.ContainsKey("Type"))
        
        if ($PSBoundParameters.ContainsKey("SourceName")) { $extras.Add(("Name = '{0}'" -f $SourceName)) | Out-Null }
        if ($PSBoundParameters.ContainsKey("UserName"))   { $extras.Add(("User = '{0}'" -f $UserName))   | Out-Null }
		if ($PSBoundParameters.ContainsKey("Uuid")) { $extras.Add("ID IN ({0})" -f (($Uuid -replace '^(.*)$',"'`$1'") -join ",")) | Out-Null }

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

			# minor placeholder to hold account type in case of all call
			[System.String]$accounttype = $null

			if ($query.CloudProviderID -ne $null) { $accounttype = "Cloud"    }
			if ($query.DomainID -ne $null)        { $accounttype = "Domain"   }
			if ($query.DatabaseID -ne $null)      { $accounttype = "Database" }
			if ($query.Host -ne $null)            { $accounttype = "Local"    }

			$account = $null

			$obj = New-Object PSObject

			Try
			{
				# create a new PAS Account object
				$account = New-Object PASAccount -ArgumentList ($query, $accounttype)
				# add it to our temporary returner object
				$obj | Add-Member -MemberType NoteProperty -Name Accounts -Value $account
			}
			Catch
			{
				# if an error occurred during New-Object, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New PASAccount object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$e.AddData("accounttype",$accounttype)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch
			Finally
			{
				# nulling values to free memory
				$account = $null
				$accounttype = $null
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
			Write-Progress -Activity "Getting Accounts" -Status ("{0} out of {1} Complete" -f $i,$basesqlquery.Count) -PercentComplete $Completed -CurrentOperation ("Current: [{0}]" -f $_.SSName)
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

	return $AllData.Accounts
}# function global:Get-PASAccount
#endregion
###########