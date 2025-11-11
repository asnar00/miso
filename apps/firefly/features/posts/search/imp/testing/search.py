#!/usr/bin/env python3
"""
Command-line search tool for Firefly semantic search.

Usage:
    python3 search.py "your search query"
    python3 search.py "your search query" --limit 10
"""

import sys
import requests
import json

def search(query, limit=5, server="http://185.96.221.52:8080"):
    """
    Search for posts using semantic similarity.

    Args:
        query: Search query string
        limit: Maximum number of results (default: 5)
        server: Server URL (default: remote server)

    Returns:
        List of matching posts
    """
    try:
        response = requests.get(f"{server}/api/search", params={
            'q': query,
            'limit': limit
        })

        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error: {response.status_code} - {response.text}")
            return []
    except Exception as e:
        print(f"Error connecting to server: {e}")
        return []

def format_post(post, index):
    """Format a post for display"""
    score = post.get('relevance_score', 0.0)
    title = post.get('title', 'Untitled')
    summary = post.get('summary', '')
    body = post.get('body', '')

    # Build output
    lines = []
    lines.append(f"\n{'='*80}")
    lines.append(f"[{index}] {title} (relevance: {score:.3f})")
    lines.append(f"{'='*80}")

    if summary:
        lines.append(f"\nSummary: {summary}")

    if body:
        lines.append(f"\n{body}")

    return '\n'.join(lines)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 search.py \"your search query\" [--limit N]")
        print("Example: python3 search.py \"beach vacation\" --limit 3")
        sys.exit(1)

    # Parse arguments
    query = sys.argv[1]
    limit = 5

    # Check for --limit flag
    if len(sys.argv) > 2 and sys.argv[2] == '--limit':
        if len(sys.argv) > 3:
            limit = int(sys.argv[3])

    print(f"Searching for: \"{query}\"")
    print(f"Limit: {limit}")
    print()

    # Perform search
    results = search(query, limit)

    if not results:
        print("No results found.")
        return

    print(f"Found {len(results)} results:")

    # Display results
    for i, post in enumerate(results, 1):
        print(format_post(post, i))

    print(f"\n{'='*80}\n")

if __name__ == '__main__':
    main()
