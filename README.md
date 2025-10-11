# Song Practice Quickstart

This Powershell command creates a common file and folder structure so you can quickly start learning new songs.
Since this script reflects my own workflow it is heavily opinionated.

## Pre-Requisites

- Powershell (Tested with v5.1)
- [youtube-dl](https://github.com/ytdl-org/youtube-dl#installation) is used for downloading media content.
- [ffmpeg](https://ffmpeg.org/download.html) is used by youtube-dl for media conversion.
- [Transcribe!](https://www.seventhstring.com/xscribe/download.html) is used for slowing down and analysis of the song.
- [Generate-BackingTrack](https://github.com/hochandr/demucs-backing-track-generator) Cmd is used for backing track generation.

## Getting Started

Set the `REPERTOIRE_ROOT` environment variable to the root directory of your repertoire (absolute path). New songs will be added here.
A preferably recording-ready DAW project will be copied to the new song directory, if you set `DAW_PROJECT_TEMPLATE` env to the templates absolute path.

Once you execute the `Add-Song` command an interactive setup routine will start and handle following steps.

1. Create folder structure
2. Copy DAW project template
3. Fetch lyrics
4. Get the audio file of the track
5. Fetch song metadata (Key, BPM)
6. Generate a Transcribe! file with proper configuration. The stem files (see last step) will be referenced as well.
7. Download additional video and audio files
8. Generate backing track

The resulting structure will look like this:

```
.\{Artist} - {Song}
├───backing-tracks
│       {Artist} - {Song}_remove_other.mp3
├───covers
|       {Artist} {Song} Cover.mp4
├───recordings
│   └───2025-04-18
│           {Artist} - {Song}.cpr
├───tabs
│       The {Artist} - {Song}.gp5
├───transcriptions
│   │   {Artist} - {Song}.mp3
│   │   {Artist} - {Song}.xsc
│   │   lyrics.txt
│   └───stems
│           bass.mp3
│           drums.mp3
│           other.mp3
│           vocals.mp
└───tutorials
        {Artist} {Song} Guitar Lesson.mp4
```
