"""Regression tests for calculator operations."""

import unittest

from calculator import add, multiply, subtract


class CalculatorTests(unittest.TestCase):
    """Check arithmetic with positive, negative and fractional values."""

    def test_add(self):
        """Addition supports numbers with different signs."""
        self.assertEqual(add(2, 3), 5)
        self.assertEqual(add(-2, 3), 1)
        self.assertAlmostEqual(add(0.1, 0.2), 0.3)

    def test_subtract(self):
        """Subtraction preserves operand order."""
        self.assertEqual(subtract(7, 2), 5)
        self.assertEqual(subtract(2, 7), -5)
        self.assertEqual(subtract(-2, -3), 1)

    def test_multiply(self):
        """Multiplication supports zero and negative factors."""
        self.assertEqual(multiply(6, 7), 42)
        self.assertEqual(multiply(0, 100), 0)
        self.assertEqual(multiply(-3, 4), -12)


if __name__ == "__main__":
    unittest.main()
