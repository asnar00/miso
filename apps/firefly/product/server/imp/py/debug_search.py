#!/usr/bin/env python3
"""
Debug search to show fragment-level scores.
Usage: python3 debug_search.py "query text"
"""

import sys
import numpy as np
import torch
import embeddings
from db import db

def load_all_embeddings():
    """Load all post embeddings from disk"""
    import os
    embedding_files = []
    for filename in os.listdir('data/embeddings'):
        if filename.startswith('post_') and filename.endswith('.npy'):
            post_id = int(filename.replace('post_', '').replace('.npy', ''))
            embedding_files.append((post_id, f'data/embeddings/{filename}'))

    embedding_files.sort()

    all_embeddings = []
    index = []

    for post_id, filepath in embedding_files:
        emb = np.load(filepath)
        all_embeddings.append(emb)
        for frag_idx in range(emb.shape[0]):
            index.append((post_id, frag_idx))

    all_embeddings = np.vstack(all_embeddings)
    return all_embeddings, index

def compute_similarity_gpu(query_emb_float, all_embeddings_float):
    """Compute cosine similarity on GPU"""
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    query_tensor = torch.tensor(query_emb_float, device=device, dtype=torch.float32).unsqueeze(0)
    all_tensor = torch.tensor(all_embeddings_float, device=device, dtype=torch.float32)
    scores = torch.nn.functional.cosine_similarity(query_tensor, all_tensor)
    return scores.cpu().numpy()

def get_post_fragments(post_id):
    """Get the fragments for a post"""
    post = db.get_post_by_id(post_id)
    if not post:
        return []

    fragments = [post['title'], post['summary'] or ""]
    body_fragments = embeddings.chunk_text(post['body'] or "")
    fragments.extend(body_fragments)
    return fragments

def debug_search(query):
    """Debug search with detailed fragment scoring"""
    print(f"\n{'='*80}")
    print(f"SEARCH DEBUG REPORT")
    print(f"Query: '{query}'")
    print(f"{'='*80}\n")

    # Load all embeddings
    all_embeddings, index = load_all_embeddings()
    print(f"Loaded {len(index)} fragments from {len(set(pid for pid, _ in index))} posts\n")

    # Generate query embedding
    model = embeddings.get_model()
    query_emb = model.encode([query], convert_to_numpy=True)[0]

    # Compute similarity scores
    scores = compute_similarity_gpu(query_emb, all_embeddings)

    # Build detailed results
    post_fragments = {}
    for i, (post_id, frag_idx) in enumerate(index):
        if post_id not in post_fragments:
            post_fragments[post_id] = []
        post_fragments[post_id].append({
            'frag_idx': frag_idx,
            'score': float(scores[i])
        })

    # Get post details and compute max scores
    post_results = []
    for post_id, fragments in post_fragments.items():
        post = db.get_post_by_id(post_id)
        if not post or post.get('template_name') == 'query':
            continue

        max_score = max(f['score'] for f in fragments)
        post_results.append({
            'id': post_id,
            'title': post['title'],
            'max_score': max_score,
            'fragments': fragments,
            'post': post
        })

    # Sort by max score
    post_results.sort(key=lambda x: x['max_score'], reverse=True)

    # Print top 10 results with fragment details
    print("TOP 10 RESULTS WITH FRAGMENT BREAKDOWN:\n")

    for rank, result in enumerate(post_results[:10], 1):
        post_id = result['id']
        title = result['title']
        max_score = result['max_score']

        print(f"{rank}. [{max_score:.4f}] Post {post_id}: {title}")
        print(f"   {'─'*76}")

        # Get the actual fragment text
        fragment_texts = get_post_fragments(post_id)

        # Sort fragments by score
        sorted_fragments = sorted(result['fragments'], key=lambda x: x['score'], reverse=True)

        # Show top 5 fragments
        print(f"   Top scoring fragments:")
        for i, frag_info in enumerate(sorted_fragments[:5], 1):
            frag_idx = frag_info['frag_idx']
            frag_score = frag_info['score']

            if frag_idx < len(fragment_texts):
                frag_text = fragment_texts[frag_idx]
                # Truncate long fragments
                if len(frag_text) > 80:
                    frag_text = frag_text[:77] + "..."

                # Mark which fragment type
                if frag_idx == 0:
                    frag_type = "TITLE"
                elif frag_idx == 1:
                    frag_type = "SUMMARY"
                else:
                    frag_type = f"BODY[{frag_idx-2}]"

                marker = "★" if frag_score == max_score else " "
                print(f"   {marker} [{frag_score:.4f}] {frag_type:12} \"{frag_text}\"")

        print()

    # Summary statistics
    print(f"\n{'='*80}")
    print("SCORE STATISTICS:")
    print(f"{'='*80}")
    all_scores = [r['max_score'] for r in post_results]
    print(f"Highest score: {max(all_scores):.4f}")
    print(f"Lowest score:  {min(all_scores):.4f}")
    print(f"Mean score:    {np.mean(all_scores):.4f}")
    print(f"Median score:  {np.median(all_scores):.4f}")
    print(f"Std deviation: {np.std(all_scores):.4f}")
    print(f"\nResults above 0.25 threshold: {len([s for s in all_scores if s >= 0.25])}")
    print(f"Total results: {len(all_scores)}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 debug_search.py 'query text'")
        sys.exit(1)

    query = ' '.join(sys.argv[1:])

    # Initialize database
    db.initialize_pool()

    debug_search(query)
