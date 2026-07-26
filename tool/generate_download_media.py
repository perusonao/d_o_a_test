"""Generate the smartphone play guides and gameplay overview video."""

from pathlib import Path

import imageio.v2 as imageio
import numpy
from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.colors import Color, HexColor, white
from reportlab.lib.pagesizes import A5
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "web" / "downloads"
MEDIA_SOURCES = ROOT / "tool" / "media_sources"
APP_ICON = ROOT / "assets" / "branding" / "app_icon.png"
GAME_SHOT = MEDIA_SOURCES / "media-game.png"
TUTORIAL_SHOT = MEDIA_SOURCES / "media-tutorial.png"
FONT_PATH = Path("C:/Windows/Fonts/YuGothM.ttc")

BG = "#0B0B10"
GOLD = "#C8A34A"
BLUE = "#4EB5E8"
RED = "#E0554F"
PURPLE = "#B078FF"
GREEN = "#4FCB84"


def split_japanese(text: str, limit: int) -> list[str]:
    lines: list[str] = []
    for paragraph in text.splitlines():
        if not paragraph:
            lines.append("")
            continue
        while len(paragraph) > limit:
            lines.append(paragraph[:limit])
            paragraph = paragraph[limit:]
        lines.append(paragraph)
    return lines


class GuidePdf:
    def __init__(self, path: Path, title: str):
        pdfmetrics.registerFont(UnicodeCIDFont("HeiseiKakuGo-W5"))
        self.c = canvas.Canvas(str(path), pagesize=A5)
        self.width, self.height = A5
        self.title = title
        self.page = 0

    def add_page(
        self,
        heading: str,
        body: str,
        *,
        accent: str = GOLD,
        image: Path | None = None,
        footer: str = "9人の審判 / NINE VERDICTS",
    ) -> None:
        self.page += 1
        c = self.c
        c.setFillColor(HexColor(BG))
        c.rect(0, 0, self.width, self.height, fill=1, stroke=0)
        c.setStrokeColor(HexColor(GOLD))
        c.setLineWidth(1)
        c.roundRect(16, 16, self.width - 32, self.height - 32, 12, stroke=1)
        c.setFillColor(HexColor(accent))
        c.setFont("HeiseiKakuGo-W5", 18)
        c.drawString(30, self.height - 54, heading)
        c.setStrokeColor(HexColor(accent))
        c.line(30, self.height - 65, self.width - 30, self.height - 65)

        body_top = self.height - 88
        if image:
            source = Image.open(image)
            max_h = 270
            max_w = self.width - 72
            scale = min(max_w / source.width, max_h / source.height)
            draw_w = source.width * scale
            draw_h = source.height * scale
            c.drawImage(
                ImageReader(source),
                (self.width - draw_w) / 2,
                body_top - draw_h,
                width=draw_w,
                height=draw_h,
                mask="auto",
            )
            body_top -= draw_h + 18

        c.setFillColor(white)
        c.setFont("HeiseiKakuGo-W5", 10.5)
        y = body_top
        for line in split_japanese(body, 28):
            if y < 48:
                break
            c.drawString(31, y, line)
            y -= 17

        c.setFillColor(Color(1, 1, 1, alpha=0.55))
        c.setFont("HeiseiKakuGo-W5", 7)
        c.drawString(30, 28, footer)
        c.drawRightString(self.width - 30, 28, str(self.page))
        c.showPage()

    def save(self) -> None:
        self.c.save()


def generate_how_to_play() -> None:
    pdf = GuidePdf(OUT / "nine-verdicts-how-to-play.pdf", "実際の遊び方")
    pdf.add_page(
        "9人の審判",
        "救済者と執行者が、9人の運命を巡って対立する2人用ゲームです。\n"
        "情報を集め、生と死を操作し、高い裁定ボーナスを獲得しましょう。",
        image=APP_ICON,
    )
    pdf.add_page(
        "1. 陣営と得点",
        "救済者\n善人・中立を生、悪人を死にすると得点。\n\n"
        "執行者\n善人・中立を死、悪人を生にすると得点。\n\n"
        "確定時の人物属性と最終状態により、得点する陣営が決まります。",
        accent=BLUE,
    )
    pdf.add_page(
        "2. 盤面と秘密情報",
        "盤面はA1〜C3の9人です。\n"
        "各属性は善人3・悪人3・中立3。\n"
        "自分側の手前3人は開始時から自分だけ確認できます。\n"
        "相手の初期情報やEYEの結果は表示されません。",
        image=GAME_SHOT,
    )
    pdf.add_page(
        "3. LIFE / DEATH",
        "LIFEは「生」、DEATHは「死」の履歴チップを人物へ置きます。\n\n"
        "同じ裁定が続くと確定。\n"
        "異なる裁定が続いても3回目で必ず確定します。\n\n"
        "例：生 → 死 → 生 ＝ 生存確定",
        accent=GREEN,
    )
    pdf.add_page(
        "4. EYE / JUDGE",
        "EYE\n未確定人物の属性を自分だけ確認します。相手には対象だけが伝わります。\n\n"
        "JUDGE\n各プレイヤー1回。未介入の審議中人物を即時確定します。"
        "実行前に対象を確認してください。",
        accent=PURPLE,
    )
    pdf.add_page(
        "5. 逆属性アクション",
        "救済者はDEATHを1回だけ使用できます。\n"
        "執行者はLIFEを1回だけ使用できます。\n\n"
        "ボタンのSPECIAL ●1が残数です。使用後はSPECIAL ●0となります。",
        accent=RED,
    )
    pdf.add_page(
        "6. 裁定ボーナス",
        "ボーナスは1〜9を1枚ずつ使用します。\n"
        "最初の値は両者に公開。\n"
        "2枚目以降は、直前の確定者ではない側だけが次の値を知ります。\n\n"
        "未来の順番は非公開です。9人確定後、合計得点の高い陣営が勝利します。",
        accent=GOLD,
    )
    pdf.save()


