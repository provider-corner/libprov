#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <openssl/core.h>
#include "t_params.h"

#define cRED    "\033[1;31m"
#define cDRED   "\033[0;31m"
#define cGREEN  "\033[1;32m"
#define cDGREEN "\033[0;32m"
#define cBLUE   "\033[1;34m"
#define cMAGENT "\033[1;35m"
#define cDBLUE  "\033[0;34m"
#define cNORM   "\033[m"
#define TEST_ASSERT(e) {if ((test = (e)))                       \
            printf(cGREEN "Assertion passed: " #e cNORM "\n");  \
        else                                                    \
            printf(cRED "Assertion FAILED" #e cNORM "\n");}

OSSL_PARAM *prep(OSSL_PARAM *p, const char *s_param)
{
    p[0].key = s_param;
    return p;
}

int main()
{
    int ret = 1, test;
    OSSL_PARAM params[] = {
        { NULL, 0, NULL, 0, 0 },
        { NULL, 0, NULL, 0, 0 }
    };

    /* Positive tests */
    TEST_ASSERT(test_params_tree(S_PARAM_rounds) == V_PARAM_rounds); ret &= test;
    TEST_ASSERT(test_params_tree(S_PARAM_mode) == V_PARAM_mode); ret &= test;
    TEST_ASSERT(test_params_tree(S_PARAM_size) == V_PARAM_size); ret &= test;
    TEST_ASSERT(test_params_tree(S_PARAM_pass) == V_PARAM_pass); ret &= test;
    TEST_ASSERT(test_params_tree(S_PARAM_salt) == V_PARAM_salt); ret &= test;
    TEST_ASSERT(test_params_tree(S_PARAM_size) == V_PARAM_size); ret &= test;
    TEST_ASSERT(test_params_tree(S_PARAM_version) == V_PARAM_version); ret &= test;
    TEST_ASSERT(test_params_tree(S_PARAM_buildinfo) == V_PARAM_buildinfo); ret &= test;
    TEST_ASSERT(test_params_tree(S_PARAM_author) == V_PARAM_author); ret &= test;

    /* Positively negative tests */
    TEST_ASSERT(test_params_tree("something") == 0); ret &= test;
    TEST_ASSERT(test_params_tree("authors") == 0); ret &= test;
    TEST_ASSERT(test_params_tree("sizes") == 0); ret &= test;
    TEST_ASSERT(test_params_tree("author buildinfo") == 0); ret &= test;

    return !ret;
}
