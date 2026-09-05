"""Generate screamier driver-shout WAVs via edge-tts + ffmpeg crush."""

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
VOICE = "en-US-GuyNeural"

# Four beats the van actually uses.
LINES = [
	("shout_start", "Go, go, GO! Move this thing!"),
	("shout_slow", "Ease off, ease off! Slow it down!"),
	("shout_resume", "Awright, normal speed! Drive normal!"),
	("shout_turbo", "Punch it! NOW, DUMBASS!"),
]


async def synth(text: str) -> bytes:
	# Rate/pitch/volume pushed hard — neural TTS won't truly scream, so we
	# also crush it in ffmpeg below.
	communicate = edge_tts.Communicate(
		text, VOICE, rate="+50%", pitch="+30Hz", volume="+80%"
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
		# Trim leading/trailing hush, pitch up ~3 semitones via asetrate,
		# compress hard, boost. Keep it under ~2s.
		af = (
			"silenceremove=start_periods=1:start_silence=0.02:start_threshold=-40dB:"
			"stop_periods=-1:stop_silence=0.08:stop_threshold=-40dB,"
			"asetrate=24000*1.28,aresample=48000,"
			"highpass=f=280,lowpass=f=5200,"
			"acompressor=threshold=-22dB:ratio=14:attack=2:release=30:makeup=14,"
			"volume=5,alimiter=limit=0.98"
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
		subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
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
		# Duration sanity check via file size (~768 kbps mono s16 @ 48k).
		secs = wav_path.stat().st_size / (48000 * 2)
		print(f"wrote {wav_path.name} ~{secs:.2f}s — {text!r}")


if __name__ == "__main__":
	asyncio.run(main())
