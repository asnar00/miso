"""
Embedding generation and storage for semantic search.
Uses sentence-transformers with all-mpnet-base-v2 model.
"""

import os
import re
import numpy as np
import torch
from typing import List, Optional

# Set offline mode BEFORE importing sentence_transformers
# This prevents it from trying to connect to HuggingFace
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '1'

from sentence_transformers import SentenceTransformer

# Global model instance (loaded once on first use)
_model = None

def get_model():
    """Get or initialize the sentence transformer model"""
    global _model
    if _model is None:
        # Use MPS (Metal Performance Shaders) for M2 GPU acceleration
        device = 'mps' if torch.backends.mps.is_available() else 'cpu'
        print(f"[EMBEDDINGS] Loading all-mpnet-base-v2 model on {device}...")
        _model = SentenceTransformer('all-mpnet-base-v2', device=device)
        print(f"[EMBEDDINGS] Model loaded successfully")
    return _model

def chunk_text(text: str) -> List[str]:
    """
    Split text into fragments on punctuation.

    Args:
        text: Input text to chunk

    Returns:
        List of non-empty text fragments
    """
    # Split on any punctuation: . , ; : ! ?
    fragments = re.split(r'[.,;:!?]+', text)

    # Strip whitespace and filter empty fragments
    fragments = [f.strip() for f in fragments if f.strip()]

    return fragments

# Quantization functions removed - using float32 for better search quality

def generate_embeddings(post_id: int, title: str, summary: str, body: str) -> bool:
    """
    Generate and save embeddings for all fragments of a post.

    Args:
        post_id: Database ID of the post
        title: Post title
        summary: Post summary
        body: Post body text

    Returns:
        True if successful, False otherwise
    """
    try:
        model = get_model()

        # Build fragment list
        fragments = [title, summary]
        body_fragments = chunk_text(body)
        fragments.extend(body_fragments)

        print(f"[EMBEDDINGS] Generating embeddings for post {post_id}: {len(fragments)} fragments")

        # Generate embeddings for all fragments in one batch
        embeddings_float = model.encode(fragments, convert_to_numpy=True)

        # Ensure data directory exists
        os.makedirs('data/embeddings', exist_ok=True)

        # Save to file as float32
        filepath = f'data/embeddings/post_{post_id}.npy'
        np.save(filepath, embeddings_float.astype(np.float32))

        print(f"[EMBEDDINGS] Saved embeddings to {filepath}: shape {embeddings_float.shape}")
        return True

    except Exception as e:
        print(f"[EMBEDDINGS] Error generating embeddings for post {post_id}: {e}")
        return False

def load_embeddings(post_id: int) -> Optional[np.ndarray]:
    """
    Load embeddings from disk.

    Args:
        post_id: Database ID of the post

    Returns:
        Float32 numpy array of shape (num_fragments, 768), or None if not found
    """
    try:
        filepath = f'data/embeddings/post_{post_id}.npy'
        if os.path.exists(filepath):
            embeddings = np.load(filepath)
            return embeddings
        else:
            return None
    except Exception as e:
        print(f"[EMBEDDINGS] Error loading embeddings for post {post_id}: {e}")
        return None

def delete_embeddings(post_id: int) -> bool:
    """
    Delete embedding file for a post.

    Args:
        post_id: Database ID of the post

    Returns:
        True if deleted or didn't exist, False on error
    """
    try:
        filepath = f'data/embeddings/post_{post_id}.npy'
        if os.path.exists(filepath):
            os.remove(filepath)
            print(f"[EMBEDDINGS] Deleted embeddings for post {post_id}")
        return True
    except Exception as e:
        print(f"[EMBEDDINGS] Error deleting embeddings for post {post_id}: {e}")
        return False
