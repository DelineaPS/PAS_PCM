# class for holding Secret information
[NoRunspaceAffinity()]
class PASSecret
{
    [System.String]$Name                 # the name of the Secret
    [System.String]$Type                 # the type of Secret
    [System.String]$ParentPath           # the Path of the Secret
    [System.String]$Description          # the description 
    [System.String]$ID                   # the ID of the Secret
    [System.String]$FolderId             # the FolderID of the Secret
    [System.DateTime]$whenCreated        # when the Secret was created
    [System.DateTime]$whenModified       # when the Secret was last modified
    [System.DateTime]$lastRetrieved      # when the Secret was last retrieved
    [System.String]$SecretText           # (Text Secrets) The contents of the Text Secret
    [System.String]$SecretFileName       # (File Secrets) The file name of the Secret
    [System.String]$SecretFileSize       # (File Secrets) The file size of the Secret
    [System.String]$SecretFilePath       # (File Secrets) The download FilePath for this Secret
    [PSCustomObject[]]$RowAces           # The RowAces (Permissions) of this Secret
    [System.Boolean]$WorkflowEnabled     # is Workflow enabled
    [PSCustomObject[]]$WorkflowApprovers # the Workflow Approvers for this Secret
	[System.Collections.ArrayList]$SecretActivity = @{} 
	hidden [System.String]$PASPCMObjectType

	# empty constructor
    PASSecret () {}

	# method for reserialization
	resetObject ($pasobject)
	{
		# for each property passed in
		foreach ($property in $pasobject.PSObject.Properties) 
        {
			# loop into each property and readd it
            $this.("{0}" -f $property.Name) = $property.Value
        }
	}# resetObject ($pasobject)

	# primary constructor
    PASSecret ($secretinfo)
    {
		$this.PASPCMObjectType = "PASSecret"
        $this.Name            = $secretinfo.SecretName
        $this.Type            = $secretinfo.Type
        $this.ParentPath      = $secretinfo.ParentPath
        $this.Description     = $secretinfo.Description
        $this.ID              = $secretinfo.ID
        $this.FolderId        = $secretinfo.FolderId
        $this.WorkflowEnabled = $secretinfo.WorkflowEnabled

        if ($secretinfo.whenCreated -ne $null)
        {
            $this.whenCreated = $secretinfo.whenCreated
        }
        
        # if the secret has been updated
        if ($secretinfo.WhenContentsReplaced -ne $null)
        {
            # also update the whenModified property
            $this.whenModified = $secretinfo.WhenContentsReplaced
        }

        # getting when the secret was last accessed
        $lastquery = Query-RedRock -SQLQuery ('SELECT DataVault.ID, DataVault.SecretName, Event.WhenOccurred FROM DataVault JOIN Event ON DataVault.ID = Event.DataVaultItemID WHERE (Event.EventType IN ("Cloud.Server.DataVault.DataVaultDownload") OR Event.EventType IN ("Cloud.Server.DataVault.DataVaultViewSecret"))  AND Event.WhenOccurred < Datefunc("now") AND DataVault.ID = "{0}" ORDER BY WhenOccurred DESC LIMIT 1'	-f $this.ID)

        if ($lastquery -ne $null)
        {
            $this.lastRetrieved = $lastquery.whenOccurred
        }

        # if the ParentPath is blank (root folder)
        if ([System.String]::IsNullOrEmpty($this.ParentPath))
        {
            $this.ParentPath = "."
        }

        # if this is a File secret, fill in the relevant file parts
        if ($this.Type -eq "File")
        {
            $this.SecretFileName = $secretinfo.SecretFileName
            $this.SecretFileSize = $secretinfo.SecretFileSize
        }

        # getting the RowAces for this secret
        $this.RowAces = Get-PASRowAce -Type Secret -Uuid $this.ID

		<# disabling this for now
        # if Workflow is enabled
        if ($this.WorkflowEnabled)
        {
            # get the WorkflowApprovers for this secret
            $this.WorkflowApprovers = Get-PASSecretWorkflowApprovers -Uuid $this.ID
        }#>
    }# PASSecret ($secretinfo)

