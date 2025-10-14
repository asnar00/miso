# testing
*how features get tested*

Each feature in the feature tree is a potential site to add some tests. For a feature `A/B/C.md`, there should be a file called `test.md` in `A/B/C/imp/`, which documents the tests to be performed.

Tests can cut across multiple products, eg. a "ping test" would test both client and server at the same time; so tests can specify code to run on multiple products in one place, making it easier to understand how the test works.

Product-specific tests go in the same folder but contain product-specific code and executable scripts, i.e. `A/B/C/imp/test-ios.sh` and so on.

Actually running tests is the responsibility of the individual products; miso itself doesn't specify how this happens.