def generate_tutorial_guide() -> None:
    pdf = GuidePdf(OUT / "nine-verdicts-tutorial.pdf", "操作チュートリアル")
    pdf.add_page(
        "操作チュートリアル",
        "ホーム画面の「チュートリアル」から、実際の盤面を操作して学べます。\n"
        "所要時間は約3〜5分です。",
        image=TUTORIAL_SHOT,
    )
    steps = [
        ("STEP 1　初期情報", "あなたは救済者です。A3・B3・C3の正体が最初から見えます。"),
        ("STEP 2　EYE", "指定された未知人物を選び、EYEで正体を確認します。結果は自分だけの情報です。"),
        ("STEP 3　LIFE", "既知の善人B3へLIFEを使用します。カード下部に「生」チップが追加されます。"),
        ("STEP 4　相手の介入", "CPUが同じB3へDEATH。履歴は「生」「死」となり、まだ確定しません。"),
        ("STEP 5　確定", "もう一度LIFE。3回目の裁定によりB3が生存確定し、ボーナスが加点されます。"),
        ("STEP 6　JUDGE", "未介入人物へ1回限定のJUDGEを使用します。確認画面で対象を確認して実行します。"),
        ("STEP 7　切り札", "救済者のSPECIAL DEATHを体験します。使えるのはゲーム中1回だけです。"),
    ]
    colors = [BLUE, PURPLE, GREEN, RED, GOLD, GOLD, RED]
    for (heading, body), color in zip(steps, colors):
        pdf.add_page(heading, body, accent=color)
    pdf.add_page(
        "チュートリアル完了",
        "情報 → 推理 → LIFE/DEATHで介入 → JUDGEで確定。\n\n"
        "ホームへ戻り、CPU対戦で実戦を始めましょう。",
        image=GAME_SHOT,
    )
    pdf.save()


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    src = image.convert("RGB")
    ratio = max(size[0] / src.width, size[1] / src.height)
    resized = src.resize(
        (round(src.width * ratio), round(src.height * ratio)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size=size)


def video_slide(
    heading: str,
    lines: list[str],
    *,
    accent: str,
    screenshot: Path | None = None,
) -> Image.Image:
    frame = Image.new("RGB", (720, 1280), BG)
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle((30, 30, 690, 1250), 26, outline=GOLD, width=3)
    draw.text((58, 66), heading, font=font(43), fill=accent)
    draw.line((58, 128, 662, 128), fill=accent, width=3)

    y = 170
    if screenshot:
        shot = Image.open(screenshot).convert("RGB")
        shot.thumbnail((390, 740), Image.Resampling.LANCZOS)
        x = (720 - shot.width) // 2
        frame.paste(shot, (x, y))
        y += shot.height + 28

    for line in lines:
        draw.text((62, y), line, font=font(28), fill="white")
        y += 48
    draw.text((62, 1192), "9人の審判  /  NINE VERDICTS", font=font(20), fill=GOLD)
    return frame


def generate_video() -> None:
    slides = [
        video_slide(
            "9人の審判",
            ["実際のゲーム画面で見る", "約30秒 プレイガイド"],
            accent=GOLD,
            screenshot=GAME_SHOT,
        ),
        video_slide(
            "1. あなたは救済者",
            ["善人・中立 → 生", "悪人 → 死", "相手は執行者です"],
            accent=BLUE,
        ),
        video_slide(
            "2. まず情報を読む",
            ["手前3人は開始時から既知", "未知人物はEYEで確認", "結果は相手に見えません"],
            accent=PURPLE,
            screenshot=TUTORIAL_SHOT,
        ),
        video_slide(
            "3. 生と死を積み重ねる",
            ["LIFE → 生チップ", "DEATH → 死チップ", "3回目の裁定で必ず確定"],
            accent=GREEN,
            screenshot=GAME_SHOT,
        ),
        video_slide(
            "4. JUDGE",
            ["各プレイヤー1回", "未介入人物を即時確定", "確認画面で対象を再確認"],
            accent=GOLD,
        ),
        video_slide(
            "5. 一度だけの切り札",
            ["救済者：SPECIAL DEATH", "執行者：SPECIAL LIFE", "高いボーナスを狙って使う"],
            accent=RED,
        ),
        video_slide(
            "6. 裁定ボーナス",
            ["最初だけ両者に公開", "次の値は片方だけが知る", "未来の順番は非公開"],
            accent=GOLD,
        ),
        video_slide(
            "実戦を始めよう",
            ["CPU対戦でルールを確認", "チュートリアルは3〜5分", "perusonao.github.io/nine-verdicts/"],
            accent=BLUE,
            screenshot=GAME_SHOT,
        ),
    ]
    output = OUT / "nine-verdicts-gameplay.mp4"
    writer = imageio.get_writer(
        output,
        fps=12,
        codec="libx264",
        quality=7,
        pixelformat="yuv420p",
        ffmpeg_log_level="warning",
    )
    for slide in slides:
        frame = numpy.asarray(slide)
        for _ in range(36):
            writer.append_data(frame)
    writer.close()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    generate_how_to_play()
    generate_tutorial_guide()
    generate_video()
    print(f"Generated downloads in {OUT}")


if __name__ == "__main__":
    main()
