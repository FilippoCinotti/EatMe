"""Run with: python -m eatme.worker."""
import logging
import signal
import threading
import time

from eatme.errors import DomainError
from eatme.transport import configured_router

logger = logging.getLogger(__name__)


def main():
    stop = threading.Event()
    for name in (signal.SIGINT, signal.SIGTERM):
        signal.signal(name, lambda *_: stop.set())
    service = configured_router().service
    last_cleanup = 0.0
    while not stop.is_set():
        try:
            if time.monotonic() - last_cleanup > 60:
                service.purge_expired_media()
                service.retry_account_deletions()
                last_cleanup = time.monotonic()
            worked = service.run_next_job()
        except (DomainError, OSError):
            logger.error('worker_iteration_failed')
            worked = False
        if not worked:
            stop.wait(2)


if __name__ == '__main__':
    main()
