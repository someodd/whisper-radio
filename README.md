# Whisper Radio

IceCast radio station of a TTS (espeak) reading off, hopefully soon:

  * Random text files
  * RSS headlines
  * Weather data
  * Random music files
  * Read something via gopher? I want to have it read the latest thread on gopherden!
  * Random Internet Archive public domain music, radio broadcasts (?)
  * MOTD: a message you want to consistently be read

"Whisper" is a reference to the espeak voice or whatever used.

## Dependencies

  * espeak
  * jq
  * curl
  * ezstream
  * icecast2
  * metar
  * piper-tts
  * ffmpeg

### piper-tts setup

```
sudo apt-get install pipx
pipx install piper-tts
```

Download:

  * [The JSON for the hfc_female Piper voice](https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/hfc_female/medium/en_US-hfc_female-medium.onnx.json)
  * [The hfc_female Piper voice](https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/hfc_female/medium/en_US-hfc_female-medium.onnx?download=true)
  * [Check out the supported voices for Piper](https://github.com/rhasspy/piper/blob/master/VOICES.md)

You may have to open a new terminal for it to be in the path.

### icecast2 set up

Install `icecast2`. It asked me to optionally input some info through the TUI.
For my example/demo I chose `hackme` (source password, relay password, admin
password [this is extremely bad practice]). I also entered `localhost`.

```
sudo apt-get update
sudo apt-get install icecast2
```

Edit `sudo vi /etc/icecast2/icecast.xml`.

```
sudo systemctl start icecast2
```

To persist the server:

```
sudo systemctl enable icecast2
```

I RECOMMEND YOU USE LOW LOW LOW MP3 STREAMING SETTINGS, MONO ETC

### Run the script for first time + send with ezstream

```
./whisper.sh
```

### Actually crontab the whole thing...

How often to poll or

### Troubleshooting

I had this problem where I thought the project was broken but I restarted
computer and it works again. careful how kill ezstream maybe.
