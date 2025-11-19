#!/usr/bin/env python3
"""
Test Claude API connectivity and credits.
Requires: pip install anthropic
Set ANTHROPIC_API_KEY environment variable or pass as argument.
"""

import sys
import os
import config  # Load .env file

def test_claude_api(api_key=None):
    """Test Claude API connection and check credits"""

    # Get API key
    if api_key is None:
        api_key = config.get_anthropic_api_key()

    if not api_key:
        print("❌ No API key found!")
        print("Set ANTHROPIC_API_KEY in .env file or environment variable")
        print("Or pass as argument: python3 test_claude_api.py [API_KEY]")
        print("\nCreate .env file with:")
        print("  ANTHROPIC_API_KEY=sk-ant-...")
        return False

    print("=" * 80)
    print("CLAUDE API TEST")
    print("=" * 80)

    # Mask API key for display
    masked_key = api_key[:8] + "..." + api_key[-4:] if len(api_key) > 12 else "***"
    print(f"\n✓ API Key found: {masked_key}")

    # Try importing anthropic
    try:
        import anthropic
        print(f"✓ anthropic library installed (version {anthropic.__version__})")
    except ImportError:
        print("❌ anthropic library not installed")
        print("Install with: pip install anthropic")
        return False

    # Test API call
    print("\n📡 Testing API connection...")
    try:
        client = anthropic.Anthropic(api_key=api_key)

        # Make a minimal test call
        message = client.messages.create(
            model="claude-3-5-haiku-20241022",
            max_tokens=50,
            messages=[
                {"role": "user", "content": "Respond with just the word 'SUCCESS' if you can read this."}
            ]
        )

        response_text = message.content[0].text

        print(f"✓ API call successful!")
        print(f"  Model: {message.model}")
        print(f"  Response: {response_text}")
        print(f"  Input tokens: {message.usage.input_tokens}")
        print(f"  Output tokens: {message.usage.output_tokens}")

        # Calculate approximate cost (as of 2024 pricing)
        # Claude 3.5 Sonnet: $3/MTok input, $15/MTok output
        input_cost = (message.usage.input_tokens / 1_000_000) * 3.0
        output_cost = (message.usage.output_tokens / 1_000_000) * 15.0
        total_cost = input_cost + output_cost

        print(f"  Cost: ${total_cost:.6f}")

        print("\n" + "=" * 80)
        print("✅ CLAUDE API IS WORKING!")
        print("=" * 80)
        print("\nNote: Credits/balance cannot be checked via API.")
        print("Check your balance at: https://console.anthropic.com/settings/billing")

        return True

    except anthropic.AuthenticationError as e:
        print(f"❌ Authentication failed: {e}")
        print("Check your API key at: https://console.anthropic.com/settings/keys")
        return False

    except anthropic.RateLimitError as e:
        print(f"❌ Rate limit exceeded: {e}")
        return False

    except anthropic.APIError as e:
        print(f"❌ API error: {e}")
        return False

    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    api_key = sys.argv[1] if len(sys.argv) > 1 else None
    success = test_claude_api(api_key)
    sys.exit(0 if success else 1)
