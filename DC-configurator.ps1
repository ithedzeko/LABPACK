cd c:\labs
ls
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest –URI https://download.sysinternals.com/files/Sysmon.zip -OutFile “Sysmon.zip” 
Invoke-WebRequest –URI https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-7.7.1-windows-x86_64.zip -OutFile “WinLogBeat.zip” 
Invoke-WebRequest –URI https://github.com/olafhartong/sysmon-modular/archive/master.zip -OutFile “sysmon-modular.zip” 
Invoke-WebRequest –URI https://github.com/palantir/windows-event-forwarding/archive/master.zip -OutFile “palantir.zip”
Invoke-WebRequest –URI https://github.com/DefensiveOrigins/LABPACK/archive/master.zip -OutFile LabPack.zip
Expand-Archive .\Sysmon.zip 
Expand-Archive .\sysmon-modular.zip 
Expand-Archive .\palantir.zip 
Expand-Archive .\WinLogBeat.zip 
Expand-Archive .\LabPack.zip 
Expand-Archive .\labs.zip
Set-ExecutionPolicy Bypass -Force -Confirm:$false
cd C:\labs\sysmon-modular\sysmon-modular-master
Import-Module .\Merge-SysmonXml.ps1 
Merge-AllSysmonXml -Path ( Get-ChildItem '[0-9]*\*.xml') -AsString | Out-File sysmonconfig.xml
Get-Content ".\sysmonconfig.xml " | select -First 10
cp C:\LABS\sysmon-modular\sysmon-modular-master\sysmonconfig.xml c:\labs\sysmon\sysmonconfig.xml
ls c:\labs\sysmon\
cd \\dc01\labs\sysmon\
./sysmon64.exe -accepteula -i sysmonconfig.xml
Get-WinEvent -LogName Microsoft-Windows-Sysmon/Operational
Import-GPO -Path "\\dc01\LABS\LabPack\LABPACK-master\Lab-GPOs\Enhanced-WS-Auditing\" -BackupGpoName "WS-Enhanced-Auditing" -CreateIfNeeded -TargetName "WS-Enhanced-Auditing" -Server DC01
Import-GPO -Path "\\dc01\LABS\LabPack\LABPACK-master\Lab-GPOs\Enhanced-DC-Auditing\" -BackupGpoName "DC-Enhanced-Auditing" -CreateIfNeeded -TargetName "DC-Enhanced-Auditing" -Server DC01
Import-GPO -Path "\\dc01\LABS\LabPack\LABPACK-master\Lab-GPOs\Enable WinRM and Firewall Rule" -BackupGpoName "Enable WinRM and Firewall Rule" -CreateIfNeeded -TargetName "WinRM-And-Firewall-Rules" -Server DC01
New-GPLink -Name "WS-Enhanced-Auditing" -Target "dc=labs,dc=local" -LinkEnabled Yes
New-GPLink -Name "DC-Enhanced-Auditing" -Target "ou=Domain Controllers,dc=labs,dc=local" -LinkEnabled Yes
New-GPLink -Name "WinRM-And-Firewall-Rules” -Target "dc=labs,dc=local" -LinkEnabled Yes
Get-GPOReport -Name "WinRM-And-Firewall-Rules" -ReportType HTML -Path "c:\Labs\GPOReport-WinRM-And-FirewallRules.html"
Get-GPOReport -Name "WS-Enhanced-Auditing" -ReportType HTML -Path "c:\Labs\GPOReport- WS-Enhanced-Auditing.html" 
Get-GPOReport -Name "DC-Enhanced-Auditing" -ReportType HTML -Path "c:\Labs\GPOReport- DC-Enhanced-Auditing.html"
& 'C:\Labs\GPOReport- DC-Enhanced-Auditing.html'
& 'C:\Labs\GPOReport- WS-Enhanced-Auditing.html'
& 'C:\Labs\GPOReport-WinRM-And-FirewallRules.html'
Import-GPO -Path “\\dc01\LABS\LabPack\LABPACK-master\Lab-GPOs\Windows Event Forwarding” -BackupGpoName "Windows Event Forwarding” -CreateIfNeeded -TargetName "Windows Event Forwarding" -Server DC01
Get-GPRegistryValue -Name "Windows Event Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager
Set-GPRegistryValue -Name "Windows Event Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager -ValueName "1" -Type String -Value "Server=http://dc01.labs.local:5985/wsman/SubscriptionManager/WEC,Refresh=60"
Get-GPRegistryValue -Name "Windows Event Forwarding" -Key HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager
New-GPLink -Name "Windows Event Forwarding” -Target "dc=labs,dc=local" -LinkEnabled Yes
Get-GPOReport -Name "Windows Event Forwarding" -ReportType HTML -Path "c:\Labs\GPOReport-Windows-Event-Forwarding.html" & "c:\Labs\GPOReport-Windows-Event-Forwarding.html"
wecutil qc -Force -Confirm:$false
net stop wecsvc
wevtutil um C:\windows\system32\CustomEventChannels.man
ls c:\LABS\LabPack\LABPACK-master\Lab-WEF-Palantir\windows-event-channels\
cp C:\LABS\LabPack\LABPACK-master\Lab-WEF-Palantir\windows-event-channels\CustomEventChannels.* C:\windows\System32\
ls C:\windows\System32\CustomEventChannels.*
wevtutil im C:\windows\system32\CustomEventChannels.man
net start wecsvc
Get-WinEvent -ListLog WEC*
cd C:\LABS\LabPack\LABPACK-master\Lab-WEF-Palantir\wef-subscriptions
ls
foreach ($file in (Get-ChildItem *.xml)) {wecutil cs $file}
Wevtutil gl WEC3-PRINT
foreach ($subscription in (wevtutil el | select-string -pattern "WEC")) {wevtutil sl $subscription /ms:4194304}
Wevtutil gl WEC3-PRINT
gpupdate /force
mv C:\labs\WinLogBeat\winlogbeat-7.7.1-windows-x86_64\winlogbeat.yml C:\labs\WinLogBeat\winlogbeat-7.7.1-windows-x86_64\winlogbeat.yml.old
cp C:\labs\LabPack\LABPACK-master\Lab-WinLogBeat\winlogbeat.yml C:\labs\WinLogBeat\winlogbeat-7.7.1-windows-x86_64\winlogbeat.yml
ls c:\labs\WinLogBeat\winlogbeat-7.7.1-windows-x86_64\
cd c:\labs\WinLogBeat\winlogbeat-7.7.1-windows-x86_64\
powershell -Exec bypass -File .\install-service-winlogbeat.ps1
Set-Service -Name "winlogbeat" -StartupType automatic
Start-Service -Name "winlogbeat"
Get-Service winlogbeat
cd c:\labs\WinLogBeat\winlogbeat-7.7.1-windows-x86_64\
.\winlogbeat.exe test config -c .\winlogbeat.yml -e
Restart-Computer