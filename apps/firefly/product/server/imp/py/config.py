"""
Configuration management for Firefly server.
Loads settings from .env file if present.
"""

import os
from typing import Optional

def load_env_file(filepath: str = '.env'):
    """
    Load environment variables from .env file.
    Format: KEY=value (one per line)
    Lines starting with # are comments.
    """
    if not os.path.exists(filepath):
        return

    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()

            # Skip comments and empty lines
            if not line or line.startswith('#'):
                continue

            # Parse KEY=value
            if '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip()

                # Remove quotes if present
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                elif value.startswith("'") and value.endswith("'"):
                    value = value[1:-1]

                # Set environment variable
                os.environ[key] = value

def get_anthropic_api_key() -> Optional[str]:
    """Get Anthropic API key from environment"""
    return os.getenv('ANTHROPIC_API_KEY')

def get_config_value(key: str, default: Optional[str] = None) -> Optional[str]:
    """Get configuration value from environment"""
    return os.getenv(key, default)

# Load .env file on import
load_env_file()
