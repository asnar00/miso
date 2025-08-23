#!/usr/bin/env python3
"""
search tool implementation
Finds relevant specification snippets using semantic similarity search
"""

import os
import json
import numpy as np
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from collections import deque
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity

class SearchTool:
    def __init__(self, features_root: str = "features", similarity_threshold: float = 0.3):
        self.features_root = Path(features_root)
        self.model = SentenceTransformer('all-MiniLM-L6-v2')  # Same model as compute-embedding
        self.similarity_threshold = similarity_threshold
        
    def load_snippet_embeddings(self, snippet_path: Path) -> Optional[List[List[float]]]:
        """Load embeddings for a snippet"""
        # Convert features/A/B/C.md -> features/A/B/C/meta/embeddings.json
        relative_path = snippet_path.relative_to(self.features_root)
        stem = relative_path.with_suffix('')  # Remove .md
        embedding_file = self.features_root / stem / "meta" / "embeddings.json"
        
        try:
            with open(embedding_file, 'r') as f:
                return json.load(f)
        except Exception:
            return None
    
    def get_snippet_similarity(self, query_embedding: np.ndarray, snippet_path: Path) -> float:
        """Calculate cosine similarity between query and snippet"""
        snippet_embeddings = self.load_snippet_embeddings(snippet_path)
        
        if not snippet_embeddings:
            return 0.0
        
        # Convert to numpy array
        snippet_vectors = np.array(snippet_embeddings)
        
        # Calculate similarity with each line and take the maximum
        # Ensure query_embedding is 1D for cosine_similarity
        query_vector = query_embedding.reshape(1, -1) if len(query_embedding.shape) == 1 else query_embedding
        similarities = cosine_similarity(query_vector, snippet_vectors)[0]
        return float(np.max(similarities))
    
    def get_child_snippets(self, snippet_path: str) -> List[Path]:
        """Get all child snippets for a given snippet path"""
        children = []
        
        # Handle root case
        if snippet_path == "" or snippet_path == ".":
            search_dir = self.features_root
        else:
            search_dir = self.features_root / snippet_path
        
        if not search_dir.exists():
            return children
        
        # Look for direct .md files in subdirectories
        try:
            for item in search_dir.iterdir():
                if item.is_dir() and item.name not in ['meta', 'all']:
                    md_file = item / f"{item.name}.md"
                    if md_file.exists():
                        children.append(md_file)
        except Exception:
            pass
        
        return children
    
    def get_all_snippets_in_subtree(self, start_path: str) -> List[Path]:
        """Get all snippets in a subtree (for recursive search)"""
        if start_path == "" or start_path == ".":
            search_root = self.features_root
        else:
            search_root = self.features_root / start_path
        
        if not search_root.exists():
            return []
        
        # Find all .md files in the subtree
        return list(search_root.rglob("*.md"))
    
    def breadth_first_search(self, start_path: str, query_embedding: np.ndarray, max_results: int = 10) -> List[Tuple[Path, float]]:
        """Perform breadth-first search through snippet tree"""
        results = []
        visited = set()
        
        # Initialize queue with starting snippets
        if start_path == "" or start_path == ".":
            # Start from root - get all top-level snippets
            queue = deque([(child, 0) for child in self.get_child_snippets("")])
        else:
            # Start from specific snippet
            start_file = self.features_root / f"{start_path}.md"
            if start_file.exists():
                queue = deque([(start_file, 0)])
            else:
                return results
        
        while queue and len(results) < max_results:
            snippet_path, depth = queue.popleft()
            
            if snippet_path in visited:
                continue
            visited.add(snippet_path)
            
            # Calculate similarity
            similarity = self.get_snippet_similarity(query_embedding, snippet_path)
            
            # Add to results if above threshold
            if similarity >= self.similarity_threshold:
                results.append((snippet_path, similarity))
            
            # Add children to queue if similarity is promising (lower threshold for exploration)
            if similarity >= self.similarity_threshold * 0.7:  # Explore branches with 70% of threshold
                # Get snippet path relative to features root for finding children
                try:
                    relative_path = snippet_path.relative_to(self.features_root)
                    snippet_name = relative_path.with_suffix('')  # Remove .md
                    children = self.get_child_snippets(str(snippet_name))
                    
                    for child in children:
                        if child not in visited:
                            queue.append((child, depth + 1))
                except Exception:
                    pass
        
        # Sort by similarity (descending)
        results.sort(key=lambda x: x[1], reverse=True)
        return results[:max_results]
    
    def search(self, start_path: str, question: str, max_results: int = 10) -> List[Dict]:
        """Main search function"""
        print(f"Searching from '{start_path}' for: '{question}'")
        
        # Convert question to embedding
        query_embedding = self.model.encode(question)  # Remove list wrapping
        
        # Get all snippets in subtree
        all_snippets = self.get_all_snippets_in_subtree(start_path)
        
        # Calculate similarity for all snippets
        results = []
        for snippet_path in all_snippets:
            similarity = self.get_snippet_similarity(query_embedding, snippet_path)
            if similarity >= self.similarity_threshold:
                results.append((snippet_path, similarity))
        
        # Sort by similarity (descending)
        results.sort(key=lambda x: x[1], reverse=True)
        results = results[:max_results]
        
        # Format results
        formatted_results = []
        for snippet_path, similarity in results:
            try:
                relative_path = snippet_path.relative_to(self.features_root)
                snippet_name = str(relative_path.with_suffix(''))  # Remove .md
                
                formatted_results.append({
                    "snippet": snippet_name,
                    "path": str(snippet_path),
                    "similarity": round(similarity, 3)
                })
            except Exception as e:
                print(f"Error formatting result for {snippet_path}: {e}")
        
        return formatted_results

def main():
    """Main entry point"""
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python search.py <start_path> <question> [max_results]")
        print("Example: python search.py miso 'how are embeddings computed?'")
        print("Example: python search.py . 'what are tools?' 5")
        sys.exit(1)
    
    start_path = sys.argv[1]
    question = sys.argv[2]
    max_results = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    
    searcher = SearchTool()
    results = searcher.search(start_path, question, max_results)
    
    print(f"\nFound {len(results)} relevant snippets:")
    print("=" * 50)
    
    for i, result in enumerate(results, 1):
        print(f"{i}. {result['snippet']} (similarity: {result['similarity']})")
    
    if not results:
        print("No relevant snippets found. Try lowering the similarity threshold or using different keywords.")

if __name__ == "__main__":
    main()