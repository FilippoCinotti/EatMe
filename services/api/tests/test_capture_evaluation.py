import unittest
from eatme.capture_evaluation import evaluate_captures


class CaptureEvaluationCase(unittest.TestCase):
    def test_reference_metrics_measure_errors_and_missing_observations(self):
        result = evaluate_captures([{'reference_type': 'receipt', 'predicted_type': 'food_photo',
            'reference_items': [{'food_id': 'tomato', 'quantity': '500', 'unit': 'g'}, {'food_id': 'milk', 'quantity': '1000', 'unit': 'ml'}],
            'predicted_items': [{'food_id': 'tomato', 'quantity': '400', 'unit': 'g'}, {'food_id': 'milk', 'quantity': '1', 'unit': 'pcs'}, {'food_id': None}],
            'corrected_items': [0, 1], 'completed': True}])
        self.assertEqual(result['classification_accuracy'], 0)
        self.assertEqual(result['ingredient_precision'], 2 / 3)
        self.assertEqual(result['ingredient_recall'], 1)
        self.assertEqual(result['unit_error_rate'], .5)
        self.assertEqual(result['quantity_mean_relative_error'], .2)
        self.assertEqual(result['quantity_samples'], 1)
        self.assertEqual(result['completion_rate'], 1)
        self.assertIsNone(evaluate_captures([])['completion_rate'])
        self.assertIsNone(evaluate_captures([{'predicted_items': []}])['quantity_mean_relative_error'])

    def test_repeated_items_are_not_overmatched(self):
        result = evaluate_captures([{'reference_items': [{'food_id': 'egg', 'quantity': '1', 'unit': 'pcs'}],
            'predicted_items': [{'food_id': 'egg', 'quantity': '1', 'unit': 'pcs'}] * 2}])
        self.assertEqual(result['ingredient_recall'], 1)
        self.assertEqual(result['ingredient_precision'], .5)


if __name__ == '__main__':
    unittest.main()
