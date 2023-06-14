 
param (
    [switch]$ReDownload=$false,
    [switch]$Reinstall=$false,

    [switch]$Help=$false)

 

if ($Help) {
    Write-Output "make-portable.ps1 [-ReDownload] [-Reinstall] [-Help]"
    Write-Output "  -ReDownload: download files even if they already exist"
    Write-Output "  -Reinstall: reinstall OBS even if it is already installed"
 
    Write-Output "  -Help: show this help"
    exit
}
$obs_version = "29.1"
$obs_version_full = "29.1.2"
$obs_url =  "https://github.com/obsproject/obs-studio/releases/download/$obs_version_full/OBS-Studio-$obs_version-Full.zip"
$dyn_url =  "https://obsproject.com/forum/resources/dynamic-delay.1035/version/4615/download?file=89294"
$move_url = "https://obsproject.com/forum/resources/move-transition.913/version/4854/download?file=93246"
$ndi_url  = "https://github.com/obs-ndi/obs-ndi/releases/download/4.11.1/obs-ndi-4.11.1-windows-x64.zip"

$downloads = ".\downloads"
$bundled = ".\bundled"

$obs_zip  = "$downloads\OBS-Studio-$obs_version-Full.zip"
$dyn_zip  = "$downloads\dynamic-delay-0.1.4-windows.zip"
$move_zip = "$downloads\move-transition-2.9.0-windows.zip"
$ptzdelay_zip = "$bundled\ptz-move-delay.zip"
$ndi_zip =  "$downloads\obs-ndi-4.11.1-windows-x64.zip"    




 


function dowload_file (
        $url,
        $filename


     ) {

    if (Test-Path -Path $filename) {
        if ($ReDownload -eq $true) {
            Write-Output "removing $filename"
            Remove-Item -Path $filename -Force
        } else {
            Write-Output "$filename exists"
            return 
        }
        
    }
    
        Write-Output "Using Invoke-WebRequest for $url --> $filename"
        Invoke-WebRequest -Uri "$url" -OutFile "$filename"
        
}


$staging = ".\staging"  

$portable_flag = "$staging\portable_mode.txt"


New-Item -ItemType Directory -Force $downloads -ErrorAction SilentlyContinue

dowload_file "$obs_url"  "$obs_zip"
dowload_file "$dyn_url"  "$dyn_zip"
dowload_file "$move_url"  "$move_zip"

dowload_file "$ndi_url"  "$ndi_zip"

if ($Reinstall -eq $false -And (Test-Path -Path "$staging\bin\64bit\obs64.exe") ) {
    Write-Output "skipping extraction of $obs_zip"
} else {
    Remove-Item -Recurse -Force $staging  -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $staging 
    Expand-Archive -Path $obs_zip  -DestinationPath $staging
}


Expand-Archive -Path $dyn_zip  -DestinationPath $staging -Force
Expand-Archive -Path $move_zip -DestinationPath $staging -Force
Expand-Archive -Path $ptzdelay_zip -DestinationPath $staging -Force
Expand-Archive -Path $ndi_zip -DestinationPath $staging -Force

New-Item $portable_flag -ItemType File -Force -ErrorAction SilentlyContinue
Set-Content -Path $portable_flag -Value "this file is used to indicate that OBS is running in portable mode"

$ShortcutFile =  $staging + "\OBS Portable v$obs_version.lnk"
if (Test-Path -Path "$ShortcutFile" ) {
    Remove-Item -Path "$ShortcutFile" -Force
}



$staging_full = (Get-Item -Path $staging).FullName

$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = "$staging_full\bin\64bit\obs64.exe"
$Shortcut.WorkingDirectory  = "$staging_full\bin\64bit"
$Shortcut.Save()



function ZipFiles( $zipfilename, $sourcedir )
{
   Add-Type -Assembly System.IO.Compression.FileSystem
   $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir,
        $zipfilename, $compressionLevel, $false)
}


Remove-Item -Path .\obs-portable.zip -Force -ErrorAction   SilentlyContinue    
ZipFiles .\obs-portable.zip $staging
