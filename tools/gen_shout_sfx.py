"""Generate rasped old-man driver-shout WAVs via edge-tts + ffmpeg."""

from __future__ import annotations

import asyncio
import os
import subprocess
import tempfile
from pathlib import Path

import edge_tts
import imageio_ffmpeg

OUT = Path("assets/audio/shouts")
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
# Adult male; rasp and age come from pitch-down + grit, not a thin scream.
VOICE = "en-US-GuyNeural"

# Four beats the van actually uses.
LINES = [
	("shout_start", "Go, go, GO! Move this thing!"),
	("shout_slow", "Ease off, ease off! Slow it down!"),
	("shout_resume", "Alright, drive!"),
	("shout_turbo", "Punch it! NOW, DUMBASS!"),
]


async def synth(text: str) -> bytes:
	# Slow and low. Neural TTS will not rasp on its own; ffmpeg adds gravel.
	communicate = edge_tts.Communicate(
		text, VOICE, rate="-8%", pitch="-18Hz", volume="+40%"
	)
	chunks: list[bytes] = []
	async for chunk in communicate.stream():
		if chunk["type"] == "audio":
			chunks.append(chunk["data"])
	return b"".join(chunks)


def crush_to_wav(mp3_bytes: bytes, wav_path: Path) -> None:
	with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
		tmp.write(mp3_bytes)
		tmp_path = tmp.name
	try:
		# Keep chest (no 280Hz highpass). Drop pitch ~3 semitones, thicken
		# low-mids, bitcrush for rasp.
		af = (
			"silenceremove=start_periods=1:start_silence=0.02:start_threshold=-40dB:"
			"stop_periods=-1:stop_silence=0.08:stop_threshold=-40dB,"
			"rubberband=pitch=0.82,"
			"highpass=f=70,lowpass=f=7200,"
			"equalizer=f=160:t=q:w=1.1:g=5,"
			"equalizer=f=420:t=q:w=0.9:g=3,"
			"equalizer=f=2800:t=q:w=1.4:g=2,"
			"acompressor=threshold=-18dB:ratio=8:attack=6:release=60:makeup=8,"
			"acrusher=bits=12:mode=log:aa=1,"
			"volume=1.8,alimiter=limit=0.95"
		)
		cmd = [
			FFMPEG,
			"-y",
			"-i",
			tmp_path,
			"-af",
			af,
			"-ac",
			"1",
			"-ar",
			"48000",
			"-sample_fmt",
			"s16",
			"-t",
			"2.5",
			str(wav_path),
		]
		result = subprocess.run(
			cmd, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE
		)
		if result.returncode != 0:
			err = result.stderr.decode("utf-8", errors="replace")
			raise RuntimeError(f"ffmpeg failed ({result.returncode}): {err}")
	finally:
		os.unlink(tmp_path)


async def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	for name, text in LINES:
		mp3 = await synth(text)
		if not mp3:
			raise RuntimeError(f"no audio for {name}")
		wav_path = OUT / f"{name}.wav"
		crush_to_wav(mp3, wav_path)
		secs = wav_path.stat().st_size / (48000 * 2)
		print(f"wrote {wav_path.name} ~{secs:.2f}s — {text!r}")


if __name__ == "__main__":
	asyncio.run(main())
