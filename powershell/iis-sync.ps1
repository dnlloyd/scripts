Get-Date
$Stopwatch = [System.Diagnostics.Stopwatch]::New()
$Stopwatch.Start()

# Disable WinRM
Write-Output "Disabling WinRM"
Disable-PSRemoting -force
Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse
Stop-Service -Name WinRM -PassThru

# Disbale the firewall
Write-Output "Disabling the firewall"
netsh advfirewall set allprofiles state off

# Install AWS Tools and dependencies
Write-Output "Installing AWS Tools and dependencies"
Install-PackageProvider -Name NuGet -Force
Install-Module -Name AWS.Tools.Installer -Force
Install-AWSToolsModule AWS.Tools.S3,AWS.Tools.EC2,AWS.Tools.AutoScaling -CleanUp -Force -AllowClobber

# Copy web content from s3
Write-Output "Copying index.html to wwwroot"
Copy-S3Object -BucketName "iis_content" -Key index.html -LocalFolder "C:\inetpub\wwwroot"

Write-Output "Syncing files from s3"
aws s3 sync "s3://iis_content" "C:\inetpub\wwwroot"

# Restart IIS
Write-Output "Restarting IIS"
iisreset /restart

# Complete auto scaling lifecycle action
Write-Output "Completing ASG lifecycle action"
$InstanceID = Get-EC2InstanceMetadata -Category InstanceId
Complete-ASLifecycleAction -AutoScalingGroupName "iis-asg" -InstanceId $InstanceID -LifecycleActionResult CONTINUE -LifecycleHookName "iis-asg"

Write-Output "Init script complete"
Write-Output "Script duration: $($Stopwatch.Elapsed.TotalMinutes) minutes"
Get-Date
