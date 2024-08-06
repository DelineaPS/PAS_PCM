###########
#region ### global:Get-PASSecret # Gets a PASSecret object from the tenant
###########
function global:Get-PASSecret
{
    <#
    .SYNOPSIS
    Gets a Secret object from the Delinea PAS.

    .DESCRIPTION
    Gets a Secret object from the Delinea PAS. This returns a PASSecret class object containing properties about
    the Secret object, and methods to potentially retreive the Secret contents as well. By default, Get-PASSecret without
    any parameters will get all Secret objects in the PAS. 
    
    The additional methods are the following:

    .RetrieveSecret()
      - For Text Secrets, this will retreive the contents of the Text Secret and store it in the SecretText property.
      - For File Secrets, this will prepare the File Download URL to be used with the .ExportSecret() method.

    .ExportSecret()
      - For Text Secrets, this will export the contents of the SecretText property as a text file into the ParentPath directory.
      - For File Secrets, this will download the file from the PAS into the ParentPath directory.

    If the directory or file does not exist during ExportSecret(), the directory and file will be created. If the file
    already exists, then the file will be renamed and appended with a random 8 character string to avoid file name conflicts.
    
    If this function gets all Secrets from the PAS Tenant, then everything will also be saved into the global
    $PASSecretBank variable. This makes it easier to reference these objects without having to make additional 
    API calls.

    .PARAMETER Name
    Get a PAS Secret by it's Secret Name.

    .PARAMETER Uuid
    Get a PAS Secret by it's UUID.

    .PARAMETER Type
    Get a PAS Secret by it's Type, either File or Text.

    .PARAMETER Limit
    Limits the number of potential Secret objects returned.

	.PARAMETER Skip
    Used with the -Limit parameter, skips the number of records before returning results.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a PASSecret class object.

    .EXAMPLE
    C:\PS> Get-PASSecret
    Gets all Secret objects from the Delinea PAS.

    .EXAMPLE
    C:\PS> Get-PASSecret -Limit 10
    Gets 10 Secret objects from the Delinea PAS.

	.EXAMPLE
    C:\PS> Get-PASSecret -Limit 10 -Skip 10
    Get the next 10 Secret objects in the tenant, skipping the first 10.

    .EXAMPLE
    C:\PS> Get-PASSecret -Name "License Keys"
    Gets all Secret objects with the Secret Name "License Keys".

    .EXAMPLE
    C:\PS> Get-PASSecret -Type File
    Gets all File Secret objects.

    .EXAMPLE
    C:\PS> Get-PASSecret -Uuid "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    Get a Secret object with the specified UUID.

    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The name of the secret to search.",ParameterSetName = "Name")]
        [System.String]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "The Uuid of the secret to search.",ParameterSetName = "Uuid")]
        [System.String]$Uuid,

        [Parameter(Mandatory = $true, HelpMessage = "The type of the secret to search.",ParameterSetName = "Type")]
        [ValidateSet("Text","File")]
        [System.String]$Type,

        [Parameter(Mandatory = $false, HelpMessage = "Limits the number of results.")]
        [System.Int32]$Limit,

		[Parameter(Mandatory = $false, HelpMessage = "Skip these number of records first, used with Limit.")]
        [System.Int32]$Skip
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # base query
    $query = "SELECT * FROM DataVault"

    # if the All set was not used
    if ($PSCmdlet.ParameterSetName -ne "All")
    {
        # arraylist for extra options
        $extras = New-Object System.Collections.ArrayList

        # appending the WHERE 
        $query += " WHERE "

        # setting up the extra conditionals
        if ($PSBoundParameters.ContainsKey("Name")) { $extras.Add(("SecretName = '{0}'" -f $Name)) | Out-Null }
        if ($PSBoundParameters.ContainsKey("Uuid")) { $extras.Add(("ID = '{0}'"         -f $Uuid)) | Out-Null }
        if ($PSBoundParameters.ContainsKey("Type")) { $extras.ADD(("Type = '{0}'"       -f $Type)) | Out-Null }

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

    # make the query
    $basesqlquery = Query-RedRock -SqlQuery $query

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

			Try
			{
				# create a new PASSecret object
				$secret = New-Object PASSecret -ArgumentList ($query)

				# add it to our temporary returner object
				$obj | Add-Member -MemberType NoteProperty -Name Secrets -Value $secret
			}
			Catch
			{
				# if an error occurred during New-Object, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New PASSecret object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$e.AddData("secret ",$secret)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
			}# Catch
			Finally
			{
				# nulling values to free memory
				$secret = $null
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
			Write-Progress -Activity "Getting Secrets" -Status ("{0} out of {1} Complete" -f $i,$basesqlquery.Count) -PercentComplete $Completed -CurrentOperation ("Current: [{0}]" -f $_.SSName)
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

	return $AllData.Secrets
}# function global:Get-PASSecret
#endregion
###########