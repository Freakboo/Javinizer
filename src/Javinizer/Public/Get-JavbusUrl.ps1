function Get-JavbusUrl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]$Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateSet('ja', 'en', 'zh')]
        [String]$Language
    )

    process {
        $searchUrl = "https://www.javbus.com/search/$Id&type=0&parent=uc"

        try {
            Write-JVLog -Level Debug -Message "[$Id] [$($MyInvocation.MyCommand.Name)] Performing [GET] on URL [$searchUrl]"
            $webRequest = Invoke-RestMethod -Uri $searchUrl -Method Get -Verbose:$false
        } catch {
            try {
                $searchUrl = "https://www.javbus.com/uncensored/search/$Id&type=0&parent=uc"
                Write-JVLog -Level Debug -Message "[$Id] [$($MyInvocation.MyCommand.Name)] Performing [GET] on URL [$searchUrl]"
                $webRequest = Invoke-RestMethod -Uri $searchUrl -Method Get -Verbose:$false
            } catch {
                try {
                    $searchUrl = "https://www.javbus.org/search/$Id&type=0&parent=uc"
                    Write-JVLog -Level Debug -Message "[$Id] [$($MyInvocation.MyCommand.Name)] Performing [GET] on URL [$searchUrl]"
                    $webRequest = Invoke-RestMethod -Uri $searchUrl -Method Get -Verbose:$false
                } catch {
                    Write-JVLog -Level Warning -Message "[$Id] not matched on JavBus"
                    return
                }
            }
        }

        $Tries = 5
        # Get the page search results
        try {
            $searchResults = (($webRequest | ForEach-Object { $_ -split '\n' } | Select-String '<a class="movie-box" href="(.*)">').Matches) | ForEach-Object { $_.Groups[1].Value }
        } catch {
            return
        }
        $numResults = $searchResults.Count

        if ($Tries -gt $numResults) {
            $Tries = $numResults
        }

        if ($numResults -ge 1) {
            Write-JVLog -Level Debug -Message "[$Id] [$($MyInvocation.MyCommand.Name)] Searching [$Tries] of [$numResults] results for [$Id]"

            $count = 1
            foreach ($result in $searchResults) {
                try {
                    Write-JVLog -Level Debug -Message "[$Id] [$($MyInvocation.MyCommand.Name)] Performing [GET] on URL [$result]"
                    $webRequest = Invoke-RestMethod -Uri $result -Method Get -Verbose:$false
                } catch {
                    Write-JVLog -Level Error -Message "[$Id] [$($MyInvocation.MyCommand.Name)] Error occurred on [GET] on URL [$result]: $PSItem"
                }
                $resultId = Get-JavbusId -WebRequest $webRequest
                if ($resultId -eq $Id) {
                    if ($Language -eq 'zh') {
                        $directUrl = "https://" + ($result -split '/')[-2] + "/" + ($result -split '/')[-1]
                    } else {
                        $directUrl = "https://" + ($result -split '/')[-2] + "/$Language/" + ($result -split '/')[-1]
                    }
                    break
                }

                Write-JVLog -Level Debug -Message "Result [$count] is [$resultId]"

                if ($count -eq $Tries) {
                    break
                }

                $count++
            }

            if ($null -eq $directUrl) {
                Write-JVLog -Level Warning -Message "[$Id] not matched on JavBus"
                return
            } else {
                $urlObject = [PSCustomObject]@{
                    Url      = $directUrl
                    Language = $Language
                }

                Write-Output $urlObject
            }
        }
    }
}
