###########
#region ### global:Get-PASSystem # CMDLETDESCRIPTION : Gets Systems from the PAS tenant :
###########
function global:Get-PASSystem
{
    <#
    .SYNOPSIS
    Gets a System object from a connected PAS tenant.

    .DESCRIPTION
    Gets an System object from a connected PAS tenant. This returns a PASSystem class object containing properties about
    the System object. By default, Get-PASSystem without any parameters will get all System objects in the PAS. 
    In addition, the PASSystem class also contains methods to help interact with that System.

    The additional methods are the following:

    .getAccounts()
      - Gets the PASAccount objects that are associated with this System.

    .PARAMETER Name
    Gets systems by PAS name.

    .PARAMETER DNSName
    Gets systems by its DNSName or FQDN.

    .PARAMETER SessionType
    Gets systems by its Session Type, either Rdp or Ssh.

    .PARAMETER Type
    Gets systems by type, either Windows or Unix.

    .PARAMETER Uuid
    Gets systems by it's Uuid.

    .PARAMETER Limit
    Limits the number of potential System objects returned.
	
	.PARAMETER Skip
    Used with the -Limit parameter, skips the number of records before returning results.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a PASSystem class object.

    .EXAMPLE
    C:\PS> Get-PASSystem
    Gets all System objects from the tenant.

    .EXAMPLE
    C:\PS> Get-PASSystem -Limit 10
    Gets 10 System objects from the tenant.
	
	.EXAMPLE
    C:\PS> Get-PASSystem -Limit 10 -Skip 10
    Get the next 10 System objects in the tenant, skipping the first 10.

    .EXAMPLE
    C:\PS> Get-PASSystem -Type Windows
    Get all Windows Systems in the tenant.

    .EXAMPLE
    C:\PS> Get-PASSystem -SessionType Ssh 
    Gets all systems with a Session Type of Ssh.

    .EXAMPLE
    C:\PS> Get-PASSystem -DNSName "LINUXSERVER01.DOMAIN.COM"
    Get all System objects with an FQDN of LINUXSERVER01.DOMAIN.COM.

    .EXAMPLE
    C:\PS> Get-PASSystem -Uuid "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    Get the System object with the specified UUID.

    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $false, HelpMessage = "The name of the System to search.", ParameterSetName = "Search")]
        [System.String]$Name,

        [Parameter(Mandatory = $false, HelpMessage = "The FQDN of the System to search.", ParameterSetName = "Search")]
        [System.String]$DNSName,

        [Parameter(Mandatory = $false, HelpMessage = "The Session Type of the System to search.", ParameterSetName = "Search")]
        [ValidateSet("Rdp","Ssh")]
        [System.String]$SessionType,

        [Parameter(Mandatory = $false, HelpMessage = "The Type of System to search.", ParameterSetName = "Search")]
        [ValidateSet("Windows","Unix")]
        [System.String]$Type,

        [Parameter(Mandatory = $false, HelpMessage = "The Uuid of the System to search.",ParameterSetName = "Uuid")]
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
    $query = "Select * FROM Server"

    # arraylist for extra options
    $extras = New-Object System.Collections.ArrayList

    # if the All set was not used
    if ($PSCmdlet.ParameterSetName -ne "All")
    {
        # appending the WHERE 
        $query += " WHERE "

        # setting up the extra conditionals
        if ($PSBoundParameters.ContainsKey("Name"))        { $extras.Add(("Name = '{0}'" -f $Name)) | Out-Null }
        if ($PSBoundParameters.ContainsKey("DNSName"))     { $extras.Add(("FQDN = '{0}'" -f $DNSName))   | Out-Null }
        if ($PSBoundParameters.ContainsKey("SessionType")) { $extras.Add(("SessionType = '{0}'" -f $SessionType)) | Out-Null}
        if ($PSBoundParameters.ContainsKey("Type"))        { $extras.Add(("ComputerClass = '{0}'" -f $Type)) | Out-Null}
		if ($PSBoundParameters.ContainsKey("Uuid"))        { $extras.Add("ID IN ({0})" -f (($Uuid -replace '^(.*)$',"'`$1'") -join ",")) | Out-Null }
 
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


			$system = $null

			$obj = New-Object PSObject

			Try
			{
				# create a new PAS Account object
				$system = New-Object PASSystem -ArgumentList ($query)
				# add it to our temporary returner object
				$obj | Add-Member -MemberType NoteProperty -Name Systems -Value $system
			}
			Catch
			{
				# if an error occurred during New-Object, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New PASSystem object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$e.AddData("system",$system)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch
			Finally
			{
				# nulling values to free memory
				$system = $null
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
			Write-Progress -Activity "Getting Systems" -Status ("{0} out of {1} Complete" -f $i,$basesqlquery.Count) -PercentComplete $Completed -CurrentOperation ("Current: [{0}]" -f $_.Name)
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

	return $AllData.Systems
}# function global:Get-PASSystem
#endregion
###########