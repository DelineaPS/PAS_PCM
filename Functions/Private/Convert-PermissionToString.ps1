###########
#region ### global:Convert-PermissionToString # Converts a Grant integer permissions number to readable permissions
###########
function global:Convert-PermissionToString
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The type of permission to convert.")]
        [System.String]$Type,

        [Parameter(Mandatory = $true, HelpMessage = "The Grant (int) number of the permissions to convert.")]
        [System.Int32]$PermissionInt
    )

    # setting our return value
    [System.String]$ReturnValue = ""

    # setting our readable permission hash based on our object type
    switch -Regex ($Type)
    {
        "Secret|DataVault" { $AceHash = @{ Grant = 1; View = 4; Edit  = 8; Delete = 64; Retrieve = 65536} ; break } # Grant,View,Edit,Delete,Retrieve
        "Set"              { $AceHash = @{ Grant    = 1; View    = 4; Edit    = 8; Delete    = 64} ; break } #Grant,View,Edit,Delete
        "ManualBucket|SqlDynamic"    
                           { $AceHash = @{ Grant    = 1; View    = 4; Edit     = 8; Delete    = 64} ; break }
        "Phantom"          { $AceHash = @{ Grant = 1; View = 4; Edit  = 8; Delete = 64; Add = 65536} ; break } # Grant,View,Edit,Delete,Add
        "Server"           { $AceHash = @{ Grant = 1; View = 4; Edit  = 8; Delete = 64; AgentAuth = 65536; 
                                           ManageSession = 128; RequestZoneRole = 131072; AddAccount = 524288;
                                           UnlockAccount = 1048576; OfflineRescue = 2097152;  ManagePrivilegeElevationAssignment = 4194304}; break }
        "Domain"           { $AceHash = @{ GrantAccount = 1; ViewAccount = 4; EditAccount = 8; DeleteAccount = 64; LoginAccount = 128; CheckoutAccount = 65536; 
                                           UpdatePasswordAccount = 131072; RotateAccount = 524288; FileTransferAccount = 1048576}; break }
        "Cloud"            { $AceHash = @{ GrantCloudAccount = 1; ViewCloudAccount = 4; EditVaultAccount = 8; DeleteCloudAccount = 64; UseAccessKey = 128;
                                           RetrieveCloudAccount = 65536} ; break }
        "Local|Account|VaultAccount" # Owner,View,Manage,Delete,Login,Naked,UpdatePassword,FileTransfer,UserPortalLogin 262276
                           { $AceHash = @{ Owner = 1; View = 4; Manage = 8; Delete = 64; Login = 128;  Naked = 65536; 
                                           UpdatePassword = 131072; UserPortalLogin = 262144; RotatePassword = 524288; FileTransfer = 1048576}; break }
        "Database|VaultDatabase"
                           { $AceHash = @{ GrantDatabaseAccount = 1; ViewDatabaseAccount = 4; EditDatabaseAccount = 8; DeleteDatabaseAccount = 64;
                                           CheckoutDatabaseAccount = 65536; UpdatePasswordDatabaseAccount = 131072; RotateDatabaseAccount = 524288}; break }
        "Subscriptions"    { $AceHash = @{ Grant = 1; View = 4; Edit = 8; Delete = 64} ; break } #Grant,View,Edit,Delete
    }# switch -Regex ($Type)

    # for each bit (sorted) in our specified permission hash
    foreach ($bit in ($AceHash.GetEnumerator() | Sort-Object))
    {
        # if the bit seems to exist
        if (($PermissionInt -band $bit.Value) -ne 0)
        {
            # add the key to our return string
            $ReturnValue += $bit.Key + ","
        }
    }# foreach ($bit in ($AceHash.GetEnumerator() | Sort-Object))

    # return the string, removing the trailing "|"
    return ($ReturnValue.TrimEnd("|"))
}# global:Convert-PermissionToString
#endregion
###########