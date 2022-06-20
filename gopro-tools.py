#!/usr/bin/python3

import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict, namedtuple
from pathlib import PurePath


class Converter:
    def __init__(self, outdir):
        self.outdir = outdir

        os.makedirs(outdir, exist_ok=True)

    def run(self, file):
        return self.exif(self.ffmpeg(file))

    def ffmpeg(self, file):
        filter = """
        [0:0]crop=128:1344:x=624:y=0,format=yuvj420p,
        geq=
        lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        interpolation=b,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[crop],
        [0:0]crop=624:1344:x=0:y=0,format=yuvj420p[left], 
        [0:0]crop=624:1344:x=752:y=0,format=yuvj420p[right], 
        [left][crop]hstack[leftAll], 
        [leftAll][right]hstack[leftDone],

        [0:0]crop=1344:1344:1376:0[middle],

        [0:0]crop=128:1344:x=3344:y=0,format=yuvj420p,
        geq=
        lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        interpolation=b,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[cropRightBottom],
        [0:0]crop=624:1344:x=2720:y=0,format=yuvj420p[leftRightBottom], 
        [0:0]crop=624:1344:x=3472:y=0,format=yuvj420p[rightRightBottom], 
        [leftRightBottom][cropRightBottom]hstack[rightAll], 
        [rightAll][rightRightBottom]hstack[rightBottomDone],
        [leftDone][middle]hstack[leftMiddle],
        [leftMiddle][rightBottomDone]hstack[bottomComplete],

        [0:5]crop=128:1344:x=624:y=0,format=yuvj420p,
        geq=
        lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        interpolation=n,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[leftTopCrop],
        [0:5]crop=624:1344:x=0:y=0,format=yuvj420p[firstLeftTop], 
        [0:5]crop=624:1344:x=752:y=0,format=yuvj420p[firstRightTop], 
        [firstLeftTop][leftTopCrop]hstack[topLeftHalf], 
        [topLeftHalf][firstRightTop]hstack[topLeftDone],

        [0:5]crop=1344:1344:1376:0[TopMiddle],

        [0:5]crop=128:1344:x=3344:y=0,format=yuvj420p,
        geq=
        lum='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        cb='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        cr='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        a='if(between(X, 0, 64), (p((X+64),Y)*(((X+1))/{div}))+(p(X,Y)*(({div}-((X+1)))/{div})), p(X,Y))':
        interpolation=n,crop=64:1344:x=0:y=0,format=yuvj420p,scale=96:1344[TopcropRightBottom],
        [0:5]crop=624:1344:x=2720:y=0,format=yuvj420p[TopleftRightBottom], 
        [0:5]crop=624:1344:x=3472:y=0,format=yuvj420p[ToprightRightBottom], 
        [TopleftRightBottom][TopcropRightBottom]hstack[ToprightAll], 
        [ToprightAll][ToprightRightBottom]hstack[ToprightBottomDone],
        [topLeftDone][TopMiddle]hstack[TopleftMiddle],
        [TopleftMiddle][ToprightBottomDone]hstack[topComplete],

        [bottomComplete][topComplete]vstack[complete], [complete]v360=eac:e:interp=cubic[v]
        """

        out = PurePath(self.outdir, PurePath(file).stem + ".mov")
        cmd = [
            "ffmpeg",
            "-i",
            file,
            "-y",
            "-filter_complex",
            filter.format(div=65),
            "-map",
            "[v]",
            "-map",
            "0:a:0",
            "-c:v",
            "dnxhd",
            "-profile:v",
            "dnxhr_" + self.quality,
            "-pix_fmt",
            "yuv422p",
            "-c:a",
            "pcm_s16le",
            "-f",
            "mov",
            out,
        ]

        subprocess.run(cmd, check=True)

        return out

    # Processes file in-place.
    def exif(self, file):
        cmd = [
            "exiftool",
            "-api",
            "LargeFileSupport=1",
            "-overwrite_original",
            "-XMP-GSpherical:Spherical=true",
            "-XMP-GSpherical:Stitched=true",
            "-XMP-GSpherical:StitchingSoftware=dummy",
            "-XMP-GSpherical:ProjectionType=equirectangular",
            file,
        ]

        subprocess.run(cmd, check=True)

        return file

    def prompt(self):
        opts = {
            "lb": "Low bandwidth [default]",
            "sq": "Standard quality",
            "hq": "High quality",
            "hqx": "Broadcast quality",
            "444": "Finishing quality",
        }

        prompt = ["Choose a quality setting from the following:"]
        for k, v in opts.items():
            prompt.append("({}) {}".format(k, v))
        prompt.append("Quality: ")

        while True:
            q = input("\n".join(prompt))
            if not q:
                self.quality = "lb"
                break
            elif q in opts:
                self.quality = q
                break
            else:
                print("Invalid quality setting: {}\n".format(q))


