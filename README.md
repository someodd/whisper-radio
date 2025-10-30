# Whisper Radio

IceCast radio station of a TTS (espeak) reading off:

  * Random text file
  * RSS headline
  * Weather data (METAR)
  * Random music file
  * Reads the "freshest" thread on gopherden (gopher://gopher.someodd.zip/phorum)
  * MOTD: a message you want to consistently be read
  * Some Masstodon/Fosstodon data
  * Responds to the latest post under a specific hashtag on fosstodon (uses AI)

"Whisper" is a reference to the espeak voice or whatever used.

Please also see [the showcase post I made about this on my blog](https://www.someodd.zip/showcase/whisper-radio). It has some tips for troubleshooting and setting up an Icecast2 server.

Here's a demo/the official Whisper Radio stream, you may be able to open in your browser or a media player: https://radio.someodd.zip/stream

Be sure to do this then edit the files before you begin:

```
cp ezstream.example.xml ezstream.xml
cp config.example.sh config.sh
```

Now being used by [Bitreich](http://bitreich.org/)!

## Warning

This was an experiment in seeing how far I could take shell scripting, kinda,
and it's just a real headache sometimes. There may be bugs!

## Dependencies

  * espeak
  * jq
  * xmlstarlet
  * curl
  * ezstream
  * icecast2
  * metar
  * piper-tts
  * ffmpeg

```
sudo apt-get update
sudo apt-get install espeak jq curl ezstream icecast2 metar ffmpeg pipx ffmpeg xmlstarlet
pipx install piper-tts
```

### Content setup

Make sure to create and populate these directories in the project folder:

* `audio/` put mp3s and the like in here. The pool of audio that'll be randomly
  selected from to build the radio program.
* `text/` same as above, but with plain text files.

Also check `config.sh` for Atom/RSS feeds, gopher page, etc.

### piper-tts setup

Download:

  * [The JSON for the hfc_female Piper voice](https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/hfc_female/medium/en_US-hfc_female-medium.onnx.json)
  * [The hfc_female Piper voice](https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/hfc_female/medium/en_US-hfc_female-medium.onnx?download=true)
  * [Check out the supported voices for Piper](https://github.com/rhasspy/piper/blob/master/VOICES.md)

You may have to open a new terminal for it to be in the path.

As of right now I had to use this weird setup to get around [a current issue with piper installation](https://github.com/rhasspy/piper/issues/509):

```
pipx install uv
uv tool install --python 3.11 piper-tts==1.2.0
```

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

## Copy the repo

```
git clone https://github.com/someodd/whisper-radio
cd whisper-radio
```

## Run the script for first time + send with ezstream

```
./whisper.sh
```

## Crontab

Use `crontab -e`, run every five minutes and log errors:

```
*/5 * * * * /home/baudrillard/Projects/whisper-radio/whisper.sh 2>> /home/baudrillard/Projects/whisper-radio/logfile
```

### Troubleshooting

I had this problem where I thought the project was broken but I restarted
computer and it works again. careful how kill ezstream maybe.

## Tips

Link music from an archive of some musician to the possible audio sources, to avoid duplication:

```
sudo find /foo/bar/some-legal-music-archive -name "*.mp3" -exec ln -s {} ./audio/ \;
```
