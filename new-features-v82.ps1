# 

Import-Module "oauth2" 
Import-Module "sso-api-v2" 
Import-Module (Get-OAuthModulePath -ChildPath "HttpListener")

$serverUri = "https://sso.example.com:8443"

New-OAuthClientConfig -Name "sso-api-sample.json" | New-SSOLogon -Uri $serverUri -Username "system" -ErrorAction Stop

# cleanup
Remove-SSOObject -Type "method" "test.1"
Remove-SSOObject -Type "method" "test.2"
Remove-SSOObject -Type "method" "test.3"
Remove-SSOObject -Type "service" "Service1"
Remove-SSOObject -Type "service" "Service2"
Remove-SSOObject -Type "inboundPolicy" "inboundPolicy1"
Remove-SSOObject -Type "inboundMappingPolicy" "inboundMappingPolicy1"

# create methods test.1 - test.3
$method1 = Set-SSOObject -Type "method" "test.1" -Attributes @{"className"="ubilogin.method.provider.UbiloginAgentV0Method";"methodType"="Authentication Provider";"enabled"="true"}
$method2 = Set-SSOObject -Type "method" "test.2" -Attributes @{"className"="ubilogin.method.provider.saml2.AssertionConsumerMethod";"methodType"="SAML";"enabled"="true"}
$method3 = Set-SSOObject -Type "method" "test.3" -Attributes @{"className"="ubilogin.method.provider.openidconnect.OpenIDConnectMethod";"methodType"="OpenID Connect";"enabled"="true"}

# create directory Directory1
$directory1 = Set-SSOObject -Type "directory" "Directory1" -Attributes @{"className"="example.Directory1"}
$directory1 | Set-SSOLink -Link $method1 | Out-Null

# create service Service1, Service2
$service1 = Set-SSOObject -Type "service" "Service1" -Attributes @{
    "className"="com.ubisecure.ubilogin.restclient.impl.UbiloginRestClientFactory"
    "template"="http://demo.ubisecure.com/userid.aspx?userid=`${method.sub}"
    "outputParameter"="directory.login /user/userid"
}
$service2 = Set-SSOObject -Type "service" "Service1" -Attributes @{"className"="example.Service2"}

# inboundPolicy
$inboundPolicy1 = Set-SSOObject -Type "inboundPolicy" "inboundPolicy1"
$inboundPolicy1 | Get-SSOLink -LinkType "inboundPolicyItem" | Select-SSOLink -Link | Remove-SSOObject
$inboundPolicy1 | Set-SSOLink -Link $method1 | Out-Null
$inboundPolicy1 | Add-SSOObject -ChildType "inboundPolicyItem" -Attributes @{"attributename"="name1";"attributevalue"="value1"} | Out-Null

# inboundMappingPolicy 
$inboundMappingPolicy1 = Set-SSOObject -Type "inboundMappingPolicy" "inboundMappingPolicy1"
$inboundMappingPolicy1 | Get-SSOLink -LinkType "inboundDirectoryMapping" | Select-SSOLink -Link | Remove-SSOObject
$inboundMappingPolicy1 | Get-SSOLink -LinkType "inboundServiceMapping" | Select-SSOLink -Link | Remove-SSOObject
$inboundMappingPolicy1 | Set-SSOLink -Link $method1 | Out-Null
$inboundMappingPolicy1 | Add-SSOObject -ChildType "inboundDirectoryMapping" -Attributes @{"mappingURL"="ldap:///localhost" } | Out-Null
$inboundServiceMapping1 = $inboundMappingPolicy1 | Add-SSOObject -ChildType "inboundServiceMapping" 
$inboundServiceMapping1 | Set-SSOLink -Link $service1 | Out-Null
$inboundServiceMapping1 | Set-SSOLink -Link $directory1 | Out-Null

# authentication provider

$method1 | Set-SSOLink -LinkType "directory" "Ubilogin Directory" | Out-Null
$method1 | Set-SSOObject -Attributes @{"configuration"="agentURL https://uap.example.com/uapsso/login.ashx"} | Out-Null
$metadata = $method1 | Set-SSOAttribute "metadata" -Body "" 

# saml federation 

