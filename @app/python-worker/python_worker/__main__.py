import logging

from . import app

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format=logging.BASIC_FORMAT, style="%")

with app.open():
    app.run_worker(wait=True)
