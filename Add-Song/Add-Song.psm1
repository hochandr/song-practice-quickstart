$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

#############
# Functions #
#############

function DownloadWithRetry([string] $url, [int] $retries = 3) {
    $waitTimeBase = $retries

    while ($retries -gt 0) {
        try {
            $response = Invoke-WebRequest $url -TimeoutSec 4
            
            if ($response.StatusCode -eq 200) { 
                return $response 
            }
            
            Write-Host "$($response.StatusCode) - $($response.StatusDescription): Failed to download '$url'"
            $retries--
        }
        catch {
            Write-Host $_
            $waitTime = [Math]::Pow(2, $waitTimeBase - $retries)
            $retries--
            Write-Host "Waiting $waitTime seconds before retrying. Retries left: $retries"
            Start-Sleep -Seconds $waitTime 
        }
    }
}

########
# Main #
########

<#
 .Synopsis
  Add a new song to your repertoire.

 .Description
  Fetches meta information about a song from the internet.
  Downloads audio and video files and creates a transcription file.
#>
function Add-Song {
    try {

        $repertoire_root = "${env:REPERTOIRE_ROOT}"
        Set-Location $repertoire_root

        #########################
        # Detect yt-dlp.exe #
        #########################

        [bool]$isYoutubedlInstalled = $false
        if (Get-Command 'yt-dlp' -errorAction SilentlyContinue) {
            if (Get-Command 'ffmpeg' -errorAction SilentlyContinue) {
                $isYoutubedlInstalled = $true
                Write-Host "yt-dlp is installed"
                yt-dlp --update
                yt-dlp --rm-cache-dir
            }
            else {
                Write-Warning "yt-dlp will not be used, because ffmpeg is not installed."
            }
        }
        else {
            Write-Warning "yt-dlp is not installed."
        }
    
        Write-Host @"

 Add a new song to your...
  _____                           _          _            
 |  __ \                         | |        (_)           
 | |__) | ___  _ __    ___  _ __ | |_  ___   _  _ __  ___ 
 |  _  / / _ \| '_ \  / _ \| '__|| __|/ _ \ | || '__|/ _ \
 | | \ \|  __/| |_) ||  __/| |   | |_| (_) || || |  |  __/
 |_|  \_\\___|| .__/  \___||_|    \__|\___/ |_||_|   \___|
              | |                                         
              |_|                                         

...in '$repertoire_root'

"@

        #############################
        # User input and validation #
        #############################

        [System.IO.FileInfo]$artist = Read-Host 'Artist'
        [System.IO.FileInfo]$song = Read-Host 'Song'
        [System.IO.FileInfo]$root = "${artist} - ${song}"

        # Remove common phrases from the query string for better search results
        $queryString = "${artist} ${song}"
        @( 
            "feat. ",
            "ft. ",
            "duet with ",
            "present ",
            "presents ",
            "introducing ",
            "vs. "
        ) | % { $queryString = $queryString.Replace("$_", "") }

        ###########################
        # Create folder structure #
        ###########################

        # Get the actual name of the created folder (Windows removes trailing dots for example)
        $rootDir = $(New-Item -ItemType "directory" ".\${root}").Name

        @( 
            "backing-tracks", 
            "covers", 
            "transcriptions", 
            "recordings\$(Get-Date -UFormat '%Y-%m-%d')", 
            "tabs", 
            "tutorials" 
        ) | % { New-Item -Path ".\${rootDir}" -Name "$_" -ItemType "directory" | Out-Null }        

        Push-Location ".\${rootDir}"

        ######################################
        # Copy DAW project template #
        ######################################

        $projectTemplate = Get-Item "${Env:DAW_PROJECT_TEMPLATE}"
        Copy-Item $projectTemplate.FullName -Destination ".\recordings\$(Get-Date -UFormat '%Y-%m-%d')\${root}$($projectTemplate.Extension)"

        Push-Location ".\transcriptions"

        ######################
        # Create lyrics file #
        ######################

        # Open browser and search for lyrics by artist and song name
        $query = [System.Web.HttpUtility]::UrlEncode("${queryString}")
        @( 
            "https://www.songtexte.com/search?q=${query}",
            "https://search.azlyrics.com/search.php?q=${query}"
            #"https://genius.com/search?q=${query}"
        ) | % { Start-Process "$_" }

        # Fetch lyrics from azlyrics
        $lyricsText = ""
        try {
            $response = DownloadWithRetry("https://www.azlyrics.com/lyrics/$($artist.ToLower() -replace '\s','')/$($song.toLower() -replace '\s','').html")
            $lyricsText = $response.ParsedHtml.getElementsByTagName('div') | 
            ? { [System.String]::IsNullOrWhiteSpace($_.className) -and [System.String]::IsNullOrWhiteSpace($_.id) -and ![System.String]::IsNullOrWhiteSpace($_.innerText) } | 
            Select-Object -First 1 | 
            % { $_.innerText.Trim() }
        }
        catch {
            Write-Host "Could not fetch lyrics from azlyrics."
        }

        # Create the TextBox
        $textBox = New-Object System.Windows.Forms.TextBox 
        $textBox.Location = New-Object System.Drawing.Size(20, 15) 
        $textBox.Size = New-Object System.Drawing.Size(550, 600)
        $textBox.AcceptsReturn = $true
        $textBox.AcceptsTab = $false
        $textBox.Multiline = $true
        $textBox.ScrollBars = 'Both'
        $textBox.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Regular)
        $textBox.Text = $lyricsText

        # Create the OK Button
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Location = New-Object System.Drawing.Size(495, 640)
        $okButton.Size = New-Object System.Drawing.Size(75, 25)
        $okButton.Text = "OK"
        $okButton.Add_Click( {
                If ([string]::IsNullOrWhiteSpace($textBox.Text)) {
                    $ErrorProvider.SetError($textBox, "Please enter some text!");
                }
                Else {
                    $form.Close()        
                }
            })

        $ErrorProvider = New-Object System.Windows.Forms.ErrorProvider
        $ErrorProvider.SetIconAlignment($textBox, "BottomRight")

        # Create the Form
        $form = New-Object System.Windows.Forms.Form 
        $form.Text = "Insert the lyrics"
        $form.Size = New-Object System.Drawing.Size(620, 720)
        $form.FormBorderStyle = 'FixedSingle'
        $form.AutoSizeMode = 'GrowAndShrink'
        $form.StartPosition = "CenterScreen"
        $form.MaximizeBox = $false
        $form.ShowInTaskbar = $true
        $form.AcceptButton = $okButton
 
        $form.Controls.Add($textBox)
        $form.Controls.Add($okButton)

        # Initialize and show the form.
        $form.Add_Shown( { $form.Activate() })
        $form.ShowDialog() > $null

        [string]$lyrics = $textBox.Text
        New-Item ".\lyrics.txt" -Value $lyrics | Out-Null

        ##################
        # Get audio file #
        ##################

        $title = 'Audio File'
        $message = 'Where is the audio file?'
        $optionLocal = New-Object System.Management.Automation.Host.ChoiceDescription '&Local', 'Choose a local audio file'
        $optionOnline = New-Object System.Management.Automation.Host.ChoiceDescription '&Online', 'Paste the URL of an online audio resource'
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($optionOnline, $optionLocal)
        $chosenOption = $optionLocal
        $success = $false

        do {
            if ($isYoutubedlInstalled) {
                $result = $host.ui.PromptForChoice($title, $message, $options, 0)
                $chosenOption = $options[$result]
            }

            if ($chosenOption -eq $optionLocal) {
                [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
                $FilePicker = New-Object System.Windows.Forms.OpenFileDialog
                $FilePicker.Title = 'Select audio file for the transcription'
                $FilePicker.InitialDirectory = "~\Downloads"
                $FilePicker.Filter = 'Audio Files (*.mp3, *.wav)|*.mp3;*.wav'
    
                do {
                    $result = $FilePicker.ShowDialog()
                } until ($result -eq "OK")
    
                $fileExt = ([System.IO.FileInfo] $FilePicker.FileName).Extension
                Copy-Item "$($FilePicker.FileName)" -Destination ".\${root}${fileExt}"
                Write-Host "Copied audio file '$($FilePicker.FileName)'"
                $success = $true
            }
            else {
                $query = [System.Web.HttpUtility]::UrlEncode("${queryString}")
                Start-Process "https://www.youtube.com/results?search_query=${query}"

                $url
                do {
                    $url = (Read-Host 'Enter URL') -as [System.URI]
                } until ($null -ne $url.AbsoluteURI -and $url.Scheme -match '[http|https]')

                $fileExt = '.mp3'
                yt-dlp -f 'bestaudio' --extract-audio --audio-format 'mp3' --audio-quality '0' -o "${root}.%(ext)s" ${url}

                if (Test-Path ".\${root}${fileExt}") {
                    Write-Host "Downloaded audio file from '${url}'."
                    $success = $true
                }
                else {
                    Write-Host "Could not download '${url}'."
                }           
            }
        } until ($success)

        #######################
        # Fetch song metadata #
        #######################

        Write-Host @"

Enter song metadata...
"@

        $query = [System.Web.HttpUtility]::UrlEncode("${queryString}")
        Start-Process "https://tunebat.com/Search?q=${query}"

        $defaultValue = '?'
        $prompt = Read-Host "Key [$($defaultValue)]"
        $key = ($defaultValue, $prompt)[[bool]$prompt]
        $prompt = Read-Host "BPM [$($defaultValue)]"
        $bpm = ($defaultValue, $prompt)[[bool]$prompt]

        # See https://www.pianoscales.org/major.html
        $majorAndMinorScales = @{
            @("C", "Am")                = @("C", "D", "E", "F", "G", "A", "B");
            @("C#", "Db", "A#m", "Bbm") = @("C#", "D#", "F", "F#", "G#", "A#", "C");
            @("D", "Bm")                = @("D", "E", "F#", "G", "A", "B", "C#");
            @("D#", "Eb", "Cm")         = @("D#", "F", "G", "G#", "A#", "C", "D");
            @("E", "C#m")               = @("E", "F#", "G#", "A", "B", "C#", "D#");
            @("F", "Dm")                = @("F", "G", "A", "Bb", "C", "D", "E");
            @("F#", "Gb", "D#m", "Ebm") = @("F#", "G#", "A#", "B", "C#", "D#", "F");
            @("G", "Em")                = @("G", "A", "B", "C", "D", "E", "F#")
            @("G#", "Ab", "Fm")         = @("G#", "A#", "C", "C#", "D#", "F", "G");
            @("A", "F#m")               = @("A", "B", "C#", "D", "E", "F#", "G#");
            @("A#", "Bb", "Gm")         = @("A#", "C", "D", "D#", "F", "G", "A");
            @("B", "Cb", "Abm", "G#m")  = @("B", "C#", "D#", "E", "F#", "G#", "A#");
        }

        $majorAndMinorScales.GetEnumerator() | % { 
            if ($_.key -contains $key) { 
                if ($key.Contains("m")) {
                    # Minor scale
                    $scale = $_.value[-2..4]
                }
                else {
                    $scale = $_.value                    
                }
            }
        }

        ########################################
        # Let Transcribe! generate a .xsc file #
        ########################################

        # See automation commands under 'Help > Transcribe! Help... > Various Topics > Commands for shortcuts and automation'

        @"
FileOpenNamed(".\${root}${fileExt}");
ViewFitWholeFileOn;
ViewTextZoneOn;
ViewNavBarShow;
ViewLoopLineOn;
FxClear;
FxEqSetFromText("1,0,0,-80:-80:-80:-80:-80:-80:-80:-80:-80:-80:-80:-80:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0");
FxEqBypass;
FxTuningBypass;
PlayLoopOff;
PlayScrollOn;
Speed70;
FxSpeedBypass;
FxMonoKaraoke;
FxMonoBypass;
FileSaveNamed("${root}.xsc");
QuitNoSaveNoVeto;
"@ | Out-File -FilePath ".\template.xscscpt" -Encoding UTF8

        Start-Process -FilePath ".\template.xscscpt" -WindowStyle Minimized -Wait
        Remove-Item ".\template.xscscpt"

        if (Test-Path ".\${root}.xsc") {
            $xsc = Get-Content -Path ".\${root}.xsc"

            $xsc = $xsc.Replace("TextZoneSplitterPos,0.250000", "TextZoneSplitterPos,0.500000")
            $xsc = $xsc.Replace("ViewSplitterPos,0.700000", "ViewSplitterPos,0.999900")   

            $newline = [System.Environment]::NewLine
            $delimiter = "${newline}${newline}"
            $lyricsParagraphs = $lyrics.Trim() -Split "$delimiter"

            $blocks = ""

            for ($i = 0; $i -lt $lyricsParagraphs.Length; $i++) {
                $blockEscaped = $lyricsParagraphs[$i].Replace(",", "\C").Replace("${newline}", "\n")
                $blocks += "T,$(($i + 1) * 600000),230,,White,,${blockEscaped},1${newline}"
            }
    
            # Add metadata and lyrics TextBlocks to the generated .xsc file

            $xsc += @"
SectionStart,TextBlocks
TextBlockFont,70,12,Consolas,@Adobe Fan Heiti Std B
Howmany,$($lyricsParagraphs.Length + 1)
T,0,5,285,White,0:00:00.000,Creation date: $(Get-Date -UFormat '%d-%m-%Y')\nTuning / Capo: Standard / -\nBPM: ${bpm}\nKey: ${key}\nScale: ${scale}\nNotes: ,0
${blocks}
SectionEnd,TextBlocks
"@

            # Add stem files to the generated .xsc file

            $transcriptionsDir = $Pwd.Path.Replace('\', '\\')
            $backingtracksDir = (Get-Item ..\backing-tracks).FullName.Replace('\', '\\')

            $xsc = $xsc.Replace(",Stem 1,", ",Original,")
            $xsc += @"
SectionStart,SeparateStemFiles
ShowStemSelector,1
StemFile,other.mp3,Other,${transcriptionsDir}\\stems\\other.mp3
StemFile,bass.mp3,Bass,${transcriptionsDir}\\stems\\bass.mp3
StemFile,drums.mp3,Drums,${transcriptionsDir}\\stems\\drums.mp3
StemFile,vocals.mp3,Vocals,${transcriptionsDir}\\stems\\vocals.mp3
StemFile,${root}_remove_other.mp3,Backing-Track,${backingtracksDir}\\${root}_remove_other.mp3
SectionEnd,SeparateStemFiles
"@

            Set-Content -Path ".\${root}.xsc" -Value $xsc
        }

        ################
        # Open browser #
        ################

        # Backing-tracks
        $query = [System.Web.HttpUtility]::UrlEncode("${queryString} backing track")
        Start-Process "https://www.google.com/search?q=${query}"

        # Covers
        $query = [System.Web.HttpUtility]::UrlEncode("${queryString} guitar cover")
        Start-Process "https://www.youtube.com/results?search_query=${query}"

        # Tabs
        $query = [System.Web.HttpUtility]::UrlEncode("${queryString} tab")
        Start-Process "https://www.google.com/search?q=${query}"

        $query = [System.Web.HttpUtility]::UrlEncode("${queryString}")
        Start-Process "https://www.ultimate-guitar.com/search.php?title=${query}&type=500"

        # Tutorials
        $query = [System.Web.HttpUtility]::UrlEncode("${queryString} guitar lesson")
        Start-Process "https://www.youtube.com/results?search_query=${query}"

        ###################################
        # Download videos and audio files #
        ###################################

        Pop-Location

        if ($isYoutubedlInstalled) {
            Write-Host @"

Download videos...
"@
    
            $urls = @()
            While ($url = (Read-Host "Enter URL (Leave blank to quit)")) {
                $urls += $url.trim()
            }
    
            $urls = $urls | Select-Object -Unique
            $joinedUrls = $urls -join [System.Environment]::NewLine
    
            if ($urls.Length -gt 0) {
                Write-Output $joinedUrls | yt-dlp --ignore-errors -f 'bestvideo[ext=mp4][height<=720]+bestaudio[ext=m4a]/best[ext=mp4][height<=720]/best' -o '%(title)s.%(ext)s' --batch-file -
            }

            Write-Host @"

Download audio files...
"@
    
            $urls = @()
            While ($url = (Read-Host "Enter URL (Leave blank to quit)")) {
                $urls += $url.trim()
            }
    
            $urls = $urls | Select-Object -Unique
            $joinedUrls = $urls -join [System.Environment]::NewLine
    
            if ($urls.Length -gt 0) {
                Write-Output $joinedUrls | yt-dlp --ignore-errors -f 'bestaudio' --extract-audio --audio-format 'mp3' --audio-quality '0' -o '%(title)s.%(ext)s' --batch-file -
            }
        }

        ##########################
        # Generate backing track #
        ##########################

        Generate-BackingTrack -AudioFile ".\transcriptions\${root}${fileExt}" -StemSource other -StemMode remove -OutputDir '.\backing-tracks'

        ###################
        # Success message #
        ###################

        Write-Host @"

Successfully added '${root}' to your repertoire!
"@

    }
    catch {
        Write-Host "An error occurred:"
        Write-Host $_.Exception
        Write-Host $_.ScriptStackTrace

        Set-Location "$PSScriptRoot"
        if (!([System.String]::IsNullOrEmpty("$rootDir")) -and (Test-Path "$rootDir")) {
            Write-Host "Removing '${rootDir}'."
            Remove-Item -Path "${rootDir}" -Recurse -Confirm
        }
    }
    finally {
        Write-Host "Press any key to exit..."
        $Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown") | OUT-NULL
        $Host.UI.RawUI.FlushInputbuffer()
    }
}

Export-ModuleMember -Function Add-Song