ᕦ(ツ)ᕤ
# scribbles

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
