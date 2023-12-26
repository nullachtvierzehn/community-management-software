from pathlib import Path
from uuid import uuid4
import os

from psycopg2.extras import Json
from aiopg import IsolationLevel, Transaction
from pypdfium2 import PdfDocument
from dotenv import load_dotenv
from procrastinate import App, AiopgConnector
import PIL

load_dotenv()

RENDER_PIXELS = 1920.0

if not (UPLOAD_FOLDER := os.getenv("UPLOAD_FOLDER")):
    raise ValueError(
        "Please provide the absolute path to stored uplaods in UPLOAD_FOLDER"
    )


connector = AiopgConnector(
    host=os.getenv("DATABASE_HOST"),
    user=os.getenv("DATABASE_OWNER"),
    dbname=os.getenv("DATABASE_NAME"),
    password=os.getenv("DATABASE_OWNER_PASSWORD"),
    options="-c search_path=procrastinate",
    enable_json=True,
    enable_uuid=True,
)

app = App(connector=connector)
app.open()


@app.task(name="test")
async def test(name="Timo"):
    return f"Hallo {name}!"


@app.task(name="process_pdf")
async def process_pdf(file_id: str):
    async with connector.pool.acquire() as con, con.cursor() as cur, Transaction(
        cur, IsolationLevel.read_committed
    ) as tr:
        # fetch file from database
        await cur.execute("SELECT * FROM app_public.files WHERE id = %s", (file_id,))
        file_row = await cur.fetchone()

        # fetch file from upload folder
        file_path = Path(UPLOAD_FOLDER).joinpath(str(file_row.get("id")))
        pdf = PdfDocument(file_path)

        # create thumbnail
        first_page = pdf.get_page(0)
        thumbnail = first_page.render(
            scale=RENDER_PIXELS / max(first_page.get_size())
        ).to_pil()
        thumbnail_id = str(uuid4())
        thumbnail_path = Path(UPLOAD_FOLDER).joinpath(thumbnail_id)

        with open(thumbnail_path, "wb") as thumbnail_file:
            thumbnail.save(thumbnail_file, format="WebP", quality=85)

        await cur.execute(
            """
            INSERT INTO app_public.files (id, uploaded_bytes, total_bytes, mime_type, contributor_id) 
            VALUES (%(id)s, %(bytes)s, %(bytes)s, %(mime_type)s, %(contributor_id)s)
            RETURNING *
            """,
            dict(
                id=thumbnail_id,
                bytes=thumbnail_path.stat().st_size,
                mime_type="image/webp",
                contributor_id=file_row.get("contributor_id"),
            ),
        )

        # collect text
        plain_text = "\n".join(p.get_textpage().get_text_range() for p in pdf)
        plain_text = plain_text.replace("\x00", "")
        metadata = pdf.get_metadata_dict(skip_empty=True)

        await cur.execute(
            """
            INSERT INTO app_public.pdf_files (id, title, pages, metadata, content_as_plain_text, thumbnail_id)
            VALUES (%(id)s, %(title)s, %(pages)s, %(metadata)s, %(plain_text)s, %(thumbnail_id)s)
            ON CONFLICT (id) DO UPDATE SET
                title = EXCLUDED.title, 
                pages = EXCLUDED.pages, 
                metadata = EXCLUDED.metadata, 
                content_as_plain_text = EXCLUDED.content_as_plain_text, 
                thumbnail_id = EXCLUDED.thumbnail_id
            RETURNING *
            """,
            dict(
                id=file_row.get("id"),
                title=metadata.get("Title", file_row.get("filename")),
                pages=len(pdf),
                metadata=Json(metadata),
                plain_text=plain_text,
                thumbnail_id=thumbnail_id,
            ),
        )
