function Set-JavMovie {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [object]$DataObject,
        [object]$Settings,
        [system.io.fileinfo]$Path,
        [system.io.fileinfo]$DestinationPath,
        [switch]$Force
    )

    begin {
        if ($PSVersionTable.PSVersion -like '7*') {
            $directoryMode = 'd----'
            $itemMode = '-a---'
        } else {
            $directoryMode = 'd-----'
            $itemMode = '-a----'
        }
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Function started"
        $Path = (Get-Item -LiteralPath $Path).FullName
        $DestinationPath = (Get-Item $DestinationPath).FullName
        $webClient = New-Object System.Net.WebClient
        $modulePath = (Get-Item $PSScriptroot).Parent
        $cropPath = Join-Path -Path $modulePath -ChildPath 'crop.py'
        $folderPath = Join-Path $DestinationPath -ChildPath $dataObject.FolderName
        $nfoPath = Join-Path -Path $folderPath -ChildPath ($dataObject.Id + '.nfo')
        $coverPath = Join-Path -Path $folderPath -ChildPath ('fanart.jpg')
        $posterPath = Join-Path -Path $folderPath -ChildPath ('poster.jpg')
        $trailerPath = Join-Path -Path $folderPath -ChildPath ($dataObject.Id + ' - trailer.mp4')
        $screenshotPath = Join-Path -Path $folderPath -ChildPath 'extrafanart'

        Write-Debug "[$($MyInvocation.MyCommand.Name)] Crop path: [$cropPath]"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Folder path: [$folderPath]"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Nfo path: [$nfoPath]"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Cover path: [$coverPath]"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Poster path: [$posterPath]"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Screenshot path: [$screenshotPath]"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Trailer path: [$trailerPath]"
    }

    process {
        $newFileName = $dataObject.FileName + $Path.Extension
        $dataObject = Test-RequiredMetadata -DataObject $DataObject -Settings $settings
        if ($null -ne $dataObject) {
            New-Item -ItemType Directory -Name $dataObject.FolderName -Path $DestinationPath -Force:$Force -ErrorAction SilentlyContinue | Out-Null
            Get-MetadataNfo -DataObject $dataObject -Settings $Settings | Out-File -LiteralPath $nfoPath -Force:$Force -ErrorAction SilentlyContinue
            Rename-Item -Path $Path -NewName $newFileName -PassThru -Force:$Force -ErrorAction Stop | Move-Item -Destination $folderPath -Force:$Force -ErrorAction Stop

            try {
                if ($Settings.Metadata.'download-thumb-img' -eq 'True') {
                    if ($null -ne $dataObject.CoverUrl) {
                        if ($Force.IsPresent) {
                            $webClient.DownloadFile(($dataObject.CoverUrl).ToString(), $coverPath)
                        } elseif ((-not (Test-Path -Path $coverPath))) {
                            $webClient.DownloadFile(($dataObject.CoverUrl).ToString(), $coverPath)
                        }

                        if ($Settings.Metadata.'download-poster-img' -eq 'True') {
                            # Double backslash to conform with Python path standards
                            $coverPath = $coverPath -replace '\\', '\\'
                            $posterPath = $posterPath -replace '\\', '\\'
                            if ($Force.IsPresent) {
                                if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
                                    python $cropPath $coverPath $posterPath
                                } elseif ([System.Environment]::OSVersion.Platform -eq 'Unix') {
                                    python $cropPath $coverPath $posterPath
                                }
                            } elseif ((-not (Test-Path -Path $posterPath))) {
                                if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
                                    python $cropPath $coverPath $posterPath
                                } elseif ([System.Environment]::OSVersion.Platform -eq 'Unix') {
                                    python $cropPath $coverPath $posterPath
                                }
                            }
                        }
                    }
                }
            } catch {
                Write-Warning "[$($MyInvocation.MyCommand.Name)] Error downloading cover/poster images"
            }

            try {
                if ($Settings.Metadata.'download-screenshot-img' -eq 'True') {
                    New-Item -ItemType Directory -Name 'extrafanart' -Path $folderPath -Force:$Force -ErrorAction SilentlyContinue | Out-Null
                    $index = 1
                    foreach ($screenshot in $dataObject.ScreenshotUrl) {
                        if ($Force.IsPresent) {
                            $webClient.DownloadFile($screenshot, (Join-Path -Path $screenshotPath -ChildPath "fanart$index.jpg"))
                        } elseif (-not (Test-Path -Path (Join-Path -Path $screenshotPath -ChildPath "fanart$index.jpg"))) {
                            $webClient.DownloadFile($screenshot, (Join-Path -Path $screenshotPath -ChildPath "fanart$index.jpg"))
                        }
                        $index++
                    }
                }
            } catch {
                Write-Warning "[$($MyInvocation.MyCommand.Name)] Error downloading screenshots"
            }

            try {
                if ($Settings.Metadata.'download-trailer-vid' -eq 'True') {
                    if ($Force.IsPresent) {
                        $webClient.DownloadFile(($dataObject.TrailerUrl).ToString(), $trailerPath)
                    } elseif (-not (Test-Path -Path $trailerPath)) {
                        $webClient.DownloadFile(($dataObject.TrailerUrl).ToString(), $trailerPath)
                    }
                }
            } catch {
                Write-Warning "[$($MyInvocation.MyCommand.Name)] Error downloading trailer video"
            }
        }
    }

    end {
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Function ended"
    }
}