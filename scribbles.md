ᕦ(ツ)ᕤ
# scribbles

thoughts on firefly structuring:

"microclub" as a name
target = a small group of people working together
eg. marylebone ward - 4-8 people.
goal = increase the membership of this group

each group has user-list, posts, queries.
all queries are public to the group, and live.
each new post gets matched against a query.
search results should be weighted by recent-first.

so in other words, you weight posts by people in *your* user list most highly.

the idea is, use randomness to sprinkle in "oddities" in the results. I quite like that.

"random/recent/close"

the measure of "proximity" of a post to you is through distance in the social graph.

if "A invites B" relationships exist, then we can use that (and geographical location) as a measure of proximity.

So "social proximity", "recency", and "randomness" are useful. In other words, we might randomly promote a post that has lower proximity or recency. But everything has to be relevant.

Randomness in ordering is actually under-rated. A good thing about randomness is that it's easy to sell and defend.



---------
miso notes: there's a "navigational overhead" when working in the feature tree.

this is why it's better for the agent to maintain the tree for you; you just search it

the best interface is actually conversational;
but contextual - looking at source at the same time.


----------------
todo
change to sqlite. NUP
claude-api search.
toolbar sub-UI state retention.
invite button => display download link.
install android
remote client for claude code?
demo/test.

--------------------

OK so what we'll do as v1: SUPER SIMPLE.

toolbar with three buttons:
- my posts (create post button at top)
- my queries (create query button at top)
- my bookmarks

each post viewer has 'star' button where edit button goes (can only star other peoples' posts, so makes sense).

This will do for now.
when you go to a profile page, you can see their posts, but not their queries or bookmarks.



------------------

next steps:
- show tags
- shortcuts = tags
- all lists are semantic-searchable (filter)
- query type: recurring search using an agent.

I think location of post also makes a huge difference;
and being able to interrogate and specify that via LLM.

"find meat posts in soho about events next week"

=> tag, RAG set, post-process prompt. Easy.

-------------

how about the same as below, except the infrastructure doesn't specify what the tags are - that's up to the people running the database.

so there's actually two levels of users:

    - moderators (those who run the server)
    - users (those who don't)

the framework is just: tagged posts, agent-based query.

----------------

how's this for the toolbar:

users: all users, searchable (find people who do x)
posts: all posts, searchable (find posts about x)
queries: all queries, searchable (find queries about x)
projects: all projects, searchable

so I think definitely tag: profile, post, query, project
=> we can have other tags later I suppose.
eg. events certainly seems to be one.

but the idea of "each button on toolbar is a tag"
seems like a good one.

for politics, you also need "groups"
I think eg. marylebone ward contains people who post;
so you can see all posts about x.

tags could be:

group
person
post
query
event

and so on. I think that's a good idea.
------------------------


start again with claude.
literally tell it: I want to start from scratch - this is now old. -> advise design based on the last one.


--------------------------

it's just a single tree;
starting at you - and you decide what you want to add.
any post can be a query.

so the interface is:

your have your main page
edit button at any time (bottom right)
">" to children
"+post" is good.

for ANY post, you can turn that into a search query.

the fundamental operation is: "run a semantic search using this post as the query"

OH YEAH.
That's IT.

as before, toolbar icons are just shortcuts to sub-trees.

each user manages a tree of posts.
users connect to each other ("x invited y") forming a DAG/tree
we can semantic search the entire database 
weighting results by proximity in user graph.

I really like this structure.

user -> intro -> another-user

because then of course you can introduce people to each other without having to write the intro every time.

"intro" that's a good word.... name,.

what if that was its purpose!!!? 
you and me chat, you intro me, I intro you

so it really is:
when you start, there's a tree there already
that contains the instructions - but it's all changeable.

me -> writing
   -> reading
   -> questions

but it's really up to you - you organise it as you want.

so there's tools at each level:
-> reorder
-> merge
-> add

just make that for now.




-------------------------


core if it is just a tree explorer.
start at the root, go from there.
at any time, search=> new tree; and save those.
and then basically your toolbar is just shortcuts.

ok - rebuild based on that.
#startagain



----------------------------------------

page organisation ideas:

- each person has their main page:
  - name
  - mission
  - pic
  - statement

and under that, standard snippets:

- writings
- readings
- questions
- connections

connection: a page where you introduce another person - that then links to their main page.

eg. "I met Iarla at college, blah blah" -> link to Iarla's page.

to ask questions, you go to questions, and add a query; the system summarises the response underneath. you can hop down into that tree and add new sub-queries.

all of this is public to anyone on the app.

note: this is just the starting tree, you can populate it any way you want.

anyhoo. something like this. doesn't have to be perfect, just has to exist - that's the tree you show.

--- idea:
you populate each node with "prompt text" - shown in grey when you open the snippet, to give you an idea of what you could fill in there.
That guides people, while also being pretty open.

----------------------
templates!!

populate the questions/ page with some standard things, and their results.

Mark a page "template"! AHA template pages.
I like it a lot. Elegant idea.

So we create a template snippet tree for a user, and then just instantiate it. The filled-in text shows as a grey background for the input field. Super elegant. 

-------------------------------


idea: live queries.

make a query: it's a post!
its childen are the "answer" to the question; a summary of the tree of relevant posts.

so the summary is a tree of relevant posts and summaries; it's like a debug view of the RAG process.

So you can always drill down to the real answers.

If this query is re-run whenever a new post appears, the result is something like a live poll.

So the format is like: people ask questions, those questions (and the answers) are visible to others, and people can modify the answer by adding their opinion (making posts).

so it's just basically a collaborative tree editor, and a query system. Maybe the default view is just the most recently active topics.

I'm feeling it.



----------------------------------


been thinking we need a refactor.

features/
    infrastructure/
        build/
            imp.md: all code together! one file!
        deploy/
        restart/
        logging/
        control/
        testing/
products/
    client/
        ios/
        eos/
    server/
        flask/
        postgresql/
    tools/
        build/
        deploy/
        stop/
        start/
        capture/
        log/
        test/

------------------
Second most important thing: concept of ACTIONS.

Actions are hierarchical natural-language instructions for LLMs to follow.

------------------------------------------------

thoughts on firefly.

- each user has a tree of snippets
- take a picture (front or back camera) => video?
- type post text (or dictate); no pasting?
- post it

goal: to only allow user-created media. no pics, no paste.

- view your own posts
- search others semantically




--------------------------------------------------------

let's think about remote user debugging experience.
this really is what we should be thinking about building.

- on phone, record the following into a circular buffer (t sec)
    - console
    - system state (every t sec)
    - phone screen
    - user cam/mic

- when something goes wrong or you want to modify, hit "AAA" button
    - copies the current buffer and time to a store
    - label it with your comment or feedback
    - streams up to the server asap
    - miso debugs those streams

So it's really a system state recorder / replay tool, allowing the agent to diagnose the problem by going up and down the fault timeline.

----------------------------------------------------------
possible next steps:

- recordability / reproducibility / understandability
- unified capture-app for iphone/android
- record video into a circular buffer
- record system state at regular intervals (same interval)
- when there's a problem, just save the current log as a "trace"
- ability to get screenshot into agent
- agent can rewind, fwd through a trace
- replicate the system state, calls, etc.

=> that's a damn good way to get things going.

I really like this approach - just got to make the build parallel.
make the app "understandable" - "seeable"

----------------------------------------------------------
