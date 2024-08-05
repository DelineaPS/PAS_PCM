###########
#region ### Verify-PASConnection # Check to ensure you are connected to the tenant before proceeding.
###########
function global:Verify-PASConnection
{
    <#
    .SYNOPSIS
    This function verifies you have an active connection to a PAS Tenant.

    .DESCRIPTION
    This function verifies you have an active connection to a PAS Tenant. It checks for the existance of a $PASConnection 
    variable to first check if a connection has been made, then it makes a Security/whoami RestAPI call to ensure the connection is active and valid.
    This function will store a date any only check if the last attempt was made more than 5 minutes ago. If the last verify attempt occured
    less than 5 minutes ago, the check is skipped and a valid connection is assumed. This is done to prevent an overbundence of whoami calls to the 
    PAS.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function only throws an error if there is a problem with the connection.

    .EXAMPLE
    C:\PS> Verify-PASConnection
    This function will not return anything if there is a valid connection. It will throw an exception if there is no connection, or an 
    expired connection.
    #>

    if ($PASConnection -eq $null)
    {
        throw ("There is no existing `$PASConnection. Please use Connect-PASTenant to connect to your PAS tenant. Exiting.")
    }
    else
    {
        Try
        {
            # check to see if Lastwhoami is available
            if ($global:LastWhoamicheck)
            {
                # if it is, check to see if the current time is less than 5 minute from its previous whoami check
                if ($(Get-Date).AddMinutes(-5) -lt $global:LastWhoamicheck)
                {
                    # if it has been less than 5 minutes, assume we're still connected
                    return
                }
            }# if ($global:LastWhoamicheck)
            
            $uri = ("https://{0}/Security/whoami" -f $global:PASConnection.PodFqdn)

            # calling Security/whoami
            $WhoamiResponse = Invoke-RestMethod -Method Post -Uri $uri @global:PASSessionInformation
           
            # if the response was successful
            if ($WhoamiResponse.Success)
            {
                # setting the last whoami check to reduce frequent whoami calls
                $global:LastWhoamicheck = (Get-Date)
                return
            }
            else
            {
                throw ("There is no active, valid PAS Tenant connection. Please use Connect-PASTenant to re-connect to your Delinea tenant. Exiting.")
            }
        }# Try
        Catch
        {
            throw ("There is no active, valid PAS Tenant connection. Please use Connect-PASTenant to re-connect to your Delinea tenant. Exiting.")
        }
    }# else
}# function global:Verify-PASConnection
#endregion
###########