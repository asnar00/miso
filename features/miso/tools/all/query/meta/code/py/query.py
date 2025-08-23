#!/usr/bin/env python3
"""
query tool implementation
Answer questions about specifications using search + Claude API
"""

import os
import sys
from pathlib import Path
from typing import List, Dict, Optional
import anthropic

# Add search tool to path  
# Go up from query.py -> py -> code -> meta -> query -> all -> search
search_path = Path(__file__).parent.parent.parent.parent.parent / "search" / "meta" / "code" / "py"
sys.path.insert(0, str(search_path))

try:
    from search import SearchTool
except ImportError:
    print(f"Error: Could not import SearchTool from {search_path}")
    print("Make sure the search tool is implemented and accessible.")
    sys.exit(1)

class QueryTool:
    def __init__(self, features_root: str = "features", api_key: Optional[str] = None):
        self.features_root = Path(features_root)
        self.search_tool = SearchTool(features_root)
        
        # Initialize Claude API client
        self.api_key = api_key or os.getenv("ANTHROPIC_API_KEY")
        
        # Try loading from .env file if not found in environment
        if not self.api_key:
            env_file = self.features_root.parent / ".env"
            if env_file.exists():
                with open(env_file, 'r') as f:
                    for line in f:
                        if line.startswith('ANTHROPIC_API_KEY='):
                            self.api_key = line.split('=', 1)[1].strip()
                            break
        
        if not self.api_key:
            raise ValueError("ANTHROPIC_API_KEY must be set in environment variable or .env file")
        
        self.client = anthropic.Anthropic(api_key=self.api_key)
    
    def read_snippet_content(self, snippet_path: str) -> str:
        """Read the content of a snippet file"""
        try:
            full_path = self.features_root / f"{snippet_path}.md"
            with open(full_path, 'r', encoding='utf-8') as f:
                return f.read().strip()
        except Exception as e:
            return f"[Error reading {snippet_path}: {e}]"
    
    def assemble_context(self, search_results: List[Dict]) -> str:
        """Assemble search results into a coherent context"""
        if not search_results:
            return "No relevant documentation found."
        
        context_parts = []
        context_parts.append("=== RELEVANT DOCUMENTATION ===\n")
        
        for i, result in enumerate(search_results, 1):
            snippet_path = result["snippet"]
            similarity = result["similarity"]
            content = self.read_snippet_content(snippet_path)
            
            context_parts.append(f"## {snippet_path}.md (relevance: {similarity})")
            context_parts.append(content)
            context_parts.append("")  # Empty line for separation
        
        return "\n".join(context_parts)
    
    def create_prompt(self, question: str, context: str) -> str:
        """Create the prompt for Claude"""
        return f"""You are a helpful assistant that answers questions about software specifications and documentation.

Answer the user's question based ONLY on the provided documentation context.

{context}

=== USER QUESTION ===
{question}

=== INSTRUCTIONS ===
- Answer directly and concisely
- Avoid phrases like "Based on the provided documentation" - this is implicit
- When citing sources, reference the .md file path directly
- If information is missing or unclear, say so
- If the question can't be answered, say "The documentation doesn't contain enough information to answer this question"

Answer:"""
    
    def query_claude(self, prompt: str) -> str:
        """Send prompt to Claude and get response"""
        try:
            response = self.client.messages.create(
                model="claude-3-haiku-20240307",  # Fast model for queries
                max_tokens=1000,
                messages=[{"role": "user", "content": prompt}]
            )
            return response.content[0].text.strip()
        except Exception as e:
            return f"Error querying Claude API: {e}"
    
    def query(self, start_path: str, question: str, max_snippets: int = 5) -> str:
        """Main query function"""
        print(f"🔍 Searching for relevant information...")
        
        # Use search tool to find relevant snippets
        search_results = self.search_tool.search(start_path, question, max_snippets)
        
        if not search_results:
            return "❌ No relevant documentation found for your question."
        
        print(f"📄 Found {len(search_results)} relevant snippets")
        for result in search_results:
            print(f"   • {result['snippet']} (similarity: {result['similarity']})")
        
        print(f"🤖 Querying Claude...")
        
        # Assemble context
        context = self.assemble_context(search_results)
        
        # Create prompt
        prompt = self.create_prompt(question, context)
        
        # Query Claude
        answer = self.query_claude(prompt)
        
        return answer

def main():
    """Main entry point"""
    if len(sys.argv) < 3:
        print("Usage: python query.py <start_path> <question> [max_snippets]")
        print("Example: python query.py miso 'How do embeddings work?'")
        print("Example: python query.py . 'What are tools and how do they differ from actions?' 3")
        print("\nNote: Set ANTHROPIC_API_KEY environment variable")
        sys.exit(1)
    
    start_path = sys.argv[1]
    question = sys.argv[2]
    max_snippets = int(sys.argv[3]) if len(sys.argv) > 3 else 5
    
    try:
        query_tool = QueryTool()
        answer = query_tool.query(start_path, question, max_snippets)
        
        print(f"\n{'='*50}")
        print("💬 ANSWER:")
        print(f"{'='*50}")
        print(answer)
        print()
        
    except ValueError as e:
        print(f"❌ Configuration error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()