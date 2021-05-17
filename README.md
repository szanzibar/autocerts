# Auto-Renew Certs Through LetsEncrypt

#### This guide will help you get valid certificates for your domain from let's encrypt, and automatically renew before they expire.
#### I'm including instructions to use this with [stunnel](https://www.stunnel.org) which I use to access [BlueIris](https://blueirissoftware.com) over https, but you could use this guide to set up certs for pretty much anything. 

### Requirements
- Windows
- A domain name. If you need to buy one now, I recommend [namecheap](https://www.namecheap.com). The one caveat is you need to spend 50 bucks to get access to the API, which you need for this guide. You could do that by buying your domain for 5+ years in advance.
    - A different registrar may be better, just try to find one with API access
    - Google domains does not have an API
    - Without API access, you have to manually prove you own the domain to get a certificate. This is doable, just a bit inconvenient.

### Instructions

#### Get your first cert

Open an administrative Powershell terminal (`Win+X, a`)

We'll set the powershell [execution policy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.1), Scripts originating from a different computer will need to have a valid signature, and local scripts can run without a signature.
```powershell
Set-ExecutionPolicy RemoteSigned -Force
```

Install the Posh-ACME module that will handle retrieving certs from lets encrypt.
- https://github.com/rmbolger/Posh-ACME
- https://github.com/rmbolger/Posh-ACME/blob/main/Tutorial.md 

```powershell
Install-Module -Name Posh-ACME -Scope AllUsers -Force
```
If it asks you to install the NuGet provider, select `Y`.

Import the Posh-ACME module into our current powershell session so we can start using it
```powershell
Import-Module Posh-ACME
```

We need a plugin to connect to our registrar, so we can verify we own our domain

Run this command to list all the available registrar plugins

```powershell
Get-PAPlugin
```

If you are not using namecheap, open up the guide for your plugin for your registrar
```powershell
Get-PAPlugin NameOfPluginFromPreviousStep -Guide
```

Moving forward with namecheap, we need to set up the namecheap API
Here's the documentation. The important sections for us are `Enabling API Access` and `Whitelisting IP`:
https://www.namecheap.com/support/api/intro/

Copy your namecheap API key, then run this command which will prompt for and securely save your API key
```powershell
$ncKey = Read-Host "API Key" -AsSecureString
```

Run this command, replacing myusername with your actual namecheap username
```powershell
$ncParams = @{NCUsername='myusername';NCApiKey=$ncKey}
```

We should be ready to grab certificates. We'll request 2 certs. One cert for our base domain, `mydomain.com`, and one wildcard cert `*.mydomain.com`. 
We want the wildcard cert so that all of our self hosted services like ps5StockScraper.mydomain.com and plex.mydomain.com can all use the same cert. 

Make sure to replace `mydomain` with your actual domain, and `myemail@gmail.com` with your actual email. (You'll get email alerts if your cert is about to expire)
```powershell
$cert = New-PACertificate '*.mydomain.com','mydomain.com' -AcceptTos -Contact 'myemail@gmail.com' -Install -Plugin Namecheap -PluginArgs $ncParams
```

Hopefully all went well, and the contents of your cert are now saved into the $cert variable.
Now we'll save the cert data in a way for stunnel to read it. I'll assume stunnel is installed to the default location

```powershell
Copy-Item $cert.KeyFile -Destination "C:\Program Files (x86)\stunnel\config\mydomain.com.pem" -Force
Get-Content -Path $cert.CertFile -Raw | Add-Content -Path  "C:\Program Files (x86)\stunnel\config\mydomain.com.pem" -Force
Copy-Item $cert.FullChainFile -Destination "C:\Program Files (x86)\stunnel\config\mydomain.com.cafile.pem" -Force
```

Now we edit the stunnel config. Open the stunnel GUI, then Configuration → Edit Configuration

The relevant part of my stunnel config, specifically, the relative path of `cert` and `CAFile`

```
; ***************************************** Example TLS server mode services

[blueiris]
accept = 8181
connect = 81
cert = mydomain.com.pem
CAFile = mydomain.com.cafile.pem
```

Save, then restart stunnel. (Use the following command if stunnel is running as a service)
```powershell
Restart-Service stunnel
```

Follow the BlueIris documentation to get it working with Stunnel, if you haven't done that already.

To make `mydomain.com` point to your blueiris/stunnel server, we need to update DNS. To do this with namecheap:
1. Go to a site like [this](https://www.whatismyip.com), and copy your external IP address.
1. Sign in to namecheap.com
1. On the dashboard, find your domain -> click the Manage button
1. Click the Advanced DNS tab
1. Under Host Records -> click Add New Record
    - Record type = A Record
    - Host = @
    - IP Address = paste your IP address
    - TTL can stay Automatic
    - Click the ✓ to save

Update your blueiris app or anywhere you access blueiris with your new domain and correct port
```
mydomain.com:8181
```

Hopefully all went well, and you can access Blueiris through https

***

#### Add a powershell script to automatically renew our certs, since they expire every 3 months.

Save the [Update-StunnelCerts.ps1](https://github.com/szanzibar/autocerts/blob/main/Update-StunnelCerts.ps1) script somewhere. I put mine at c:\users\me\Update-StunnelCerts.ps1

Open up Task scheduler, and Create a task. (Don't use Create Basic Task)

**General tab:**
Name it, select "Run whether user is logged on or not

**Triggers tab:**
New -> One time (now), Repeat task every: 12 hours, for a duration of Indefinitely, Ok

**Actions tab:**
New -> Program/script: `powershell.exe`
Add arguments: `-File "C:\Users\me\Update-StunnelCerts.ps1"`

Click ok

Click ok to save the task. It should prompt you for your password, so that it can run the task even if you are logged off

:tada:That should be it!:tada:
