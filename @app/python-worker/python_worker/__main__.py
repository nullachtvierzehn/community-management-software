import logging

from . import app

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format=logging.BASIC_FORMAT, style="%")

async def main():
    async with app.open_async():
        await app.run_worker_async(wait=True)

with app.open():
    # FIXME: must be restarted when database shuts down
    app.run_worker(wait=True)
