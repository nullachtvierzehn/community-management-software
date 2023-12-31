import logging

from . import app

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format=logging.BASIC_FORMAT, style="%")

with app.open():
    # FIXME: must be restarted when database shuts down
    app.run_worker(wait=True)
