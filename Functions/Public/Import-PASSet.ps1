###########
#region ### global:Import-PASSet # CMDLETDESCRIPTION : Imports PAS Set from another PAS tenant :
###########
function global:Import-PASSet
{
    <#
    .SYNOPSIS
    Imports a PAS Set from another PAS tenant.
    
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PASSets to import.")]
        [PSObject[]]$PASSets,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Principals to ignore when reassigning permissions.")]
        [System.String[]]$IgnoreThesePrincipals
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # for each system
    foreach($PASSet in $PASSets)
    {
        $setname = $PASSet.Name -replace "'","''"

        Write-Verbose ("Set Exists Check [{0}]" -f $PASSet.Name)

        # get the existing set
        $existingset = Get-PASSet -Name $setname | Where-Object -Property ObjectType -eq $PASSet.ObjectType

        # if the set doesn't exist
        if (!$existingset)
        {
            Try # to make it
            {
                Write-Host ("Creating {0} Set [{1}] ... " -f $PASSet.ObjectType, $PASSet.Name) -NoNewline

                # if this is a Dynamic Set
                if ($PASSet.SetType -eq "SqlDynamic")
                {
                    $call = Invoke-PASAPI -APICall Collection/CreateDynamicCollection -Body (@{CollectionType="SqlDynamic";Description=$PASSet.Description;Name=$PASSet.Name;ObjectType=$PASSet.ObjectType;sql=$PASSet.SqlDynamic} | ConvertTo-Json)
                }
                else
                {
                    $call = Invoke-PASAPI -APICall Collection/CreateManualCollection -Body (@{CollectionType="ManualBucket";Description=$PASSet.Description;Name=$PASSet.Name;ObjectType=$PASSet.ObjectType} | ConvertTo-Json)
                }
                
                Write-Host ("Done!") -ForegroundColor Green
            }
            Catch
            {
                Write-Host ("Error!") -ForegroundColor Red
                # if an error occurred during creating the system, create a new PASException and return that with the relevant data
				$e = New-Object PASPCMException -ArgumentList ("Error during New Set object.")
				$e.AddExceptionData($_)
				$e.AddData("call",$call)
				$e.AddData("passet",$PASSet)
                $global:e = $e
            }# Catch
        }# if (!$existingset)
    }# foreach($PASSet in $PASSets)

    # now that the set exists do a permission update for permissions and member permissions

    # for each system
    foreach ($PASSet in $PASSets)
    {
        Write-Verbose ("PermissionsExistsCheck [{0}]" -f $PASSet.SSName)

        # get the existing set
        $existingset = Get-PASSet -Name $setname

        # getting the noninherited permissionrowaces
        $importedinherits = $PASSet.PermissionRowAces
        $existinginherits = $existingset.PermissionRowAces

        # if there are non inherited principals to import from the original system
        if (($importedinherits | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
        {
            Write-Host ("  - permissions found for [{0}]" -f $PASSet.Name)

            # getting the missing principals
            $missingprincipals = Compare-Object $importedinherits $existinginherits -Property PrincipalType,PrincipalName,PASPermission -PassThru | Where-Object {$_.SideIndicator -eq "<="}

            # removing excess principals if they were specified
            $remainingprincipals = $missingprincipals | Where-Object {$_.PrincipalName -notin $IgnoreThesePrincipals}
            
            # if remainingprincipals is not null
            if ($remainingprincipals -ne $null)
            {
                # prep the principals for the endpoint
                $PermissionRowAces = @((New-PASImportPermission -PermissionRowAces $remainingprincipals))

                # and prepare the jsonbody
                $jsonbody = Build-PASGrantPermissionPayload -PASImportPermissions $PermissionRowAces -TargetUuid $existingset.ID

                Try
                {
                    Write-Host ("    - setting permissions for missing principals on [{0}] ... " -f $PASSet.Name) -NoNewline
                    $call = Invoke-PASAPI -APICall Collection/SetCollectionPermissions -Body $jsonbody
                    Write-Host ("Done!") -ForegroundColor Green
                }
                Catch
                {   
                    Write-Host ("Error!") -ForegroundColor Red
                    # if an error occurred during setting resource permissions, create a new PASException and return that with the relevant data
				    $e = New-Object PASPCMException -ArgumentList ("Error during setting permissions on set object.")
				    $e.AddExceptionData($_)
				    $e.AddData("call",$call)
				    $e.AddData("existingset",$existingset)
                    $e.AddData("PASSet",$PASSet)
                    $e.AddData("importedinherits",$importedinherits)
                    $e.AddData("existinginherits",$existinginherits)
                    $e.AddData("missingprincipals",$missingprincipals)
                    $e.AddData("remainingprincipals",$remainingprincipals)
                    $e
                }# Catch
            }# if ($remainingprincipals -ne $null)
        }# if (($noninherits | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)

        # now doing member permissions if this set isn't dynamic

        if ($PASSet.SetType -ne "SqlDynamic")
        {
            # getting the member inherited permissionrowaces
            $importedmemberinherits  = $PASSet.PermissionRowAces
            $existingmemberinherits  = $existingset.PermissionRowAces

            # if there are non inherited principals to import from the original system
            if (($importedmemberinherits | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
            {
                Write-Host ("  - noninherits found for [{0}]" -f $PASSet.Name)

                # getting the missing principals
                $missingprincipals = Compare-Object $importedmemberinherits $existingmemberinherits -Property PrincipalType,PrincipalName,PASPermission -PassThru | Where-Object {$_.SideIndicator -eq "<="}

                # removing excess principals if they were specified
                $remainingprincipals = $missingprincipals | Where-Object {$_.PrincipalName -notin $IgnoreThesePrincipals}
                
                # if remainingprincipals is not null
                if ($remainingprincipals -ne $null)
                {
                    # prep the principals for the endpoint
                    $PermissionRowAces = @((New-PASImportPermission -PermissionRowAces $remainingprincipals))

                    # and prepare the jsonbody
                    $jsonbody = Build-PASGrantPermissionPayload -PASImportPermissions $PermissionRowAces -TargetUuid $existingset.ID

                    Try
                    {
                        Write-Host ("    - setting permissions for missing principals on [{0}] ... " -f $PASSet.Name) -NoNewline
                        $call = Invoke-PASAPI -APICall ServerManage/SetResourceCollectionPermissions -Body $jsonbody
                        Write-Host ("Done!") -ForegroundColor Green
                    }
                    Catch
                    {   
                        Write-Host ("Error!") -ForegroundColor Red
                        # if an error occurred during setting resource permissions, create a new PASException and return that with the relevant data
                        $e = New-Object PASPCMException -ArgumentList ("Error during setting member permissions on set object.")
                        $e.AddExceptionData($_)
                        $e.AddData("call",$call)
                        $e.AddData("existingset",$existingset)
                        $e.AddData("PASSet",$PASSet)
                        $e.AddData("importedmemberinherits",$importedmemberinherits)
                        $e.AddData("existingmemberinherits",$existingmemberinherits)
                        $e.AddData("missingprincipals",$missingprincipals)
                        $e.AddData("remainingprincipals",$remainingprincipals)
                        $e
                    }# Catch
                }# if ($remainingprincipals -ne $null)
            }# if (($noninherits | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)

            # now update the set with the proper members.

            Switch ($PASSet.ObjectType)
            {
                "VaultAccount" { $pasobjects = Get-PASAccount -SSName ($PASSet.SetMembers.Name | ?{!([System.String]::IsNullOrEmpty($_))}); break }
                "Server"       { $pasobjects = Get-PASSystem  -Name ($PASSet.SetMembers.Name   | ?{!([System.String]::IsNullOrEmpty($_))}); break }
                default        { break }
            }

            $global:PASSet = $PASSet
            $global:pasobject = $pasobjects
            
            $collection = New-Object System.Collections.ArrayList

            foreach ($pasobject in $pasobjects)
            {
                $obj = @{}
                $obj.Key = $pasobject.ID
                $obj.MemberType = "Row"
                $obj.Table = $PASSet.ObjectType
                $collection.Add($obj) | Out-Null
            }

            $payload = @{}
            $payload.add = $collection
            $payload.id = $existingset.ID

            Invoke-PASAPI -APICall Collection/UpdateMembersCollection -Body ($payload | ConvertTo-Json)
        }# if ($PASSet.SetType -eq "SqlDynamic")

    }# foreach ($PASSet in $PASSets)

}# function global:Import-PASSet
#endregion
###########