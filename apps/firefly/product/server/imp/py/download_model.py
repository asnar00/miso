#!/usr/bin/env python3
"""
Download the multi-qa-mpnet-base-dot-v1 model to the HuggingFace cache.
Run this once before enabling offline mode.
"""

import os
import torch

# Temporarily allow online mode to download
if 'HF_HUB_OFFLINE' in os.environ:
    del os.environ['HF_HUB_OFFLINE']
if 'TRANSFORMERS_OFFLINE' in os.environ:
    del os.environ['TRANSFORMERS_OFFLINE']

from sentence_transformers import SentenceTransformer

def download_model():
    """Download the model to cache"""
    model_name = 'all-MiniLM-L6-v2'

    print(f"[DOWNLOAD] Starting download of {model_name}...")
    print(f"[DOWNLOAD] This may take a few minutes...")

    # Detect device
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    print(f"[DOWNLOAD] Using device: {device}")

    try:
        # Download and load model
        model = SentenceTransformer(model_name, device=device)
        print(f"[DOWNLOAD] Model loaded successfully!")

        # Test with a simple encoding
        test_text = "This is a test sentence."
        embedding = model.encode([test_text])
        print(f"[DOWNLOAD] Test encoding successful: {embedding.shape}")

        # Show cache location
        cache_dir = os.path.expanduser("~/.cache/huggingface/hub")
        print(f"[DOWNLOAD] Model cached at: {cache_dir}")

        # List model files
        model_path = f"{cache_dir}/models--sentence-transformers--{model_name}"
        if os.path.exists(model_path):
            print(f"[DOWNLOAD] Model directory exists: {model_path}")
            print(f"[DOWNLOAD] Contents:")
            for root, dirs, files in os.walk(model_path):
                level = root.replace(model_path, '').count(os.sep)
                indent = ' ' * 2 * level
                print(f"{indent}{os.path.basename(root)}/")
                subindent = ' ' * 2 * (level + 1)
                for file in files[:5]:  # Show first 5 files in each dir
                    print(f"{subindent}{file}")
                if len(files) > 5:
                    print(f"{subindent}... and {len(files) - 5} more files")

        print(f"\n[DOWNLOAD] ✅ Download complete! You can now enable offline mode.")

    except Exception as e:
        print(f"[DOWNLOAD] ❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    download_model()
