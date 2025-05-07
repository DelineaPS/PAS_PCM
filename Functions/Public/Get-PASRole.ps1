###########
#region ### global:Get-PASRole # CMDLETDESCRIPTION : Gets Roles from the PAS tenant :
###########
function global:Get-PASRole
{
    <#
    .SYNOPSIS
    Gets a Role object from a connected PAS tenant.

    .DESCRIPTION
    Gets an Role object from a connected PAS tenant. This returns a PASRole class object containing properties about
    the Role object. By default, Get-PASRole without any parameters will get all Roles in the PAS tenant. 
    In addition, this cmdlet will get members of those roles.

    .PARAMETER Name
    Gets Roles by name. This is case sensitive. Multiple names can be specified by comma separation.

    .PARAMETER ID
    Gets Roles by ID. Multiple ID can be specified by comma separation.

    .PARAMETER DirectoryServiceUuid
    Gets Roles by Directory Service Uuid. Multiple Uuids can be specified by comma separation.

    .PARAMETER Limit
    Limits the number of potential PASRole objects returned.
	
	.PARAMETER Skip
    Used with the -Limit parameter, skips the number of records before returning results.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a PASRole class object.

    .EXAMPLE
    C:\PS> Get-PASRole
    Gets all Roles from the Delinea PAS tenant.

    .EXAMPLE
    C:\PS> Get-PASRole -Name "Blue Crab Admins"
    Gets the Role named "Blue Crab Admins" from the Delinea PAS tenant. This name search is case sensitive.

    .EXAMPLE
    C:\PS> Get-PASRole -Name "Blue Crab Admins","Blue Crab Users"
    Gets the Roles named "Blue Crab Admins" and "Blue Crab Users" from the Delinea PAS tenant. This name search is case sensitive.

    .EXAMPLE
    C:\PS> Get-PASRole -Limit 10
    Gets the first 10 Roles from the Delinea PAS tenant.
	
	.EXAMPLE
    C:\PS> Get-PASRole -Limit 10 -Skip 10
    Get the next 10 Roles in the tenant, skipping the first 10.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, HelpMessage = "The names of the Roles to search.", ParameterSetName = "Search")]
        [System.String[]]$Name,

        [Parameter(Mandatory = $false, HelpMessage = "The IDs of the Roles to search.",ParameterSetName = "Id")]
        [System.String[]]$ID,

        [Parameter(Mandatory = $false, HelpMessage = "The Directory Service Uuids of the Roles to search.",ParameterSetName = "Uuid")]
        [System.String[]]$DirectoryServiceUuid,
        
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
    $query = "Select * FROM Roles"

    # arraylist for extra options
    $extras = New-Object System.Collections.ArrayList

    # if the All set was not used
    if ($PSCmdlet.ParameterSetName -ne "All")
    {
        # appending the WHERE 
        $query += " WHERE "
        
        # if any of the other parameters were used, account for them
        if ($PSBoundParameters.ContainsKey("Name"))                 { $extras.Add("Name IN ({0})" -f (($Name -replace '^(.*)$',"'`$1'") -join ",")) | Out-Null }
        if ($PSBoundParameters.ContainsKey("Id"))                   { $extras.Add("ID IN ({0})" -f (($ID -replace '^(.*)$',"'`$1'") -join ",")) | Out-Null }
        if ($PSBoundParameters.ContainsKey("DirectoryServiceUuid")) { $extras.Add("DirectoryServiceUuid IN ({0})" -f (($DirectoryServiceUuid -replace '^(.*)$',"'`$1'") -join ",")) | Out-Null }

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

            # base returner object
            $obj = New-Object PSObject

            Try # to create a new PASRole object
            {   
                $role = New-Object PASRole -ArgumentList ($query.Name, $query.ID, $query.Description, $query.DirectoryServiceUuid)
            }
            Catch
            {
                # if an error occurred during New-Object, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New PASAccount object.")
				$e.AddExceptionData($_)
				$e.AddData("query",$query)
				$e.AddData("role",$role)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
            }# Catch

            Try # to get the members of this role
            {
                $members = Invoke-PASAPI -APICall SaasManage/GetRoleMembers -Body (@{name=$role.ID} | ConvertTo-Json)

                foreach ($member in $members.Results.Row)
                {
                    $mem = New-Object PASRoleMember -ArgumentList ($member.Name, $member.Guid, $member.Type)

                    $role.addMember($mem) | Out-Null
                }

            }# Try # to get the members of this role
            Catch
            {
                # if an error occurred during the rest call, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New PASAccount object.")
				$e.AddExceptionData($_)
				$e.AddData("members",$members)
                $e.AddData("member",$member)
				$e.AddData("role",$role)
                $e.AddData("mem",$mem)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
            }# Catch

            Try # to get the administrative rights of this role
            {
                $rights = Invoke-PASAPI -APICall core/GetAssignedAdministrativeRights -Body (@{role=$role.ID} | ConvertTo-Json)

                foreach ($right in $rights.Results.Row)
                {
                    $r = New-Object PASRoleAdministrativeRight -ArgumentList ($right.Description, $right.Path)

                    $role.addAdministrativeRight($r) | Out-Null
                }

                # add it to our temporary returner object
				$obj | Add-Member -MemberType NoteProperty -Name Roles -Value $role
            }# Try # to get the administrative rights of this role
            Catch
            {
                # if an error occurred during the rest call, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New PASAccount object.")
				$e.AddExceptionData($_)
				$e.AddData("rights",$rights)
                $e.AddData("right",$right)
				$e.AddData("r",$r)
                $e.AddData("role",$role)
				$obj | Add-Member -MemberType NoteProperty -Name Exceptions -Value $e
            }# Catch
			Finally
			{
				# nulling values to free memory
				$role    = $null
				$members = $null
                $member  = $null
                $mem     = $null
				$query   = $null
			}

			# return the returner object
			$obj
		} | # $AllData = $basesqlquery | Foreach-Object -Parallel {
		ForEach-Object -Begin { $i = 0 } -Process { 
			
			$Completed = $($i/($basesqlquery | Measure-Object | Select-Object -ExpandProperty Count)*100)
			# incrementing result count
			$i++
			# update progress bar
			Write-Progress -Activity "Getting Roles" -Status ("{0} out of {1} Complete" -f $i,$basesqlquery.Count) -PercentComplete $Completed -CurrentOperation ("Current: [{0}]" -f $_.Name)
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

	return $AllData.Roles
}# function global:Get-PASRole
#endregion
###########