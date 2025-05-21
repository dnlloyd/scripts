import sys
import os
import re

def main():
    if len(sys.argv) != 2:
        print("Usage: python srt_conversion.py <filename.srt>")
        sys.exit(1)

    filename = sys.argv[1]

    if not os.path.isfile(filename):
        print(f"Error: '{filename}' does not exist or is not a file.")
        sys.exit(1)

    print(f"Processing file: {filename}")

    def convert_srt_to_vtt(srt_path, vtt_path):
        def normalize_timestamp(srt_ts):
            # Replace commas with periods and ensure milliseconds are 3 digits (left-padded)
            return re.sub(
                r"(\d{2}:\d{2}:\d{2}),(\d{1,3})",
                lambda m: f"{m.group(1)}.{m.group(2).zfill(3)}",
                srt_ts
            )

        with open(srt_path, "r", encoding="utf-8") as srt_file, open(vtt_path, "w", encoding="utf-8") as vtt_file:
            vtt_file.write("WEBVTT\n\n")
            for line in srt_file:
                if re.match(r"^\d+\s*$", line):  # Skip sequence numbers
                    continue
                if "-->" in line:
                    line = normalize_timestamp(line)
                vtt_file.write(line)

    
    convert_srt_to_vtt(filename, filename + ".vtt")

if __name__ == "__main__":
    main()