$method2 | Set-SSOLink -LinkType "directory" "Ubilogin Directory" | Out-Null
$method2 | Set-SSOObject -Attributes @{"configuration"="ForceAuthn true"} | Out-Null
$method2 | Remove-SSOAttribute "metadata" 
$metadata = Invoke-RestMethod -Uri "$serverUri/uas/saml2/metadata.xml" 
$metadata = $method2 | Set-SSOAttribute "metadata" -ContentType "application/xml" -Body $metadata 

$site = Set-SSOObject -Type "site" "SAML"
$site | Set-SSOLink -LinkType "method" "password.1" -Enabled | Out-Null
$app = $site | Set-SSOChild -ChildType "application" "federation" -Enabled -Attributes @{"configuration"="ForceAuthn true"}
$app | Set-SSOLink -LinkType "method" "password.1" -Enabled | Out-Null
$app | Set-SSOLink -LinkName "allowedTo" -LinkType "group" "System","Authenticated Users" | Out-Null

$metadata = Invoke-RestMethod -Uri "$serverUri/uas/saml2/names/ac/test.2/metadata.xml"
$metadata = $app | Set-SSOAttribute "metadata" -ContentType "application/xml" -Body $metadata 

# oidc federation 

$method3 | Set-SSOLink -LinkType "directory" "Ubilogin Directory" | Out-Null
$method3 | Set-SSOObject -Attributes @{"configuration"="ForceAuthn true"} | Out-Null
$method3 | Remove-SSOAttribute "metadata" 
$metadata = Get-OAuthMetadata -Authority "$serverUri/uas"
$metadata = $method3 | Set-SSOAttribute "metadata" -ContentType "application/json" -Body ($metadata | ConvertTo-Json) 

$jwks = Invoke-RestMethod -Uri $metadata.jwks_uri
$jwks = $method3 | Set-SSOAttribute "jwks" -ContentType "application/jwk-set+json" -Body ($jwks | ConvertTo-Json) 

$site = Set-SSOObject -Type "site" "OpenIDConnect"
$site | Set-SSOLink -LinkType "method" "password.1" -Enabled | Out-Null
$app = $site | Set-SSOChild -ChildType "application" "federation" -Enabled -Attributes @{"configuration"="ForceAuthn true"}
$app | Set-SSOLink -LinkType "method" "password.1" -Enabled | Out-Null
$app | Set-SSOLink -LinkName "allowedTo" -LinkType "group" "System","Authenticated Users" | Out-Null

$method3 | Remove-SSOAttribute "registration"
$request = $method3 | Get-SSOAttribute "registration"
$request = $app | Set-SSOAttribute "metadata" -ContentType "application/json" -Body ($request | ConvertTo-Json -Depth 8) 
$request = $method3 | Set-SSOAttribute "registration" -ContentType "application/json" -Body ($request | ConvertTo-Json -Depth 8) 

# test client

$site = Set-SSOObject -Type "site" "Test"
$site | Set-SSOLink -LinkType "method" "test.1" -Enabled | Out-Null
$site | Set-SSOLink -LinkType "method" "test.2" -Enabled | Out-Null
$site | Set-SSOLink -LinkType "method" "test.3" -Enabled | Out-Null

$app = $site | Set-SSOChild -ChildType "application" "client" -Enabled -Attributes @{"configuration"="ForceAuthn true"}
$app | Set-SSOLink -LinkType "method" "test.1" -Enabled | Out-Null
$app | Set-SSOLink -LinkType "method" "test.2" -Enabled | Out-Null
$app | Set-SSOLink -LinkType "method" "test.3" -Enabled | Out-Null

$group = $site | Set-SSOChild -ChildType "group" "users"
$group | Set-SSOLink -LinkType "method" "test.1" -Enabled | Out-Null
$group | Set-SSOLink -LinkType "method" "test.2" -Enabled | Out-Null
$group | Set-SSOLink -LinkType "method" "test.3" -Enabled | Out-Null
$group | Set-SSOLink -LinkName "accessTo" -Link $app | Out-Null

$test = $app | Set-SSOAttribute "metadata" -ContentType "application/json" -Body "{`"redirect_uris`":[`"http://localhost/redirect_uri`"]}" 
$test = New-OAuthClientConfig -Json ($test | ConvertTo-Json)

# use test client to send authentication request

Get-OAuthAuthorizationCode -Authority "$serverUri/uas" -Client $test -Verbose 

