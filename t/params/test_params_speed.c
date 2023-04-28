#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <sys/resource.h>
#include <openssl/core.h>
#include "t_params_speed.h"

static OSSL_PARAM all_params[] = {
    { S_PARAM_ivlen, 0, NULL, 0, 0 },
    { S_PARAM_mode, 0, NULL, 0, 0 },
    { S_PARAM_aead, 0, NULL, 0, 0 },
    { S_PARAM_custom_iv, 0, NULL, 0, 0 },
    { S_PARAM_cts, 0, NULL, 0, 0 },
    { S_PARAM_tls1_multiblock, 0, NULL, 0, 0 },
    { S_PARAM_has_rand_key, 0, NULL, 0, 0 },
    { S_PARAM_keylen, 0, NULL, 0, 0 },
    { S_PARAM_block_size, 0, NULL, 0, 0 },
    { NULL, 0, NULL, 0, 0 }
};

static void
lookup_params_strcasecmp(const OSSL_PARAM *param, const void *arg)
{
    const OSSL_PARAM *all_params = arg;

    for(; all_params->key != NULL; all_params++)
        if (strcasecmp(param->key, all_params->key) == 0)
            break;
}

static void
lookup_params_parsetree(const OSSL_PARAM *param, const void *arg)
{
    test_params_speed(param->key);
}

static double measure(size_t amount,
                      const OSSL_PARAM *param,
                      void (*fn)(const OSSL_PARAM *param, const void *arg),
                      const void *arg)
{
    struct rusage start, stop;

    getrusage(RUSAGE_SELF, &start);
    for (; amount > 0; amount--)
        fn(param, arg);
    getrusage(RUSAGE_SELF, &stop);

#ifdef DEBUG
    fprintf(stderr,
            "DEBUG: start.ru_utime = { %lu, %lu }, stop.ru_utime = { %lu, %lu }\n",
            start.ru_utime.tv_sec, start.ru_utime.tv_usec,
            stop.ru_utime.tv_sec, stop.ru_utime.tv_usec);
#endif
    return (stop.ru_utime.tv_sec + stop.ru_utime.tv_usec * 1e-6)
        -  (start.ru_utime.tv_sec + start.ru_utime.tv_usec * 1e-6);
}

#define RUNS 1000
int main()
{
    const OSSL_PARAM *param = all_params;
    size_t count;

    for (; param->key != NULL; param++, count++) {
        double t_strcasecmp = measure(RUNS, param,
                                      lookup_params_strcasecmp, all_params);
        double t_parsetree = measure(RUNS, param,
                                     lookup_params_parsetree, NULL);

        printf("%zu: \"%s\": strcasecmp => %f, parsetree => %f\n",
               count, param->key, t_strcasecmp, t_parsetree);
    }
}