	getSecretActivity()
	{
		$this.SecretActivity.Clear()

		$activities = Query-RedRock -SQLQuery ("@/lib/server/get_activity_for_generic_secret.js(id:'{0}')" -f $this.ID)

		if (($activities | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
		{
			$this.SecretActivity.AddRange(@($activities)) | Out-Null
		}
	}# getSecretActivity()

	[System.Collections.ArrayList] reviewPermissions()
	{
		$ReviewedPermissions = New-Object System.Collections.ArrayList

		foreach ($rowace in $this.RowAces)
		{
			$ssperms = ConvertTo-SecretServerPermission -Type Self -Name $this.Name -RowAce $rowace

			$lastEvent = New-Object PSCustomObject

			$lastEvent | Add-Member -MemberType NoteProperty -Name whenOccurred -Value $null
			$lastEvent | Add-Member -MemberType NoteProperty -Name Message -Value $null

			$eventcheck = Query-RedRock -SQLQuery ("SELECT WhenOccurred,EventMessage AS Message FROM Event WHERE DataVaultItemID = '{0}' AND Event.WhenOccurred > Datefunc('now', -500)" -f $this.ID)
			
			# if there are more than 0 events
			if (($eventcheck | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
			{
				# set lastEvent to the most recent one
				$lastEvent = $eventcheck | Sort-Object whenOccurred -Descending | Select-Object -First 1
			}

			$obj = New-Object PSCustomObject

			$obj | Add-Member -MemberType NoteProperty -Name Type -Value $this.Type
			$obj | Add-Member -MemberType NoteProperty -Name Name -Value $this.Name
			$obj | Add-Member -MemberType NoteProperty -Name ParentPath -Value $this.ParentPath
			$obj | Add-Member -MemberType NoteProperty -Name Description -Value $this.Description
			$obj | Add-Member -MemberType NoteProperty -Name whenCreated -Value $this.whenCreated
			$obj | Add-Member -MemberType NoteProperty -Name lastRetrieved -Value $this.lastRetrieved
			$obj | Add-Member -MemberType NoteProperty -Name FileName -Value $this.SecretFileName
			$obj | Add-Member -MemberType NoteProperty -Name PrincipalType -Value $rowace.PrincipalType
			$obj | Add-Member -MemberType NoteProperty -Name PrincipalName -Value $rowace.PrincipalName
			$obj | Add-Member -MemberType NoteProperty -Name isInherited -Value $rowace.isInherited
			$obj | Add-Member -MemberType NoteProperty -Name InheritedFrom -Value $rowace.InheritedFrom
			$obj | Add-Member -MemberType NoteProperty -Name PASPermissions -Value $rowace.PASPermission.GrantString
			$obj | Add-Member -MemberType NoteProperty -Name SSPermissions -Value $ssperms.Permissions
			$obj | Add-Member -MemberType NoteProperty -Name LastEventTime -Value $lastEvent.whenOccurred
			$obj | Add-Member -MemberType NoteProperty -Name LastEventMessage -Value $lastEvent.Message
			$obj | Add-Member -MemberType NoteProperty -Name ID -Value $this.ID
			
			$ReviewedPermissions.Add($obj) | Out-Null
		}# foreach ($rowace in $this.PermissionRowAces)
		return $ReviewedPermissions
	}# [System.Collections.ArrayList] reviewPermissions()

	# method to retrieve secret content
	[System.Boolean] RetrieveSecret()
	{
		if ($this.Type -eq "Text")
		{
			# if retrieve is successful
			if ($retrieve = Invoke-PASAPI -APICall ServerManage/RetrieveSecretContents -Body (@{ ID = $this.ID } | ConvertTo-Json))
			{   
				# set these checkout fields
				$this.SecretText = $retrieve.SecretText
			}# if ($retrieve = Invoke-PASAPI -APICall ServerManage/RetrieveSecretContents -Body (@{ ID = $this.ID } | ConvertTo-Json))
			else
			{
				return $false
			}
			return $true
		}# if ($this.Type -eq "Text")
		else # this is a file secret
		{
			# if retrieve is successful
			if ($retrieve = Invoke-PASAPI -APICall ServerManage/RequestSecretDownloadUrl -Body (@{ secretID = $this.ID } | ConvertTo-Json))
			{
				$this.SecretFilePath = $retrieve.Location
			}
			else
			{
				return $false
			}
			return $true
		}
		return $false
	}# [System.Boolean] RetrieveSecret()

	    # method to export secret content to files
		ExportSecret()
		{
			# if the directory doesn't exist and it is not the Root PAS directory
			if ((-Not (Test-Path -Path $this.ParentPath)) -and $this.ParentPath -ne ".")
			{
				# create directory
				New-Item -Path $this.ParentPath -ItemType Directory | Out-Null
			}
	
			Switch ($this.Type)
			{
				"Text" # Text secrets will be created as a .txt file
				{
					# if the File does not already exists
					if (-Not (Test-Path -Path ("{0}\{1}" -f $this.ParentPath, $this.Name)))
					{
						# create it
						$this.SecretText | Out-File -FilePath ("{0}\{1}.txt" -f $this.ParentPath, $this.Name)
					}
					
					break
				}# "Text" # Text secrets will be created as a .txt file
				"File" # File secrets will be created as their current file name
				{
					$filename      = $this.SecretFileName.Split(".")[0]
					$fileextension = $this.SecretFileName.Split(".")[1]
	
					# if the file already exists
					if ((Test-Path -Path ("{0}\{1}" -f $this.ParentPath, $this.SecretFileName)))
					{
						# append the filename 
						$fullfilename = ("{0}_{1}.{2}" -f $filename, (-join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object{[char]$_})).ToUpper(), $fileextension)
					}
					else
					{
						$fullfilename = $this.SecretFileName
					}
	
					# create the file
					Invoke-RestMethod -Method Get -Uri $this.SecretFilePath -OutFile ("{0}\{1}" -f $this.ParentPath, $fullfilename) @global:PASSessionInformation
					break
				}# "File" # File secrets will be created as their current file name
			}# Switch ($this.Type)
		}# ExportSecret()	
}# class PASSecret