# TEMPLATE_PCM

This is the template for the PowerShell Cloud Module.

## TEMPLATE_PCM (Cloud Grab)

To get started, copy the snippet below and paste it directly into a PowerShell (Run-As Administrator not needed) window and run it. This effectively invokes every script from this GitHub repo directly as a web request and dot sources it into your current PowerShell session.

One benefit of this method is when updates/fixes/enhancements are made to the repo, a new Cloud Grab will obtain those changes without needing to compile, deploy, and install a new PowerShell module. Effectively, this design makes this repo a "Cloud-based PowerShell Module".

```PowerShell
$TEMPLATE_PCM = ([ScriptBlock]::Create(((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/dnlrv/TEMPLATE_PCM/main/TEMPLATE_PCM.ps1').Content))); . $TEMPLATE_PCM
```

## TEMPLATE_PCM (Local Grab)

If you want to run all of this locally, download all the scripts in this repo to a local folder, and run the primary script with the following:

```PowerShell
. (([ScriptBlock]::Create((Get-Content .\TEMPLATE_PCM_local.ps1 -Raw))))
```

## How to use

After using the Cloud Grab or Local Grab, the cmdlets in the repo are available in the PowerShell session. The folder structure provided here is a suggestion, use whatever folder structure you wish for your project. Both the Cloud Grab and the Local Grab will simply search all folders recursively for any PowerShell scripts within them.

### Underscore (_) scripts

Any `.ps1` that starts with an underscore (_) will be ignored by the module processing. This would be useful in the event you need to temporarily disable a script without removing it.

In this template repo, the script `_Dont-FindMe.ps1` will not be processed by either the Cloud Grab or the Local Grab.

## How to update

As new scripts are added into whatever Folders you want, the next Cloud Grab should grab those changes.
