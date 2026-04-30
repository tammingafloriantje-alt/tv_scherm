import os
import sys
import subprocess
from pathlib import Path

VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".avi", ".m4v", ".webm"}

TARGET_WIDTH = 1920
TARGET_HEIGHT = 1080


def has_ffmpeg():
    try:
        subprocess.run(
            ["ffmpeg", "-version"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        return True
    except Exception:
        return False


def get_video_resolution(input_file):
    cmd = [
        "ffprobe",
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height",
        "-of", "csv=p=0:s=x",
        str(input_file)
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Kon resolutie niet uitlezen van: {input_file}")

    output = result.stdout.strip()
    if "x" not in output:
        raise RuntimeError(f"Ongeldige ffprobe output voor: {input_file}")

    width, height = output.split("x")
    return int(width), int(height)


def build_filter(width, height):
    if height > width:
        # Staande video:
        # schaal naar hoogte 1080 met behoud van verhouding
        # en zet in liggend 1920x1080 frame met zwarte balken links/rechts
        return (
            "scale=-2:1080,"
            "pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black"
        )
    else:
        # Liggende video:
        # schaal passend binnen 1920x1080 en pad indien nodig
        return (
            "scale=1920:1080:force_original_aspect_ratio=decrease,"
            "pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black"
        )


def convert_video(input_file, output_file):
    width, height = get_video_resolution(input_file)
    vf = build_filter(width, height)

    cmd = [
        "ffmpeg",
        "-y",
        "-i", str(input_file),
        "-vf", vf,
        "-c:v", "libx264",
        "-preset", "fast",
        "-crf", "23",
        "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        "-c:a", "aac",
        "-b:a", "192k",
        str(output_file)
    ]

    print(f"Converteer: {input_file.name} ({width}x{height})")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        raise RuntimeError(f"Conversie mislukt voor: {input_file}")


def main():
    if len(sys.argv) != 3:
        print("Gebruik:")
        print("python convert_videos.py <input_map> <output_map>")
        sys.exit(1)
    input_dir = 'ruwe pi filmpjes'
    output_dir = 'Scherm'

    [os.remove(os.path.join(output_dir, f)) for f in os.listdir(output_dir) if os.path.isfile(os.path.join(output_dir, f))]
    if not input_dir.exists() or not input_dir.is_dir():
        print(f"Input map bestaat niet of is geen map: {input_dir}")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    if not has_ffmpeg():
        print("ffmpeg is niet gevonden in PATH.")
        print("Installeer ffmpeg eerst en probeer opnieuw.")
        sys.exit(1)

    video_files = [
        f for f in input_dir.iterdir()
        if f.is_file() and f.suffix.lower() in VIDEO_EXTENSIONS
    ]

    if not video_files:
        print("Geen videobestanden gevonden in de input map.")
        sys.exit(0)

    for input_file in video_files:
        output_file = output_dir / f"{input_file.stem}_pi.mp4"
        try:
            convert_video(input_file, output_file)
            print(f"Klaar: {output_file.name}\n")
        except Exception as e:
            print(f"Fout bij {input_file.name}: {e}\n")

    print("Alle video’s zijn verwerkt.")


if __name__ == "__main__":
    main()