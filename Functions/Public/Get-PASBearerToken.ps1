###########
#region ### global:Get-PASBearerToken # CMDLETDESCRIPTION : Gets a PAS Bearer Token information. :
###########
function global:Get-PASBearerToken
{
    <#
    .SYNOPSIS
    Gets a bearer token from a Delinea PAS tenant.

    .DESCRIPTION
	Gets a bearer token from a Delinea PAS tenant. This returns an access token in the form of a System.String object.

    .PARAMETER Url
    Provide the Url of the PAS tenant. For example, myurl.my.centrify.net.

    .PARAMETER Client
    Provide the Application ID of the OAuth2 client web app.

	.PARAMETER Scope
    Provide the scope to use of the designated OAuth2 client web app.

	.PARAMETER Secret
    Provide the secret to use with the OAuth2 client web app. You can use Connect-PASTenant to obtain this.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function returns an access token in the form of a System.String object.

    .EXAMPLE
    C:\PS> Get-PASBearerToken -Url myurl.my.centrify.net -Client oauthtest -Scope securitywhoami -Secret XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX==
	Connects to the PAS tenant at myurl.my.centrify.net and attempting to connect to the "oauthtest" web app
	with the configured scope "securitywhoami" using the supplied secret for authentication.

	If successful, the Bearer Token for this connection will be returned as a System.String object.
    #>
    param
	(
        [Parameter(Mandatory=$true, HelpMessage = "Specify the URL to connect to.")]
        [System.String]$Url,
        
        [Parameter(Mandatory=$true, HelpMessage = "Specify the OAuth2 Client name.")]
		[System.String]$Client,	

        [Parameter(Mandatory=$true, HelpMessage = "Specify the OAuth2 Scope name.")]
		[System.String]$Scope,	

        [Parameter(Mandatory=$true, HelpMessage = "Specify the OAuth2 Secret.")]
		[System.String]$Secret		
    )# param

    # Setup variable for connection
	$Uri = ("https://{0}/oauth2/token/{1}" -f $Url, $Client)
	$ContentType = "application/x-www-form-urlencoded" 
	$Header = @{ "X-CENTRIFY-NATIVE-CLIENT" = "True"; "Authorization" = ("Basic {0}" -f $Secret) }
	Write-Host ("Connecting to Delinea PAS (https://{0}) using OAuth2 Client Credentials flow" -f $Url)
			
    # Format body
    $Body = ("grant_type=client_credentials&scope={0}" -f  $Scope)
	
	# Debug informations
	Write-Debug ("Uri= {0}" -f $Uri)
	Write-Debug ("Header= {0}" -f $Header)
	Write-Debug ("Body= {0}" -f $Body)

	Try
	{
		# Connect using OAuth2 Client
		$WebResponse = Invoke-WebRequest -UseBasicParsing -Method Post -SessionVariable PASSession -Uri $Uri -Body $Body -ContentType $ContentType -Headers $Header
    
	}
	Catch
	{
        $e = New-Object PASPCMException -ArgumentList ("Error during Get-PASBearerToken.")
		$e.AddExceptionData($_)
		$e.AddData("WebResponse",$WebResponse)
		$e.AddData("Uri",$Uri)
		$e.AddData("Json",$Json)
	}
    
	# Get Response
	$WebResponseResult = $WebResponse.Content | ConvertFrom-Json
    if ([System.String]::IsNullOrEmpty($WebResponseResult.access_token))
    {
        Throw "OAuth2 Client authentication error."
    }
	else
    {
        # Return Bearer Token from successfull login
        return $WebResponseResult.access_token
    }
}# function global:Get-PASBearerToken
#endregion
###########