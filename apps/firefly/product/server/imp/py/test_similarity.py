#!/usr/bin/env python3
"""
Test similarity scores between specific phrases.
Usage: python3 test_similarity.py "query" "text1" "text2" ...
"""

import sys
import embeddings
import torch
import numpy as np

def compute_similarity(query_emb, text_emb):
    """Compute cosine similarity"""
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    query_tensor = torch.tensor(query_emb, device=device, dtype=torch.float32).unsqueeze(0)
    text_tensor = torch.tensor(text_emb, device=device, dtype=torch.float32).unsqueeze(0)
    score = torch.nn.functional.cosine_similarity(query_tensor, text_tensor)
    return float(score.cpu().numpy()[0])

def test_similarity(query, texts):
    """Test similarity between query and multiple texts"""
    print(f"\nQuery: '{query}'")
    print("=" * 80)

    model = embeddings.get_model()

    # Encode query
    query_emb = model.encode([query], convert_to_numpy=True)[0]

    # Encode and compare each text
    results = []
    for text in texts:
        text_emb = model.encode([text], convert_to_numpy=True)[0]
        score = compute_similarity(query_emb, text_emb)
        results.append((score, text))

    # Sort by score
    results.sort(reverse=True)

    # Print results
    for score, text in results:
        print(f"[{score:.4f}] {text}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 test_similarity.py 'query' 'text1' 'text2' ...")
        sys.exit(1)

    query = sys.argv[1]
    texts = sys.argv[2:]

    test_similarity(query, texts)
