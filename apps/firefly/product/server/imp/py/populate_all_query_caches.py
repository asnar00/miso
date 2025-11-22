#!/usr/bin/env python3
"""
Populate query results cache for all existing queries.
Runs the full search (RAG + LLM) for each query against all posts.
"""

import sys
from db import db
from app import populate_initial_query_results

def main():
    print("Fetching all query posts...")
    queries = db.get_posts_by_template('query')

    if not queries:
        print("No queries found in database.")
        return

    print(f"Found {len(queries)} queries to process\n")

    for i, query in enumerate(queries, 1):
        # query is a tuple: (id, user_id, parent_id, title, summary, body, image_url, created_at, timezone, location_tag, ai_generated, template_name, has_new_matches)
        query_id = query[0]
        query_title = query[3]

        print(f"[{i}/{len(queries)}] Processing query '{query_title}' (ID: {query_id})...")

        # Clear existing results first
        db.clear_query_results(query_id)
        print(f"  Cleared existing results")

        # Run full search
        try:
            populate_initial_query_results(query_id)

            # Check how many results were found
            results = db.get_query_results(query_id)
            print(f"  ✓ Found {len(results)} matching posts")

            # Clear the has_new_matches flag since we just populated
            db.set_has_new_matches(query_id, False)

        except Exception as e:
            print(f"  ✗ Error: {e}")
            continue

        print()

    print("Done! All query caches populated.")

if __name__ == "__main__":
    main()
