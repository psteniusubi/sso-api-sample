# 

Import-Module "oauth2" 
Import-Module "sso-api-v2" 

$serverUri = "https://sso.example.com:8443"

New-OAuthClientConfig -Name "sso-api-sample.json" | New-SSOLogon -Uri $serverUri -Username "system" -ErrorAction Stop

# get password.1
$method = Get-SSOObject -Type "method" "password.1" -ErrorAction Stop

# create site
$site = Set-SSOObject -Type "site" "IAM-871" 
# remove everything from site
$site | Get-SSOLink -LinkName "one" | Select-SSOLink -Link | Remove-SSOObject

# enable password.1
$site | Set-SSOLink -Link $method | Out-Null

# create application1
$application1 = $site | Add-SSOObject -ChildType "application" -ChildName "application1" -Enabled 
$application1 | Set-SSOLink -Link $method -Enabled | Out-Null

# create application2
$application2 = $site | Set-SSOChild -ChildType "application" "application2" -Enabled
$application2 | Set-SSOLink -Link $method -Enabled | Out-Null

# create application3
$application3 = $site | Set-SSOChild -ChildType "application" "application3" -Enabled
$application3 | Set-SSOLink -Link $method -Enabled | Out-Null

# create user1
$user1 = $site | Set-SSOChild -ChildType "user" "user1" -Attributes @{"uid"="user1";"mail"="user1@example.com"} -Enabled 
$user1 | Set-SSOLink -Link $method -Enabled | Out-Null

# create user2
$user2 = $site | Set-SSOChild -ChildType "user" "user2" -Attributes @{"uid"="user2";"mail"="user2@example.com"} -Enabled 
$user2 | Set-SSOLink -Link $method -Enabled | Out-Null

# create group
$group = $site | Set-SSOChild -ChildType "group" "group1" -Enabled 
$group | Set-SSOLink -LinkName "member" -Link $user1 | Out-Null
$group | Set-SSOLink -LinkName "member" -Link $user2 | Out-Null
$group | Set-SSOLink -LinkName "accessTo" -Link $application1 | Out-Null
$group | Set-SSOLink -LinkName "accessTo" -Link $application2 | Out-Null
$group | Set-SSOLink -LinkName "accessTo" -Link $application3 | Out-Null

# create policy
$policy = $site | Set-SSOChild -ChildType "policy" "policy1"
$policy | Add-SSOLink -Link $group -Attributes @{
"attributename"="mail"
"attributevalue"="`${nameID.nameFormat('email').value(user.mail)}"
} | Out-Null
$policy | Set-SSOLink -Link $application1 | Out-Null

# create refresh token policy
$refreshTokenPolicy = $site | Set-SSOChild -ChildType "refreshTokenPolicy" "refreshTokenPolicy1"
$refreshTokenPolicy | Set-SSOLink -Link $application1 | Out-Null
$refreshTokenPolicy | Set-SSOLink -Link $application2 | Out-Null

# create user mapping policy
$outboundMappingPolicy1 = $site | Set-SSOChild -ChildType "outboundMappingPolicy" "outboundMappingPolicy1" -Attributes @{
"nameIDFormat"="urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
}
$outboundMappingPolicy1 | Add-SSOLink -Link $user1 -Attributes @{"username"="mapped-user1"} | Out-Null
$outboundMappingPolicy1 | Set-SSOLink -Link $application2 | Out-Null

# create persistent id policy
$outboundMappingPolicy2 = $site | Set-SSOChild -ChildType "outboundMappingPolicy" "outboundMappingPolicy2" -Attributes @{
"nameIDFormat"="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
"nameValue"="PersistentIDFormat UUID"
}
$outboundMappingPolicy2 | Set-SSOLink -Link $application3 | Out-Null
