#!/usr/bin/env python3
"""Builds the showcase videos of the documentation (docs/static/video).

A scene (tools/videos/scenes/<name>.toml) is a document and the edits a user
makes to it, each with a caption. For every step, the edited document is
compiled with the package of this checkout (the import of
"@preview/invoice-pro:<version>" is redirected to /src/lib.typ), and the video
shows the code being typed next to the invoice it compiles to. A step can show
a region of the invoice up close (`focus`): the preview then grows over the
editor.

Everything is drawn by Typst (tools/videos/frames.typ renders one page per
frame from the timeline this script writes) and encoded by ffmpeg, so a
rebuild without changes gives the same video.

Usage: build.py [scene ...]   (default: every scene)

Environment: TYPST_BIN (default typst), FFMPEG_BIN (default ffmpeg),
VIDEOS_DATE_EPOCH (the date of the invoices, default 22 September 2026).
"""
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools" / "videos"
BUILD = ROOT / "build" / "videos"
OUT = ROOT / "docs" / "static" / "video"
TYPST = os.environ.get("TYPST_BIN", "typst")
FFMPEG = os.environ.get("FFMPEG_BIN", "ffmpeg")
EPOCH = os.environ.get("VIDEOS_DATE_EPOCH", "1790078400")

PAGE_PPI = 216  # the invoice pages: sharp up close
FRAME_PPI = 108  # a 1280 x 720 pt frame is 1920 x 1080 px
FPS = 30

# The geometry of the frame (pt), used by frames.typ as well.
EDITOR = dict(x=36, y=146, w=640, h=548)
PREVIEW = dict(x=692, y=24, w=560, h=672)
SPOTLIGHT = dict(x=36, y=146, w=1216, h=548)
BAR, CODE_TOP, CODE_SIZE, LINE_HEIGHT = 34, 10, 15, 22.5
LINES = int((EDITOR["h"] - BAR - CODE_TOP - 8) / LINE_HEIGHT)
MAX_COLS = int((EDITOR["w"] - 8 - 46) / (CODE_SIZE * 1233 / 2048))
PAD, GAP = 16, 22
# The closest zoom: a point of the page may cover 3.9 pixels of the video,
# 1.3 times the 3 pixels it has in the page images (216 ppi).
ZOOM_PX = 3.9

# Timing (s).
TITLE_HOLD = 2.6
CARD_FADE = 0.5
END_HOLD = 3.4
PRE = 0.5  # a new caption shows before the typing starts
CHARS_PER_FRAME = 2
CHAR_FRAME = 0.075  # about 27 characters a second
TYPE_MAX = 2.6  # longer edits are typed faster
LINE_FRAME = 0.17  # a line of a pasted block
COMPILE = 0.25  # the preview follows the last keystroke
ZOOM_IN = 0.8
ZOOM_OUT = 0.55
HOLD = 1.9
BADGE_FADE = 0.3


def version():
    m = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT / "typst.toml").read_text(), re.M)
    return m.group(1)


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


