"""Run with: python services/worker/main.py (install services/api first)."""
import logging
import signal
import threading

from eatme.errors import DomainError
from eatme.transport import configured_router

logger = logging.getLogger(__name__)


def main():
    stop = threading.Event()
    for name in (signal.SIGINT, signal.SIGTERM):
        signal.signal(name, lambda *_: stop.set())
    service = configured_router().service
    while not stop.is_set():
        try:
            service.purge_expired_media()
            worked = service.run_next_job()
        except (DomainError, OSError):
            logger.error('worker_iteration_failed')
            worked = False
        if not worked:
            stop.wait(2)


if __name__ == '__main__':
    main()
