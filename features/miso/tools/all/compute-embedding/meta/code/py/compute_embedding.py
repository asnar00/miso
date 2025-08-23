#!/usr/bin/env python3
"""
compute-embedding tool implementation
Computes SBERT embedding vectors for snippet files and stores them as JSON
"""

import os
import json
import hashlib
from pathlib import Path
from typing import List, Dict, Any
from sentence_transformers import SentenceTransformer

class ComputeEmbedding:
    def __init__(self, features_root: str = "features"):
        self.features_root = Path(features_root)
        self.model = SentenceTransformer('all-MiniLM-L6-v2')  # Fast SBERT model
        
    def get_snippet_hash(self, snippet_path: Path) -> str:
        """Compute hash of snippet content for change detection"""
        try:
            with open(snippet_path, 'r', encoding='utf-8') as f:
                content = f.read()
            return hashlib.md5(content.encode()).hexdigest()
        except Exception:
            return ""
    
    def get_meta_dir(self, snippet_path: Path) -> Path:
        """Get meta directory path for a snippet"""
        # Convert features/A/B/C.md -> features/A/B/C/meta
        relative_path = snippet_path.relative_to(self.features_root)
        stem = relative_path.with_suffix('')  # Remove .md
        return self.features_root / stem / "meta"
    
    def get_embedding_file(self, snippet_path: Path) -> Path:
        """Get embedding file path for a snippet"""
        meta_dir = self.get_meta_dir(snippet_path)
        return meta_dir / "embeddings.json"
    
    def get_hash_file(self, snippet_path: Path) -> Path:
        """Get hash file path for tracking changes"""
        meta_dir = self.get_meta_dir(snippet_path)
        return meta_dir / "content_hash.txt"
    
    def needs_update(self, snippet_path: Path) -> bool:
        """Check if snippet needs embedding update"""
        hash_file = self.get_hash_file(snippet_path)
        
        if not hash_file.exists():
            return True
            
        try:
            with open(hash_file, 'r') as f:
                stored_hash = f.read().strip()
            current_hash = self.get_snippet_hash(snippet_path)
            return stored_hash != current_hash
        except Exception:
            return True
    
    def compute_embeddings(self, snippet_path: Path) -> List[List[float]]:
        """Compute embeddings for each line of a snippet"""
        try:
            with open(snippet_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            # Remove empty lines and strip whitespace
            non_empty_lines = [line.strip() for line in lines if line.strip()]
            
            if not non_empty_lines:
                return []
            
            # Compute embeddings
            embeddings = self.model.encode(non_empty_lines)
            return embeddings.tolist()
            
        except Exception as e:
            print(f"Error computing embeddings for {snippet_path}: {e}")
            return []
    
    def save_embeddings(self, snippet_path: Path, embeddings: List[List[float]]):
        """Save embeddings and update hash"""
        meta_dir = self.get_meta_dir(snippet_path)
        meta_dir.mkdir(parents=True, exist_ok=True)
        
        # Save embeddings
        embedding_file = self.get_embedding_file(snippet_path)
        with open(embedding_file, 'w') as f:
            json.dump(embeddings, f, indent=2)
        
        # Update hash
        hash_file = self.get_hash_file(snippet_path)
        current_hash = self.get_snippet_hash(snippet_path)
        with open(hash_file, 'w') as f:
            f.write(current_hash)
    
    def find_all_snippets(self) -> List[Path]:
        """Find all .md files in features directory"""
        if not self.features_root.exists():
            return []
        
        return list(self.features_root.rglob("*.md"))
    
    def process_all_snippets(self):
        """Process all snippets, updating only changed ones"""
        snippets = self.find_all_snippets()
        
        updated_count = 0
        skipped_count = 0
        
        for snippet_path in snippets:
            print(f"Checking {snippet_path}...")
            
            if self.needs_update(snippet_path):
                print(f"  Computing embeddings...")
                embeddings = self.compute_embeddings(snippet_path)
                self.save_embeddings(snippet_path, embeddings)
                print(f"  Saved {len(embeddings)} embeddings")
                updated_count += 1
            else:
                print(f"  Skipped (unchanged)")
                skipped_count += 1
        
        print(f"\nProcessed {len(snippets)} snippets:")
        print(f"  Updated: {updated_count}")
        print(f"  Skipped: {skipped_count}")

def main():
    """Main entry point"""
    import sys
    
    features_root = sys.argv[1] if len(sys.argv) > 1 else "features"
    
    computer = ComputeEmbedding(features_root)
    computer.process_all_snippets()

if __name__ == "__main__":
    main()