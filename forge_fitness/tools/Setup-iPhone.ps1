param([string]$ComputerIP)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskCerts=Join-Path $taskRoot 'server\certs'
New-Item -ItemType Directory -Path $taskCerts -Force | Out-Null
$taskOpenSSL=(Get-Command openssl -ErrorAction SilentlyContinue).Source
if(-not $taskOpenSSL){$taskOpenSSL='C:\Program Files\Git\usr\bin\openssl.exe'}
if(-not(Test-Path -LiteralPath $taskOpenSSL)){throw 'OpenSSL is needed. Install Git for Windows, then run this again.'}
$taskIPs=@('127.0.0.1')
if($ComputerIP){$taskIPs+=$ComputerIP}
else{
  $taskIPs+=Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -and $_.AddressState -eq 'Preferred'} | Select-Object -ExpandProperty IPAddress
}
$taskIPs=@($taskIPs|Select-Object -Unique)
foreach($taskIP in $taskIPs){$taskParsed=$null;if(-not[System.Net.IPAddress]::TryParse($taskIP,[ref]$taskParsed)){throw 'Invalid computer IP address'}}
$taskCAKey=Join-Path $taskCerts 'ca-key.pem'
$taskCA=Join-Path $taskCerts 'ca.pem'
if(-not(Test-Path -LiteralPath $taskCAKey)){
  & $taskOpenSSL req -x509 -newkey rsa:2048 -nodes -keyout $taskCAKey -out $taskCA -sha256 -days 825 -subj '/CN=FORGE Local Development CA' -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' -addext 'keyUsage=critical,keyCertSign,cRLSign' 2>$null
  if($LASTEXITCODE -ne 0){throw 'Could not generate the local certificate authority'}
}
$taskKey=Join-Path $taskCerts 'server-key.pem'
$taskCSR=Join-Path $taskCerts 'server.csr'
$taskServerCert=Join-Path $taskCerts 'server.pem'
& $taskOpenSSL req -new -newkey rsa:2048 -nodes -keyout $taskKey -out $taskCSR -subj '/CN=FORGE Local App' 2>$null
if($LASTEXITCODE -ne 0){throw 'Could not generate server key'}
$taskSAN='DNS:localhost,'+(($taskIPs|ForEach-Object {'IP:'+$_}) -join ',')
$taskExtensions=@('basicConstraints=critical,CA:FALSE','keyUsage=critical,digitalSignature,keyEncipherment','extendedKeyUsage=serverAuth',('subjectAltName='+$taskSAN))
$taskExtensionPath=Join-Path $taskCerts 'server.ext'
Set-Content -LiteralPath $taskExtensionPath -Value $taskExtensions -Encoding ascii
& $taskOpenSSL x509 -req -in $taskCSR -CA $taskCA -CAkey $taskCAKey -CAcreateserial -out $taskServerCert -days 365 -sha256 -extfile $taskExtensionPath 2>$null
if($LASTEXITCODE -ne 0){throw 'Could not sign the server certificate'}
& $taskOpenSSL x509 -in $taskCA -outform DER -out (Join-Path $taskCerts 'forge-local-ca.cer')
if($LASTEXITCODE -ne 0){throw 'Could not export certificate'}
Write-Host 'Local HTTPS files are ready. No system trust settings were changed.'
Write-Host 'Restart Start-Forge.cmd, then open this on your iPhone in Safari:'
foreach($taskIP in $taskIPs){if($taskIP -ne '127.0.0.1'){Write-Host ('http://'+$taskIP+':8787/iphone')}}
Write-Host 'Keep server/certs private. Only the public .cer certificate is served to your phone.'


