param(
    [Parameter(Mandatory=$true)][string]$ChecksumFile,
    [Parameter(Mandatory=$true)][string]$Thumbprint,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
try { Add-Type -AssemblyName System.Security.Cryptography.Pkcs } catch { Add-Type -AssemblyName System.Security }
$ChecksumFile = (Resolve-Path -LiteralPath $ChecksumFile).Path
$Thumbprint = $Thumbprint.Replace(' ','').ToUpperInvariant()
if ($Thumbprint -notmatch '^[A-F0-9]{40}$') { throw 'Expected the signer certificate thumbprint' }
$detached = $ChecksumFile + '.p7s'
$data = [Security.Cryptography.Pkcs.ContentInfo]::new([IO.File]::ReadAllBytes($ChecksumFile))
$message = [Security.Cryptography.Pkcs.SignedCms]::new($data,$true)
if ($Verify) {
    $message.Decode([IO.File]::ReadAllBytes($detached))
    $message.CheckSignature($true)
    if ($message.SignerInfos.Count -ne 1 -or $message.SignerInfos[0].Certificate.Thumbprint -ne $Thumbprint) { throw 'Unexpected checksum signer' }
    Write-Output 'Release checksum signature verified'
} else {
    $certificate = Get-Item -LiteralPath ('Cert:/CurrentUser/My/'+$Thumbprint)
    if (!$certificate.HasPrivateKey) { throw 'Signing certificate needs a private key' }
    $signer = [Security.Cryptography.Pkcs.CmsSigner]::new($certificate)
    $signer.DigestAlgorithm = [Security.Cryptography.Oid]::new('2.16.840.1.101.3.4.2.1')
    $message.ComputeSignature($signer,$true)
    [IO.File]::WriteAllBytes($detached,$message.Encode())
    Write-Output ('Release checksum signature written to '+$detached)
}
