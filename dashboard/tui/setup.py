#!/usr/bin/env python3
"""Setup for gasclaw-tui"""

from setuptools import setup, find_packages

setup(
    name="gasclaw-tui",
    version="1.0.0",
    description="AI-Optimized Terminal Interface for Gasclaw Management",
    author="Gasclaw Team",
    py_modules=["gasclaw"],
    install_requires=[
        "click>=8.0.0",
        "requests>=2.28.0",
        "rich>=13.0.0",
        "pyyaml>=6.0",
    ],
    entry_points={
        "console_scripts": [
            "gasclaw=gasclaw:cli",
        ],
    },
    python_requires=">=3.8",
)
