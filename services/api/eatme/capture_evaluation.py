"""Offline evaluation of reviewed reference captures; never calls an AI provider."""
from collections import Counter
from decimal import Decimal, InvalidOperation


def _number(value):
    try:
        value = Decimal(str(value))
        return value if value.is_finite() and value >= 0 else None
    except (InvalidOperation, TypeError, ValueError):
        return None


def evaluate_captures(cases):
    """Return measured metrics and denominators, leaving unobserved metrics null.

    Reference/prediction items use canonical food_id, quantity and unit. Repeated
    items are matched in occurrence order within canonical ID; mismatched units
    are counted as errors and excluded from numeric quantity comparisons.
    Completion/corrections require observed workflow outcomes, not guesses.
    """
    classification_n = classification_ok = expected_n = predicted_n = matched_n = 0
    unit_n = unit_errors = quantity_n = corrections_n = corrected_n = completed_n = observed_n = 0
    relative_error = Decimal(0)
    for case in cases:
        if 'predicted_type' in case and 'reference_type' in case:
            classification_n += 1
            classification_ok += case['predicted_type'] == case['reference_type']
        references = {}
        for item in case.get('reference_items', []):
            references.setdefault(item.get('food_id'), []).append(item)
        predictions = case.get('predicted_items', [])
        expected_n += sum(len(items) for items in references.values())
        predicted_n += len(predictions)
        occurrences = Counter()
        for prediction in predictions:
            food = prediction.get('food_id')
            index = occurrences[food]
            occurrences[food] += 1
            if not food or index >= len(references.get(food, [])):
                continue
            reference = references[food][index]
            matched_n += 1
            unit_n += 1
            if prediction.get('unit') != reference.get('unit'):
                unit_errors += 1
                continue
            predicted = _number(prediction.get('quantity'))
            expected = _number(reference.get('quantity'))
            if predicted is not None and expected:
                quantity_n += 1
                relative_error += abs(predicted - expected) / expected
        if 'corrected_items' in case:
            corrections_n += len(predictions)
            corrected_n += len(case['corrected_items'])
        if type(case.get('completed')) is bool:
            observed_n += 1
            completed_n += case['completed']
    return {
        'classification_accuracy': classification_ok / classification_n if classification_n else None,
        'classification_samples': classification_n,
        'ingredient_precision': matched_n / predicted_n if predicted_n else None,
        'ingredient_recall': matched_n / expected_n if expected_n else None,
        'unit_error_rate': unit_errors / unit_n if unit_n else None,
        'quantity_mean_relative_error': float(relative_error / quantity_n) if quantity_n else None,
        'quantity_samples': quantity_n,
        'correction_rate': corrected_n / corrections_n if corrections_n else None,
        'completion_rate': completed_n / observed_n if observed_n else None,
        'completion_samples': observed_n,
    }
