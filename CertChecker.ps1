#This function gets the TLS cert for a given hostname
#It can be useful when troubleshooting issues with failing HTTPS requests, etc.

function Get-CertInfo {
    param(
        [string]$Hostname,
        [int]$Port = 443
    )

    $request = [System.Net.Sockets.TcpClient]::new($Hostname, $Port)
    $stream = [System.Net.Security.SslStream]::new($request.GetStream())
    $stream.AuthenticateAsClient($Hostname)
    $effectiveDate = $stream.RemoteCertificate.GetEffectiveDateString() -as [datetime]
    $expirationDate = $stream.RemoteCertificate.GetExpirationDateString() -as [datetime]
    $Cert = $Stream.RemoteCertificate
    $Object += [pscustomobject] @{
        Hostname       = $stream.TargetHostName
        Thumbprint     = $Cert.Thumbprint
        Start          = [string]$effectiveDate
        End            = [string]$expirationDate
        Issuer         = $Cert.Issuer
        Subject        = $cert.Subject
        SubjectName   = $Cert.SubjectName
        DnsNames      = $Cert.DnsNameList
    }

    Return $Object
}

$Result = Get-CertInfo -Hostname "google.com"
$Result | fl *


