 
param (
    [switch]$ReDownload=$false,
    [switch]$Reinstall=$false,
    [switch]$WebRequest=$false,
    [switch]$Help=$false)

 

if ($Help) {
    Write-Output "make-portable.ps1 [-ReDownload] [-Reinstall] [-Help]"
    Write-Output "  -ReDownload: download files even if they already exist"
    Write-Output "  -Reinstall: reinstall OBS even if it is already installed"
    Write-Output "  -WebRequest: use Invoke-WebRequest instead of BitsTransfer"
    Write-Output "  -Help: show this help"
    exit
}
$obs_version = "29.1"
$obs_version_full = "29.1.0"
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


function LoadModule ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
        return $true
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Verbose
            return $true
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m -Verbose
                return $true
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m not imported, not available and not in an online gallery, exiting."
                return $false
            }
        }
    }
}

 
$bt_available = ($WebRequest -eq $false) -and (  LoadModule "BitsTransfer" )
 



function dowload_file (
        $url,
        $filename,
        $shafilename=$false,
        $sha=$false
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
    
    if ($bt_available -eq $false) {
        Write-Output "BitsTransfer module not available, using Invoke-WebRequest for $url --> $filename"
        Invoke-WebRequest -Uri "$url" -OutFile "$filename"
        if (($shafilename -eq $false) -or ( $sha -eq $false)) {
            return 
        } else {
            set-content -Path $shafilename   -Value $sha 
        }
       
        return  
    }
    Write-Output "using BitsTransfer for $url --> $filename"
    Start-BitsTransfer -Source "$url" -Destination  "$filename"

    # not great that we do this before download completes, but meh.
    if (($shafilename -eq $false) -or ( $sha -eq $false)) {
        return 
    } else {
        set-content -Path $shafilename   -Value $sha 
    }
  
}

function  doneDownloading () {
    if ($bt_available -eq $false) {
        return
    }
    write-host "waiting for files to finish downloading..."
    Get-BitsTransfer | Complete-BitsTransfer
    write-host "done downloading"
}


$staging = ".\staging"  

$portable_flag = "$staging\portable_mode.txt"


New-Item -ItemType Directory -Force $downloads -ErrorAction SilentlyContinue

dowload_file "$obs_url"  "$obs_zip"
dowload_file "$dyn_url"  "$dyn_zip"
dowload_file "$move_url"  "$move_zip"

dowload_file "$ndi_url"  "$ndi_zip"

doneDownloading

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


Push-Location $staging
ZipFiles ..\obs-portable.zip .
Pop-Location
