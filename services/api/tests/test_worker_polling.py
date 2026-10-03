import unittest
from unittest.mock import Mock, patch

from eatme.worker import run_worker


class WorkerPollingTests(unittest.TestCase):
    def run_outcomes(self, outcomes):
        service = Mock()
        service.run_next_job.side_effect = outcomes
        stop = Mock()
        stop.is_set.side_effect = [False] * len(outcomes) + [True]
        with patch('eatme.worker.time.monotonic', return_value=100):
            run_worker(service, stop)
        return service, [call.args[0] for call in stop.wait.call_args_list]

    def test_idle_polling_is_bounded_and_active_work_resets_delay(self):
        service, waits = self.run_outcomes([False] * 7 + [True, True, False])
        self.assertEqual(waits, [2, 4, 8, 16, 30, 30, 30, 2])
        self.assertEqual(service.run_next_job.call_count, 10)
        service.purge_expired_media.assert_called_once()
        service.cleanup_dinner_guests.assert_called_once()
        service.retry_account_deletions.assert_called_once()

    def test_shutdown_during_idle_wait_does_not_poll_again(self):
        service = Mock()
        service.run_next_job.return_value = False
        import threading
        stop = threading.Event()
        with patch.object(stop, 'wait', side_effect=lambda _: stop.set()):
            run_worker(service, stop)
        service.run_next_job.assert_called_once()
