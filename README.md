# libprov - a small library of helpers for OpenSSL 3 providers

Currently available routines:

-   ERR helpers

    OpenSSL's ERR functions do not lend themselves very well to provider's
    own error tables, because they can't pass the provider's handle to the
    error record building routines.  This is due to certain limitations with
    the base C standard requirements for OpenSSL itself (C90).

    These helpers are replacements of OpenSSL's ERR_raise() and
    `ERR_raise_data()` that take better advantage of more modern C
    standards.  C99 required.

    See the comments in `include/prov/err.h` for more information.

-   NUM helper

    Converting `OSSL_PARAM` numbers to native numbers present a bit of a
    challenge, as they are variable length, and may need some adaption
    to fit into native numbers.

    `provnum_get()` and `provnum_set()` claim to be universally applicable
    functions for converting an OSSL_PARAM number to a native integer or
    bignum implementations.

-   `OSSL_PARAM` parsing helper

    Parsing `OSSL_PARAM` keys can be done in many ways, with various
    performance problems.  A simple (even naïve) way was to loop over the
    params and `strcasecmp()` them with known names.  Depending on the
    `strcasecmp()` implementation, that can be rather slow.

    `perl/gen_param_LL.pl` takes a specification in form of a perl ARRAY,
    which contains a C function name (for example, `"parse_params"`) as
    first item, followed by a series of tuples of this form:

    ``` perl
    NAME => "key"
    ```

    Each such `NAME` becomes a couple of C macros:

    -   `S_NAME`, with the `"key"` string as its value.
    -   `V_NAME`, with a unique generated integer as its value.

    The function name that's given at the start of the function becomes a C
    function that is called with a single argument, the key to parse.  As a
    test, the following should always be true:

    ``` C
    parse_params(S_NAME) == V_NAME
    ```

    When looking through an `OSSL_PARAM` array, the easy way is to do
    something like this:

    ``` C
    const OSSL_PARAM *p;

    for (p = params; p->key != NULL; p++) {
        switch (parse_params(p->key)) {
        case V_NAME:
            /* Do whatever's needed */
            break;
        ...
        }
    }
    ```
