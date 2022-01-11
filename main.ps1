
param(
[String]
 $gatewayKey,

    [string]
    $userName,
	
	[string]
	$password 
)

./installsynapsepathway.ps1 $userName $password

./gatewayinstall.ps1 $gatewayKey


