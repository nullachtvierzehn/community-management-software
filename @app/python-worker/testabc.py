import os

from dotenv import load_dotenv
from procrastinate import App, AiopgConnector

load_dotenv()
app = App(
    connector=AiopgConnector(
        host=os.getenv("DATABASE_HOST"),
        user=os.getenv("DATABASE_OWNER"),
        password=os.getenv("DATABASE_OWNER_PASSWORD"),
    )
)


@app.task
def test():
    return "Hallo Welt"
