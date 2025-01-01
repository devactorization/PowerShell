# Summary

This module contains wrapper functions that allow interaction with Systemd units/services via PowerShell cmdlets.

# Examples

Get all running services:
```
Get-Service
```

Get specific service:
```
Get-service -Name pulseaudio
```

List system services:
```
Get-service -System
```

