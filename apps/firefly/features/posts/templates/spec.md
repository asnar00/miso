# templates
*define reusable field label sets for different types of posts*

Posts can have different purposes - some are regular posts with "Title", "Summary", and "Body" fields, while others are profiles with "name", "mission", and "personal statement" fields. Templates let you define these label sets once and reuse them across many posts.

**What is a Template:**
A template is a named set of placeholder labels for the three main text fields in a post. Each template has:
- A unique name (e.g., "post", "profile", "query")
- A label for the title field
- A label for the summary field
- A label for the body field

**Default Templates:**
The system comes with two built-in templates:
- **post**: Uses "Title", "Summary", "Body" - the standard blog post format
- **profile**: Uses "name", "mission", "personal statement" - for user profile pages

**How Posts Use Templates:**
Each post references a template by name. When viewing or editing the post, the appropriate placeholder labels appear in the text fields. For example, the "asnaroo" post uses the "profile" template, so its edit fields show "name" instead of "Title".

**Visual Effect:**
When editing a post, the placeholder text appears in light grey (55% opacity) in empty fields. Different templates make the same post editing interface feel different - a profile feels like filling out personal information, while a regular post feels like writing an article.

**Benefits:**
- **Consistency**: All posts of the same type use the same labels
- **Flexibility**: Create new templates for new post types without code changes
- **Clarity**: Users immediately understand what kind of content belongs in each field
- **Reusability**: One template can be used by thousands of posts

**Example Use Cases:**
- **profile**: Personal profiles with name, mission, bio
- **post**: Standard blog posts or articles
- **query**: Questions with "question", "context", "what I've tried"
- **recipe**: Cooking recipes with "dish name", "description", "instructions"
- **review**: Product reviews with "product", "verdict", "detailed review"

**Future Extensions:**
Templates could eventually specify:
- Field validation rules (min/max length)
- Whether fields are required or optional
- Default values for new posts
- Custom field types beyond text
