# posts test
*verify post creation and retrieval*

Tests the full lifecycle of posts: creating a new post with metadata, storing it in the database, and retrieving it.

**Server requirement**: Server running at 185.96.221.52:8080 with posts table and API endpoints active

**Test logic**:
1. Parse `test-post.md` to extract title, summary, body, and image filename
2. Create a new post via `/api/posts/create` with parsed data
3. Verify the post was created successfully and get post_id
4. Retrieve the post by ID via `/api/posts/{post_id}`
5. Verify all fields match what was submitted
6. Get recent posts via `/api/posts/recent`
7. Verify the new post appears in recent posts list

**Test data**:
- Content loaded from `test-post.md` (title, summary, body)
- Timezone: "Europe/Barcelona"
- Location: "Barcelona, Spain"
- Email: ash.nehru@gmail.com
- Image extracted from markdown `![...]` reference

**Success criteria**:
- Post is created and returns valid post_id
- Retrieved post matches submitted data
- Post appears in recent posts list
- All metadata (timezone, location, timestamps) is preserved

**Running the test**:
```bash
cd apps/firefly/features/posts/imp
python3 test.py
```

**Notes**:
- Test requires ash.nehru@gmail.com to exist in database
- Test parses `test-post.md` for post content
- Post markdown format: `# title`, `*summary*`, body, `![...](image.png)`
- Image referenced in markdown must exist in same directory
- Each test run creates a new post in the database
- Server must have write access to uploads directory
