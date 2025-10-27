ᕦ(ツ)ᕤ
# scribbles

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
