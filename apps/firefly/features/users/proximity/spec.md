# proximity
*measure how closely connected two users are via invite chains*

Every user (except the first) was invited by someone else. This creates a tree of relationships connecting all users. Proximity measures the "distance" between any two users in this tree.

**How it works:**

Starting from user A, trace upwards through "invited by" links until you find someone who is also an ancestor of user B. This is the common ancestor. Proximity is the total number of links: from A up to the common ancestor, plus from B up to the common ancestor.

**Examples:**

- You and yourself: proximity 0
- You and the person who invited you: proximity 1
- You and someone you invited: proximity 1
- You and a "sibling" (someone else invited by the same person): proximity 2
- You and a "cousin" (your inviter's sibling's invitee): proximity 4

**How it affects what you see:**

- **Users list**: Sorted by proximity first. You appear at the top, then your inviter and invitees, then their connections, expanding outward.

- **Posts and Queries**: Sorted by date first (newest day at top), but within the same day, posts from closer users appear before posts from distant users.

**Storage:**

Each user stores their ancestor chain - the list of user IDs from themselves up to the root. This makes proximity calculations fast: just find the first common ID in both chains and sum the distances.
