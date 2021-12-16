param(
    [string]
    $userName,
	
	[string]
	$password 
)
# init log setting
$logLoc = "$env:SystemDrive\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\"
if (! (Test-Path($logLoc)))
{
    New-Item -path $logLoc -type directory -Force
}
$logPath = "$logLoc\tracelog.log"
"Start to excute installsynapsepathway.ps1. `n" | Out-File $logPath

function Now-Value()
{
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Throw-Error([string] $msg)
{
	try 
	{
		throw $msg
	} 
	catch 
	{
		$stack = $_.ScriptStackTrace
		Trace-Log "DMDTTP is failed: $msg`nStack:`n$stack"
	}

	throw $msg
}

function Trace-Log([string] $msg)
{
    $now = Now-Value
    try
    {
        "${now} $msg`n" | Out-File $logPath -Append
    }
    catch
    {
        #ignore any exception during trace
    }

}

function Run-Process([string] $process, [string] $arguments)
{
	Write-Verbose "Run-Process: $process $arguments"
	
	$errorFile = "$env:tmp\tmp$pid.err"
	$outFile = "$env:tmp\tmp$pid.out"
	"" | Out-File $outFile
	"" | Out-File $errorFile	

	$errVariable = ""

	if ([string]::IsNullOrEmpty($arguments))
	{
		$proc = Start-Process -FilePath $process -Wait -Passthru -NoNewWindow `
			-RedirectStandardError $errorFile -RedirectStandardOutput $outFile -ErrorVariable errVariable
	}
	else
	{
		$proc = Start-Process -FilePath $process -ArgumentList $arguments -Wait -Passthru -NoNewWindow `
			-RedirectStandardError $errorFile -RedirectStandardOutput $outFile -ErrorVariable errVariable
	}
	
	$errContent = [string] (Get-Content -Path $errorFile -Delimiter "!!!DoesNotExist!!!")
	$outContent = [string] (Get-Content -Path $outFile -Delimiter "!!!DoesNotExist!!!")

	Remove-Item $errorFile
	Remove-Item $outFile

	if($proc.ExitCode -ne 0 -or $errVariable -ne "")
	{		
		Throw-Error "Failed to run process: exitCode=$($proc.ExitCode), errVariable=$errVariable, errContent=$errContent, outContent=$outContent."
	}

	Trace-Log "Run-Process: ExitCode=$($proc.ExitCode), output=$outContent"

	if ([string]::IsNullOrEmpty($outContent))
	{
		return $outContent
	}

	return $outContent.Trim()
}

function Download-Gateway([string] $url, [string] $gwPath)
{
    try
    {
        $ErrorActionPreference = "Stop";
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($url, $gwPath)
        Trace-Log "Download synapse pathway successfully. Pathway loc: $gwPath"
    }
    catch
    {
        Trace-Log "Fail to download pathway msi"
        Trace-Log $_.Exception.ToString()
        throw
    }
}

function Download-netruntime([string] $neturi, [string] $netruntimepath)
{
    try
    {
        $ErrorActionPreference = "Stop";
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($neturi, $netruntimepath)
        Trace-Log "Downloaded net runtime successfully. Runtime loc: $netruntimepath"
    }
    catch
    {
        Trace-Log "Fail to download runtime desktop"
        Trace-Log $_.Exception.ToString()
        throw
    }
}

function Install-Gateway([string] $gwPath)
{
	if ([string]::IsNullOrEmpty($gwPath))
    {
		Throw-Error "Pathway path is not specified"
    }

	if (!(Test-Path -Path $gwPath))
	{
		Throw-Error "Invalid gateway path: $gwPath"
	}
	
	Trace-Log "Start Gateway installation"
	Run-Process "msiexec.exe" "/i AzureSynapsePathway.msi INSTALLTYPE=AzureTemplate /quiet /norestart"		
	
	Start-Sleep -Seconds 30	

	Trace-Log "Installation of gateway is successful"
}

function Install-Runtime([string] $netruntimepath)
{
	if ([string]::IsNullOrEmpty($netruntimepath))
    {
		Throw-Error "Runtime path is not specified"
    }

	if (!(Test-Path -Path $gwPath))
	{
		Throw-Error "Invalid runtime path: $netruntimepath"
	}
	
	Trace-Log "Start Gateway installation"
	Start-Process $netruntimepath -ArgumentList "/q" -Wait
	
	
	Start-Sleep -Seconds 30	

	Trace-Log "Installation of runtime is successful"
}


function Get-RegistryProperty([string] $keyPath, [string] $property)
{
	Trace-Log "Get-RegistryProperty: Get $property from $keyPath"
	if (! (Test-Path $keyPath))
	{
		Trace-Log "Get-RegistryProperty: $keyPath does not exist"
	}

	$keyReg = Get-Item $keyPath
	if (! ($keyReg.Property -contains $property))
	{
		Trace-Log "Get-RegistryProperty: $property does not exist"
		return ""
	}

	return $keyReg.GetValue($property)
}

function Get-InstalledFilePath()
{
	$filePath = Get-RegistryProperty "hklm:\Software\Microsoft\DataTransfer\DataManagementGateway\ConfigurationManager" "DiacmdPath"
	if ([string]::IsNullOrEmpty($filePath))
	{
		Throw-Error "Get-InstalledFilePath: Cannot find installed File Path"
	}
    Trace-Log "Gateway installation file: $filePath"

	return $filePath
}

# addeddatabaseinstall
./adddatabase.ps1 $username $password


Trace-Log "Log file: $logLoc"
$neturi = "https://download.visualstudio.microsoft.com/download/pr/5303da13-69f7-407a-955a-788ec4ee269c/dc803f35ea6e4d831c849586a842b912/dotnet-sdk-5.0.403-win-x64.exe"
$uri = "https://download.microsoft.com/download/a/0/a/a0a5ea88-ea47-4897-bb68-3e9483673523/AzureSynapsePathway.msi"
Trace-Log "Pathway download fw link: $uri"
$netruntimepath = "$PWD\dotnet-sdk-5.0.403-win-x64.exe"
$gwPath= "$PWD\AzureSynapsePathway.msi"
Trace-Log "Pathway download location: $gwPath"
$sqlserver = "localhost"
$dname = "sampledatabase"


Download-Gateway $uri $gwPath
Download-netruntime $neturi $netruntimepath
Install-Runtime $netruntimepath
Install-Gateway $gwPath



# Generateddl
./exportddl.ps1 $username $password "localhost" "sampledatabase"

# Convert  DDL using Pathway - 
./converttablesddl.ps1


