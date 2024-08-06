###########
#region ### global:Get-PASRowAce # Gets RowAces for the specified PAS object
###########
function global:Get-PASRowAce
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The type of object to search.")]
        [System.String]$Type,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the object to search.", ParameterSetName = "Name")]
        [System.String]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "The Uuid of the object to search.",ParameterSetName = "Uuid")]
        [System.String]$Uuid
    )

    # if the Name parameter was used
    if ($PSBoundParameters.ContainsKey("Name"))
    {
        # getting the uuid of the object
        $uuid = Get-PASObjectUuid -Type $Type -Name $Name
    }

    # setting the table variable
    [System.String]$table = ""

    Switch -Regex ($Type)
    {
        "Secret"    { $table = "DataVault"    ; break }
        "Set|Phantom|ManualBucket|SqlDynamic"
                    { $table = "Collections"  ; break }
        "Domain|Database|Local|Cloud"
                    { $table = "VaultAccount" ; break }
        "Server"    { $table = "Server"       ; break }
        default     { $table = $Type          ; break }
    }

    # preparing the JSONBody
    $JSONBody = @{ RowKey = $uuid ; Table = $table } | ConvertTo-Json

    # getting the RowAce information
    $RowAces = Invoke-PASAPI -APICall "Acl/GetRowAces" -Body $JSONBody

    # setting a new ArrayList for the return
    $RowAceObjects = New-Object System.Collections.ArrayList

    # for each rowace retrieved
    foreach ($rowace in $RowAces)
    {
        # ignore any global root or tech support entries
        if ($rowace.Type -eq "GlobalRoot" -or $rowace.PrincipalName -eq "Technical Support Access")
        {
            continue
        }

        # if the type is Super (from default global roles with read permissions)
        if ($rowace.Type -eq "Super")
        {
            # set the Grant to 4 instead of "Read"
            [System.Int64]$rowace.Grant = 4
        }

		# nulling out InheritedFrom
		[System.String]$InheritedFrom = $null

		# if this rowace is inherited
		if ($rowace.Inherited)
		{
			Switch ($rowace.Type)
			{
				"GlobalTable" { $InheritedFrom = "Global Settings"; break }
				"Collection"  { $InheritedFrom = ("Set: {0}" -f $rowace.CollectionName); break }
				"Super"       { $InheritedFrom = ("Admin Right: {0}" -f $rowace.SuperName); break }
				default       { break }
			}
		}# if ($rowace.Inherited)

        Try
        {
            # creating the PASPermission object
            $PASpermission = New-Object PASPermission -ArgumentList ($Type, $rowace.Grant, $rowace.GrantStr)

            # creating the PASRowAce object
            $obj = New-Object PermissionRowAce -ArgumentList ($rowace.PrincipalType, $rowace.Principal, `
				$rowace.PrincipalName, $rowace.Inherited, $InheritedFrom, $PASpermission)
        }# Try
        Catch
        {
            # setting our custom Exception object and stuff for further review
            $e = New-Object PASPCMException -ArgumentList ("A PASRowAce error has occurred. Check `$LastRowAceError for more information.")
			$e.AddExceptionData($_)
			$e.AddData("RowAce",$rowace)
			$e.AddData("PASPermission",$PASpermission)
			$global:LastPASPCMError = $e
        }# Catch

        # adding the PASRowAce object to our ArrayList
        $RowAceObjects.Add($obj) | Out-Null
    }# foreach ($rowace in $RowAces)

    # returning the RowAceObjects
    return $RowAceObjects
}# function global:Get-PASRowAce
#endregion
###########