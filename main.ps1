
param(
[String]
 $gatewayKey,

    [string]
    $userName,
	
	[string]
	$password 
)

./gatewayinstall.ps1 $gatewayKey


./installsynapsepathway.ps1 $userName $password