class Scene:
    def __init__(self, name):
        self.name = name
        self.data = tomllib.loads((TOOLS / "scenes" / f"{name}.toml").read_text())
        self.version = version()
        self.dir = BUILD / name
        self.dir.mkdir(parents=True, exist_ok=True)
        for asset in self.data.get("assets", []):
            shutil.copy(TOOLS / "assets" / asset, self.dir / asset)
        text = self.data["start"].replace("{version}", self.version)
        self.start = text
        self.steps = []
        for i, st in enumerate(self.data.get("step", [])):
            new, texts = text, []
            for e in st.get("edit", []):
                find = e["find"].replace("{version}", self.version)
                repl = e["with"].replace("{version}", self.version)
                n = new.count(find)
                if n != 1:
                    sys.exit(f"{name}: step {i + 1} ({st.get('caption')!r}): {find!r} occurs {n} times")
                new = new.replace(find, repl)
                texts.append(new)
            # each edit is typed on its own; the preview follows the last
            self.steps.append(dict(st, text=new, texts=texts))
            text = new
        for t in [self.start] + [s["text"] for s in self.steps]:
            for line in t.split("\n"):
                if len(line) > MAX_COLS:
                    sys.exit(f"{name}: a line is longer than {MAX_COLS} characters: {line!r}")

    # --- compiling ---------------------------------------------------------
    def pages(self, text):
        src = text.replace(f'"@preview/invoice-pro:{self.version}"', '"/src/lib.typ"')
        key = hashlib.sha1((src + EPOCH + str(PAGE_PPI)).encode()).hexdigest()[:12]
        found = sorted(self.dir.glob(f"p-{key}-*.png"))
        if found:
            return found
        f = self.dir / f"p-{key}.typ"
        f.write_text(src)
        env = dict(os.environ, SOURCE_DATE_EPOCH=EPOCH)
        cmd = [TYPST, "compile", "--root", str(ROOT), "--ppi", str(PAGE_PPI), str(f),
               str(self.dir / f"p-{key}-{{0p}}.png")]
        r = subprocess.run(cmd, capture_output=True, text=True, env=env)
        if r.returncode != 0:
            sys.exit(f"{self.name}: a step does not compile:\n{r.stderr}\n--- source ---\n{text}")
        return sorted(self.dir.glob(f"p-{key}-*.png"))

    # --- the preview -------------------------------------------------------
    @staticmethod
    def layout(pages):
        """Up to two pages side by side, fitted into the preview (zoom 1)."""
        pages = pages[:2]
        pts = [(w / PAGE_PPI * 72, h / PAGE_PPI * 72) for w, h in (png_size(p) for p in pages)]
        vw, vh = PREVIEW["w"], PREVIEW["h"]
        gaps = GAP * (len(pts) - 1)
        s = min((vw - 2 * PAD - gaps) / sum(w for w, _ in pts), (vh - 2 * PAD) / max(h for _, h in pts))
        x = (vw - s * sum(w for w, _ in pts) - gaps) / 2
        boxes = []
        for p, (w, h) in zip(pages, pts):
            boxes.append(dict(img="/" + p.relative_to(ROOT).as_posix(), x=x, y=(vh - s * h) / 2,
                              w=s * w, h=s * h, scale=s))
            x += s * w + GAP
        return boxes

    @staticmethod
    def home():
        return dict(vp=dict(PREVIEW), c=(PREVIEW["w"] / 2, PREVIEW["h"] / 2), z=1.0, panel=0.0)

    @staticmethod
    def spot(boxes, focus):
        """The camera that shows `focus` ([page, x0, y0, x1, y1]) in the spotlight."""
        page, x0, y0, x1, y1 = focus
        b = boxes[min(int(page) - 1, len(boxes) - 1)]
        rw, rh = (x1 - x0) * b["w"], (y1 - y0) * b["h"]
        z_max = ZOOM_PX / (b["scale"] * FRAME_PPI / 72)
        z = min(SPOTLIGHT["w"] * 0.94 / rw, SPOTLIGHT["h"] * 0.92 / rh, z_max)
        c = (b["x"] + (x0 + x1) / 2 * b["w"], b["y"] + (y0 + y1) / 2 * b["h"])
        return dict(vp=dict(SPOTLIGHT), c=c, z=z, panel=1.0)

    @staticmethod
    def project(boxes, cam):
        vp, (cx, cy), z = cam["vp"], cam["c"], cam["z"]
        return [dict(b, x=vp["w"] / 2 + (b["x"] - cx) * z, y=vp["h"] / 2 + (b["y"] - cy) * z,
                     w=b["w"] * z, h=b["h"] * z) for b in boxes]

    # --- the timeline ------------------------------------------------------
    def timeline(self):
        frames = []
        st8 = dict(code=self.start, caret=None, hl=None, first=0, n=None, caption=None, sub=None,
                   boxes=self.layout(self.pages(self.start)), cam=self.home(), badge=None, chip=None)

        def emit(d, **over):
            s = dict(st8, **over)
            cam = s["cam"]
            frames.append(dict(
                d=round(d, 4), code=s["code"], caret=s["caret"], hl=s["hl"], first=s["first"],
                n=s["n"], caption=s["caption"], sub=s["sub"],
                vp={k: round(v, 2) for k, v in cam["vp"].items()}, panel=round(cam["panel"], 3),
                pages=[{k: (round(v, 2) if isinstance(v, float) else v) for k, v in b.items()
                        if k != "scale"} for b in self.project(s["boxes"], cam)],
                badge=s["badge"], chip=s["chip"], card=s.get("card"),
            ))

        def move(target, dur):
            a = st8["cam"]
            if a == target:
                return
            k = max(2, int(dur * FPS))
            for i in range(1, k + 1):
                e = ease(i / k)
                st8["cam"] = dict(
                    vp={key: lerp(a["vp"][key], target["vp"][key], e) for key in a["vp"]},
                    c=(lerp(a["c"][0], target["c"][0], e), lerp(a["c"][1], target["c"][1], e)),
                    z=a["z"] * (target["z"] / a["z"]) ** e,
                    panel=lerp(a["panel"], target["panel"], e),
                )
                emit(dur / k)
            st8["cam"] = target

        def scroll_to(line):
            first = st8["first"]
            n_lines = st8["code"].count("\n") + 1
            if line < first + 2:
                first = max(0, line - 4)
            elif line > first + LINES - 3:
                first = line - LINES + 4
            st8["first"] = max(0, min(first, max(0, n_lines - LINES)))

        def fade_badge():
            if st8["badge"]:
                text = st8["badge"]["text"]
                k = max(2, int(BADGE_FADE * FPS))
                for i in range(1, k + 1):
                    st8["badge"] = dict(text=text, alpha=round(1 - i / k, 3))
                    emit(BADGE_FADE / k)
                st8["badge"] = None

        # the title card fades over the first scene
        emit(TITLE_HOLD, card=dict(kind="title", alpha=1.0))
        k = int(CARD_FADE * FPS)
        for i in range(1, k + 1):
            emit(CARD_FADE / k, card=dict(kind="title", alpha=round(1 - ease(i / k), 3)))
        intro = self.data.get("intro")
        if intro:
            st8.update(caption=intro.get("caption"), sub=intro.get("sub"))
            emit(intro.get("hold", 2.4))

        for n, step in enumerate(self.steps, 1):
            new = step["text"]
            st8.update(n=n, caption=step.get("caption"), sub=step.get("sub"), hl=None, caret=None)
            fade_badge()
            keep = step.get("keep", False) and st8["cam"]["panel"] > 0
            if not step["texts"] and step.get("focus") and st8["cam"]["panel"] > 0:
                # nothing to type: the camera pans to the next region
                move(self.spot(st8["boxes"], step["focus"]), ZOOM_IN * 1.4)
                emit(step.get("hold", HOLD))
                continue
            if not keep:
                move(self.home(), ZOOM_OUT)
                emit(PRE)
            for t in step["texts"]:
                if t != st8["code"]:
                    self.type(st8["code"], t, step, st8, emit, scroll_to, chip=keep)
            # the preview follows the edit
            st8["boxes"] = self.layout(self.pages(new))
            st8.update(caret=None)
            if keep and step.get("focus"):
                st8["cam"] = self.spot(st8["boxes"], step["focus"])
            # a step can show its result a while before the zoom (`look`)
            emit(0.5 if keep else step.get("look", 0.2))
            st8.update(chip=None)
            if step.get("badge"):
                k = max(2, int(BADGE_FADE * FPS))
                for i in range(1, k + 1):
                    st8["badge"] = dict(text=step["badge"], alpha=round(i / k, 3))
                    emit(BADGE_FADE / k)
            if step.get("focus") and not keep:
                move(self.spot(st8["boxes"], step["focus"]), ZOOM_IN)
            emit(step.get("hold", HOLD))

        fade_badge()
        st8.update(hl=None, caret=None)
        k = int(CARD_FADE * FPS)
        for i in range(1, k + 1):
            emit(CARD_FADE / k, card=dict(kind="end", alpha=round(ease(i / k), 3)))
        emit(END_HOLD, card=dict(kind="end", alpha=1.0))

        total = sum(f["d"] for f in frames)
        t = 0.0
        for f in frames:
            f["progress"] = round(t / total, 4)
            t += f["d"]
        return frames, total

    @staticmethod
    def type(prev, new, step, st8, emit, scroll_to, chip=False):
        """Emits the frames of the edit from `prev` to `new`, as a user types it."""
        p = 0
        while p < min(len(prev), len(new)) and prev[p] == new[p]:
            p += 1
        s = 0
        while s < min(len(prev), len(new)) - p and prev[-1 - s] == new[-1 - s]:
            s += 1
        old_mid, new_mid = prev[p:len(prev) - s], new[p:len(new) - s]
        if not old_mid or not new_mid:
            # an insertion (or deletion) slides to the start of its line, so
            # whole lines are typed as whole lines
            mid = new_mid or old_mid
            while p > 0 and mid and prev[p - 1] != "\n" and prev[p - 1] == mid[-1]:
                mid = prev[p - 1] + mid[:-1]
                p -= 1
            new_mid, old_mid = (mid, "") if new_mid else ("", mid)
        else:
            # a replacement takes whole words, as a user selects a word to
            # retype it
            def word(c):
                return c.isalnum() or c == "_"
            while p > 0 and word(prev[p - 1]) and (word(old_mid[0]) or word(new_mid[0])):
                old_mid, new_mid = prev[p - 1] + old_mid, prev[p - 1] + new_mid
                p -= 1
            e = p + len(old_mid)
            while e < len(prev) and word(prev[e]) and (word(old_mid[-1]) or word(new_mid[-1])):
                old_mid, new_mid = old_mid + prev[e], new_mid + prev[e]
                e += 1
        # inserting whole lines: the caret goes to the end of the line before
        # and the user presses Enter first, as in an editor
        if not old_mid and new_mid.endswith("\n") and p > 0 and prev[p - 1] == "\n":
            p -= 1
            new_mid = "\n" + new_mid[:-1]
        # deleting whole lines: from the end of the last one, as with
        # Backspace, so the line below stays where it is
        if not new_mid and old_mid.endswith("\n") and p > 0 and prev[p - 1] == "\n":
            p -= 1
            old_mid = "\n" + old_mid[:-1]
        head, tail = prev[:p], prev[p + len(old_mid):]
        mode = step.get("type", "auto")
        if mode == "auto":
            mode = "chars" if len(new_mid) <= 160 and len(old_mid) <= 56 else "lines"
        texts = []
        if chip:
            # the chip shows where the edit goes before the typing starts
            texts.append((prev, p, PRE + 0.3))
        if mode == "chars":
            for c in range(len(old_mid), 0, -3):
                m = max(0, c - 3)
                texts.append((head + old_mid[:m] + tail, p + m, CHAR_FRAME * 0.6))
            # at most TYPE_MAX; a single short edit in the chip goes slower
            cpf = max(CHARS_PER_FRAME, -(-len(new_mid) // int(TYPE_MAX / CHAR_FRAME)))
            dur = CHAR_FRAME
            if chip and len(new_mid) <= 12:
                cpf, dur = 1, CHAR_FRAME * 1.6
            for c in range(0, len(new_mid), cpf):
                m = min(len(new_mid), c + cpf)
                texts.append((head + new_mid[:m] + tail, p + m, dur))
        else:
            # whole lines: the changed lines go, the new ones come line by line
            p0 = prev.rfind("\n", 0, p) + 1
            e = p + len(old_mid)
            if e > 0 and e <= len(prev) and (e == len(prev) or prev[e - 1] != "\n"):
                nl = prev.find("\n", e)
                e = len(prev) if nl < 0 else nl + 1
            s2 = len(prev) - e
            head2, tail2 = prev[:p0], prev[e:]
            new_mid2 = new[p0:len(new) - s2]
            if e > p0:
                texts.append((head2 + tail2, p0, 0.3))
            acc = ""
            for part in re.split(r"(?<=\n)", new_mid2):
                if part:
                    acc += part
                    texts.append((head2 + acc + tail2, p0 + len(acc) - (1 if part.endswith("\n") else 0),
                                  LINE_FRAME))
        if not texts or texts[-1][0] != new:
            texts.append((new, p + len(new_mid), CHAR_FRAME))
        if chip:
            # the finished line stays a moment before the preview follows
            t, pos, d = texts[-1]
            texts[-1] = (t, pos, d + 0.35)
        start_line = prev[:p].count("\n") + (1 if new_mid.startswith("\n") else 0)
        for t, pos, d in texts:
            line = t[:pos].count("\n")
            col = pos - (t.rfind("\n", 0, pos) + 1)
            st8["code"] = t
            scroll_to(line)
            st8["caret"] = [line, col]
            st8["hl"] = [min(start_line, line), max(start_line, line)]
            if chip:
                text = t.split("\n")[line]
                indent = len(text) - len(text.lstrip())
                st8["chip"] = dict(code=text.strip(), col=max(0, col - indent))
            emit(d)
        # the changed lines stay marked
        a, b = prev.split("\n"), new.split("\n")
        i = 0
        while i < min(len(a), len(b)) and a[i] == b[i]:
            i += 1
        j = 0
        while j < min(len(a), len(b)) - i and a[-1 - j] == b[-1 - j]:
            j += 1
        st8["hl"] = [i, len(b) - 1 - j] if len(b) - 1 - j >= i else None
        st8["code"] = new
        if not chip:
            emit(COMPILE)

    # --- rendering ---------------------------------------------------------
    def render(self):
        frames, total = self.timeline()
        tl = dict(
            title=self.data["title"], subtitle=self.data.get("subtitle", ""),
            tagline=self.data.get("tagline", "An invoice template for Typst · open source"),
            outro=self.data.get("outro", "Try it yourself"),
            link=self.data.get("link", "leonieziechmann.github.io/invoice-pro"),
            accent=self.data.get("accent", "#0f766e"),
            file=self.data.get("file", "invoice.typ"),
            geometry=dict(editor=EDITOR, preview=PREVIEW, spotlight=SPOTLIGHT, bar=BAR,
                          **{"code-top": CODE_TOP, "code-size": CODE_SIZE,
                             "line-height": LINE_HEIGHT}, lines=LINES),
            frames=frames,
        )
        tl["import"] = f'#import "@preview/invoice-pro:{self.version}": *'
        (self.dir / "timeline.json").write_text(json.dumps(tl, ensure_ascii=False))
        fdir = self.dir / "frames"
        if fdir.exists():
            shutil.rmtree(fdir)
        fdir.mkdir()
        cmd = [TYPST, "compile", "--root", str(ROOT), "--ppi", str(FRAME_PPI),
               "--input", "timeline=/" + (self.dir / "timeline.json").relative_to(ROOT).as_posix(),
               str(TOOLS / "frames.typ"), str(fdir / "{0p}.png")]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f"{self.name}: frames.typ failed:\n{r.stderr}")
        pngs = sorted(fdir.glob("*.png"))
        assert len(pngs) == len(frames), (len(pngs), len(frames))
        lines = [f"file '{png.name}'\nduration {f['d']:.4f}" for png, f in zip(pngs, frames)]
        lines.append(f"file '{pngs[-1].name}'")
        (fdir / "list.txt").write_text("\n".join(lines) + "\n")
        OUT.mkdir(parents=True, exist_ok=True)
        video = OUT / f"{self.name}.mp4"
        cmd = [FFMPEG, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", "list.txt",
               "-vf", f"fps={FPS},format=yuv420p", "-c:v", "libx264", "-preset", "veryslow",
               "-crf", str(self.data.get("crf", 27)), "-tune", "stillimage", "-threads", "4",
               "-movflags", "+faststart", "-an", str(video)]
        subprocess.run(cmd, check=True, cwd=fdir)
        # the poster: the last frame of the step `poster` (default: the last step)
        pick = self.data.get("poster", len(self.steps))
        idx = max((i for i, f in enumerate(frames) if f.get("n") == pick and not f.get("card")),
                  default=len(frames) // 2)
        poster = OUT / f"{self.name}.jpg"
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", str(pngs[idx]), "-vf", "scale=1280:-1",
                        "-q:v", "4", str(poster)], check=True)
        print(f"{self.name}: {total:.1f} s, {len(frames)} frames, "
              f"{video.stat().st_size / 1e6:.2f} MB, poster {poster.stat().st_size / 1e3:.0f} kB")


def main():
    names = sys.argv[1:] or sorted(p.stem for p in (TOOLS / "scenes").glob("*.toml"))
    for name in names:
        Scene(name).render()


if __name__ == "__main__":
    main()
