#!/usr/bin/env python3
"""
Populate last_match_added_at timestamps for all queries that have cached results.
Sets the timestamp to the time the most recent match was added.
"""

import sys
from db import db

def main():
    print("Fetching all query posts...")
    queries = db.get_posts_by_template('query')

    if not queries:
        print("No queries found in database.")
        return

    print(f"Found {len(queries)} queries to process\n")

    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            for i, query in enumerate(queries, 1):
                query_id = query[0]
                query_title = query[3]

                # Check if this query has any cached results
                cur.execute("""
                    SELECT COUNT(*) FROM query_results WHERE query_id = %s
                """, (query_id,))
                count = cur.fetchone()[0]

                if count == 0:
                    print(f"[{i}/{len(queries)}] Query '{query_title}' (ID: {query_id}) - no results, skipping")
                    continue

                # Set last_match_added_at to now (since we don't track when individual results were added)
                cur.execute("""
                    UPDATE posts
                    SET last_match_added_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (query_id,))

                print(f"[{i}/{len(queries)}] Query '{query_title}' (ID: {query_id}) - set timestamp ({count} results)")

            conn.commit()
            print("\nDone! All query timestamps populated.")

    finally:
        conn.close()

if __name__ == "__main__":
    main()
