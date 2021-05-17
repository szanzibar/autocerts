Import-Module Posh-ACME
$cert = Submit-Renewal

if ($cert) {
    Copy-Item $cert.KeyFile -Destination "C:\Program Files (x86)\stunnel\config\stevenvandijk.com.pem" -Force
    Get-Content -Path $cert.CertFile -Raw | Add-Content -Path  "C:\Program Files (x86)\stunnel\config\stevenvandijk.com.pem" -Force
    Copy-Item $cert.FullChainFile -Destination "C:\Program Files (x86)\stunnel\config\stevenvandijk.com.cafile.pem" -Force

    Restart-Service stunnel
}