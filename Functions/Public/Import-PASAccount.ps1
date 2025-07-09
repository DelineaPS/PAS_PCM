###########
#region ### global:Import-PASAccount # CMDLETDESCRIPTION : Imports PAS Accounts from another PAS tenant :
###########
function global:Import-PASAccount
{
    <#
    .SYNOPSIS
    Imports a PAS Account from another PAS tenant.

    .DESCRIPTION
    This cmdlet will Import a PAS Account from another Delinea Privilege Access Service tenant. This requires two PAS tenants.

    First on the old PAS tenant, get the Accounts you want to import with "Get-PASAccount". Save these to a variable.

    Then, connect to the new PAS tenant, and use this cmdlet to recreate the account, along with all non-inherited principals 
    with whatever permissions they had. The only properties currently supported in the import are the following:
    
    - Username
    - Description

    Any other options such as policies or Workflow are currently not supported at this time.

    This also requires that you have Connectors pointed to the same AD domain. This is to ensure that the AD lookup of any
    AD principals works correctly. For example:

    TenantA.my.centrify.net is pointed to mydomain.com
    TenantB.my.centrify.net is also pointed to mydomain.com

    First connect to TenantA.my.centrify.net. Then run "$myaccounts = Get-PASAccount".

    Then connect to TenantB.my.centrify.net. Then run "Import-PASAccount -PASAccounts $myaccounts"

    If Connectors are registered in both tenants, then all non-inherited principals will be reassigned the same permissions
    they had on the system prior to the import.

    If a principal is from Federation, then the Federated Name (SourceDsLocalized) need to match.

    .PARAMETER PASAccounts
    The PASAccount objects to import.

    .PARAMETER IgnoreThesePrincipals
    This is a string array of principals that you want to ignore reassigning permissions in the new tenant.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function only prints to the console.

    .EXAMPLE
    C:\PS> Import-PASAccount -PASAccounts $PASAccounts
    For each PAS Account specified in $PASAccounts, attempt to recreate the account in the new tenant. After creation,
    attempt to locate all non-inherited principals that had permission on the account and reassign the same permissions
    to that account. The Source of the account (Host for local accounts, Domain for domain accounts). For example, to
    import the root account on LINUXSERVER01, then LINUXSERVER01 must already exist in the tenant.

    .EXAMPLE
    C:\PS> Import-PASAccount -PASAccounts $PASAccounts -IgnoreThesePrincipals "bob@domain.com","ITTeam@domain.com"
    For each PAS Account specified in $PASAccounts, attempt to recreate the account in the new tenant. After creation,
    attempt to locate all non-inherited principals that had permission on the account and reassign the same permissions
    to that account. The Source of the account (Host for local accounts, Domain for domain accounts). For example, to
    import the root account on LINUXSERVER01, then LINUXSERVER01 must already exist in the tenant. However, the principals 
    "bob@domain.com" and "ITTeam@domain.com" will be ignored if they are found as non-inherited principals on the system.
    
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PASAccounts to import.")]
        [PASAccount[]]$PASAccounts,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Principals to ignore when reassigning permissions.")]
        [System.String[]]$IgnoreThesePrincipals
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # for each account
    foreach($PASAccount in $PASAccounts)
    {
        Write-Verbose ("Account Exists Check [{0}]" -f $PASAccount.SSName)

        # get the existing account
        $existingaccount = Get-PASAccount -SourceName $PASAccount.SourceName -UserName $PASAccount.UserName

        # if the account doesn't exist
        if (!$existingaccount)
        {
            $sourceobject = $null

            # get the source
            Switch ($PASAccount.AccountType)
            {
                "Local"  { $sourceobject = Query-RedRock -SQLQuery ("SELECT Name,ID From Server WHERE Name = '{0}'"  -f $PASAccount.SourceName)    ; $sourceobject | Add-Member -MemberType NoteProperty -Name "Tag" -Value "Host"     ; break }
                "Domain" { $sourceobject = Query-RedRock -SQLQuery ("SELECT Name,ID From VaultDomain WHERE Name = '{0}'" -f $PASAccount.SourceName) ; $sourceobject | Add-Member -MemberType NoteProperty -Name "Tag" -Value "DomainID" ; break }
                default  { $sourceobject = $false; break }
            }

            # if the source object doesn't exist
            if (!$sourceobject)
            {
                Write-Warning = ("Source object {0} {1} doesn't exist." -f $PASAccount.AccountType, $PASAccount.SourceName)      
                continue
            }

            Try # to make it
            {
                Write-Host ("Creating Account [{0}] ... " -f $PASAccount.SSName) -NoNewline

                $call = Invoke-PASAPI -APICall ServerManage/AddAccount -Body (@{Description=$PASAccount.Description;($sourceobject.Tag)=$sourceobject.ID;isManaged=$false;Password=$PASAccount.Password;User=$PASAccount.UserName} | ConvertTo-Json)
                Write-Host ("Done!") -ForegroundColor Green
            }
            Catch
            {
                Write-Host ("Error!") -ForegroundColor Red
                # if an error occurred during creating the system, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New Account object.")
				$e.AddExceptionData($_)
				$e.AddData("call",$call)
				$e.AddData("passaccount",$PASAccount)
                $e.AddData("sourceobject",$sourceobject)
                $global:e = $e
            }
        }# if (!$existingaccount)
    }# foreach($PASAccount in $PASAccounts)

    # now that the role exists do a permission update for non inherited principals

    # for each system
    foreach ($PASAccount in $PASAccounts)
    {
        Write-Verbose ("PermissionsExistsCheck [{0}]" -f $PASAccount.SSName)

        # get the existing account
        $existingaccount = Get-PASAccount -SourceName $PASAccount.SourceName -UserName $PASAccount.UserName

        # getting the noninherited permissionrowaces
        $importednoninherits  = $PASAccount.PermissionRowAces | Where-Object -Property isInherited -eq $false
        $existingnoninherits  = $existingaccount.PermissionRowAces | Where-Object -Property isInherited -eq $false

        # if there are non inherited principals to import from the original system
        if (($importednoninherits | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
        {
            Write-Host ("  - noninherits found for [{0}]" -f $PASAccount.SSName)

            # getting the missing principals
            $missingprincipals = Compare-Object $importednoninherits $existingnoninherits -Property PrincipalType,PrincipalName,PASPermission -PassThru | Where-Object {$_.SideIndicator -eq "<="}

            # removing excess principals if they were specified
            $remainingprincipals = $missingprincipals | Where-Object {$_.PrincipalName -notin $IgnoreThesePrincipals}
            
            # if remainingprincipals is not null
            if ($remainingprincipals -ne $null)
            {
                # prep the principals for the endpoint
                $PermissionRowAces = @((New-PASImportPermission -PermissionRowAces $remainingprincipals))

                # and prepare the jsonbody
                $jsonbody = Build-PASGrantPermissionPayload -PASImportPermissions $PermissionRowAces -TargetUuid $existingaccount.ID

                Try
                {
                    Write-Host ("    - setting permissions for missing principals on [{0}] ... " -f $PASAccount.SSName) -NoNewline
                    $call = Invoke-PASAPI -APICall ServerManage/SetAccountPermissions -Body $jsonbody
                    Write-Host ("Done!") -ForegroundColor Green
                }
                Catch
                {   
                    Write-Host ("Error!") -ForegroundColor Red
                    # if an error occurred during setting resource permissions, create a new PASException and return that with the relevant data
				    $e = New-Object PASPCMException -ArgumentList ("Error during setting permissions on account object.")
				    $e.AddExceptionData($_)
				    $e.AddData("call",$call)
				    $e.AddData("existingaccount",$existingaccount)
                    $e.AddData("PASAccount",$PASAccount)
                    $e.AddData("importednoninherits",$importednoninherits)
                    $e.AddData("existingnoninherits",$existingnoninherits)
                    $e.AddData("missingprincipals",$missingprincipals)
                    $e.AddData("remainingprincipals",$remainingprincipals)
                    $e
                }# Catch
            }# if ($remainingprincipals -ne $null)
        }# if (($noninherits | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
    }# foreach ($PASAccount in $PASAccounts)

}# function global:Import-PASAccount
#endregion
###########