class Processor:
    # groups: [1] encoding, [2] chapter number, [3] file number
    regex = re.compile("^G(H|X|S|P|)(\d{2})(\d{4})")
    File = namedtuple("File", ["path", "encoding", "chapter", "number"])

    def __init__(self, path, outdir):
        self.path = path
        self.outdir = PurePath(path, outdir)
        self.converter = Converter(self.outdir)
        self.files = {
            ".360": defaultdict(list),
            ".mp4": defaultdict(list),
            ".LRV": defaultdict(list),
        }

        for f in os.listdir(path):
            p = PurePath(path, f)
            m = Processor.regex.match(p.stem)
            if p.suffix not in self.files or not m:
                continue
            t = Processor.File(
                path=p, encoding=m.group(1), chapter=m.group(2), number=m.group(3)
            )
            self.files[p.suffix][t.number].append(t)

        for ts in self.files.values():
            for t in ts.values():
                t.sort(key=lambda t: t.chapter)

    def run(self):
        self.handle_input(self.prompt())

    def can_merge(self, suffix):
        if not self.files[suffix]:
            return False

        for ts in self.files[suffix].values():
            for t in ts:
                if len(t) > 1:
                    return True

        return False

    def merge(self, suffix, out_suffix=None):
        for ts in self.files[suffix].values():
            if len(ts) == 1:
                continue
            out = PurePath(
                self.outdir,
                "G{}--{}-merged{}".format(
                    ts[0].encoding, ts[0].number, out_suffix or suffix
                ),
            )
            cmd = ["ffmpeg", "-f", "concat", "-safe", "0", "-c", "copy", "-i"]
            cmd.extend(map(lambda t: t.path, ts))
            cmd.append(out)

            subprocess.run(cmd, check=True)

    def handle_input(self, i):
        if i["convert_360"]:
            for ts in self.files[".360"].values():
                for t in ts:
                    t.path = self.converter.run(t.path)
        if i["merge_mov"]:
            self.merge(".360", ".mov")
        if i["merge_360"]:
            self.merge(".360")
        if i["merge_mp4"]:
            self.merge(".mp4")
        if i["merge_LRV"]:
            self.merge(".LRV")

    def prompt(self):
        def prompter(msg):
            v = input(msg + " [Y/n] ")
            if not v or v.lower() == "y":
                return True
            return False

        i = defaultdict(bool)

        if self.files[".360"]:
            i["convert_360"] = prompter("Convert .360 files to .mov?")
            if i["convert_360"]:
                self.converter.prompt()
            if self.can_merge(".360"):
                if i["convert_360"]:
                    i["merge_mov"] = prompter("Merge converted .mov files?")
                else:
                    i["merge_360"] = prompter("Merge .360 files?")
        if self.can_merge(".mp4"):
            i["merge_mp4"] = prompter("Merge .mp4 files?")
        if self.can_merge(".LRV"):
            i["merge_LRV"] = prompter("Merge .LRV files?")

        return i


def main():
    parser = argparse.ArgumentParser(description="Convert and merge GoPro video files")
    parser.add_argument("input", nargs="?", default=".", help="Directory to process")
    parser.add_argument(
        "output",
        nargs="?",
        default="Converted",
        help="Directory for converted files",
    )

    args = parser.parse_args()
    path = Path(args.input)

    if not path.is_dir():
        print("input is not a directory\n", file=sys.stderr)
        parser.print_help()
        sys.exit(2)

    Processor(path, args.output).run()


if __name__ == "__main__":
    main()
