import unittest
from eatme.engine import contextual_recommendations


def candidate(identifier, *, minutes=30, expiry=(), available=1, total=2):
    return {'recipe': {'id': identifier, 'steps': ['cook']}, 'minutes': minutes,
            'score': 1, 'component_scores': {'availability': available / total},
            'use_soon_food_ids': list(expiry), 'available_count': available, 'ingredient_count': total}


class ContextualCase(unittest.TestCase):
    def test_scarce_candidates_are_reserved_for_distinct_categories(self):
        result = contextual_recommendations([
            candidate('quick', minutes=10), candidate('expiring', expiry=['tomato']), candidate('normal')])
        self.assertEqual([r['kind'] for r in result], ['for_you', 'use_soon', 'quick'])
        self.assertEqual([r['recommendation']['recipe']['id'] for r in result], ['normal', 'expiring', 'quick'])

    def test_limited_catalog_does_not_duplicate_or_invent_categories(self):
        self.assertEqual(contextual_recommendations([]), [])
        result = contextual_recommendations([candidate('one')])
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['kind'], 'for_you')
        self.assertEqual(len(contextual_recommendations([candidate('both', minutes=5, expiry=['a'])])), 1)

    def test_reasons_are_supported_by_ranking_evidence(self):
        result = contextual_recommendations([candidate('one', available=2)])
        self.assertEqual(result[0]['reasons'], [{'code': 'smart_reason_available'}, {'code': 'smart_reason_minutes', 'count': 30}])
        self.assertLessEqual(len(result[0]['reasons']), 2)


if __name__ == '__main__':
    unittest.main()
