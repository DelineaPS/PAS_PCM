###########
#region ### global:Import-PASSystem # CMDLETDESCRIPTION : Imports PAS Systems from another PAS tenant :
###########
function global:Import-PASSystem
{
    <#
    .SYNOPSIS
    Imports a PAS System from another PAS tenant.

    .DESCRIPTION
    This cmdlet will Import a PAS System from another Delinea Privilege Access Service tenant. This requires two PAS tenants.

    First on the old PAS tenant, get the Systems you want to import with "Get-PASSystem". Save these to a variable

    Then, connect to the new PAS tenant, and use this cmdlet to recreate the role, along with all non-inherited principals 
    with whatever permissions they had. The only properties currently supported in the import are the following:
    
    - Name (as it appears in the old tenant)
    - FQDN
    - Description
    - System Type (Windows or UNIX/Linux)

    Any other options such as policies or Zone Role Workflow are currently not supported at this time.

    This also requires that you have Connectors pointed to the same AD domain. This is to ensure that the AD lookup of any
    AD principals works correctly. For example:

    TenantA.my.centrify.net is pointed to mydomain.com
    TenantB.my.centrify.net is also pointed to mydomain.com

    First connect to TenantA.my.centrify.net. Then run "$mysystems = Get-PASSystem".

    Then connect to TenantB.my.centrify.net. Then run "Import-PASSystem -PASSystem $mysystems"

    If Connectors are registered in both tenants, then all non-inherited principals will be reassigned the same permissions
    they had on the system prior to the import.

    If a principal is from Federation, then the Federated Name (SourceDsLocalized) need to match.

    .PARAMETER PASRoles
    The PASRole objects to import.

    .PARAMETER IgnoreThesePrincipals
    This is a string array of principals that you want to ignore reassigning permissions in the new tenant.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function only prints to the console.

    .EXAMPLE
    C:\PS> Import-PASSystem -PASSystems $PASSystems
    For each PAS System specified in $PASSystems, attempt to recreate the system in the new tenant. After creation,
    attempt to locate all non-inherited principals that had permission on the system and reassign the same permissions
    to that system.

    .EXAMPLE
    C:\PS> Import-PASSystem -PASSystems $PASSystems -IgnoreThesePrincipals "bob@domain.com","ITTeam@domain.com"
    For each PAS System specified in $PASSystems, attempt to recreate the system in the new tenant. After creation,
    attempt to locate all non-inherited principals that had permission on the system and reassign the same permissions
    to that system. However, the principals "bob@domain.com" and "ITTeam@domain.com" will be ignored if they are found
    as non-inherited principals on the system.
    
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PASSystems to import.")]
        [PASSystem[]]$PASSystems,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Principals to ignore when reassigning permissions.")]
        [System.String[]]$IgnoreThesePrincipals
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # for each system
    foreach($passystem in $PASSystems)
    {
        Write-Verbose ("System Exists Check [{0}]" -f $passystem.Name)

        # get the existing system
        $existingsystem = Get-PASSystem -Name $passystem.Name

        # if the system doesn't exist
        if (!$existingsystem)
        {
            Try # to make it
            {
                Write-Host ("Creating System [{0}] ... " -f $passystem.Name) -NoNewline
                $call = Invoke-PASAPI -APICall ServerManage/AddResource -Body (@{ComputerClass=$passystem.ComputerClass;Description=$passystem.Description;FQDN=$passystem.FQDN;Name=$passystem.Name;SessionType=$passystem.SessionType} | ConvertTo-Json)
                Write-Host ("Done!") -ForegroundColor Green
            }
            Catch
            {
                Write-Host ("Error!") -ForegroundColor Red
                # if an error occurred during creating the system, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New System object.")
				$e.AddExceptionData($_)
				$e.AddData("call",$call)
				$e.AddData("passsystem",$passystem)
                $e
            }
        }# if (!$existingsystem)
    }# foreach($passystem in $PASSystems)

    # now that the role exists do a permission update for non inherited principals

    # for each system
    foreach ($passystem in $PASSystems)
    {
        Write-Verbose ("PermissionsExistsCheck [{0}]" -f $passystem.Name)

        # get the existing system
        $existingsystem = Get-PASSystem -Name $passystem.Name

        # getting the noninherited permissionrowaces
        $importednoninherits  = $passystem.PermissionRowAces | Where-Object -Property isInherited -eq $false
        $existingnoninherits  = $existingsystem.PermissionRowAces | Where-Object -Property isInherited -eq $false

        # if there are non inherited principals to import from the original system
        if (($importednoninherits | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
        {
            Write-Host ("  - noninherits found for [{0}]" -f $passystem.Name)

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
                $jsonbody = Build-PASGrantPermissionPayload -PASImportPermissions $PermissionRowAces -TargetUuid $existingsystem.ID

                Try
                {
                    Write-Host ("    - setting permissions for missing principals on [{0}] ... " -f $passystem.Name) -NoNewline
                    $call = Invoke-PASAPI -APICall ServerManage/SetResourcePermissions -Body $jsonbody
                    Write-Host ("Done!") -ForegroundColor Green
                }
                Catch
                {   
                    Write-Host ("Error!") -ForegroundColor Red
                    # if an error occurred during setting resource permissions, create a new PASException and return that with the relevant data
				    $e = New-Object PASPCMException -ArgumentList ("Error during setting permissions on computer object.")
				    $e.AddExceptionData($_)
				    $e.AddData("call",$call)
				    $e.AddData("existingsystem",$existingsystem)
                    $e.AddData("passystem",$passystem)
                    $e.AddData("importednoninherits",$importednoninherits)
                    $e.AddData("existingnoninherits",$existingnoninherits)
                    $e.AddData("missingprincipals",$missingprincipals)
                    $e.AddData("remainingprincipals",$remainingprincipals)
                    $e
                }# Catch
            }# if ($remainingprincipals -ne $null)
        }# if (($noninherits | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
    }# foreach ($passystem in $PASSystems)

}# function global:Import-PASSystem
#endregion
###########