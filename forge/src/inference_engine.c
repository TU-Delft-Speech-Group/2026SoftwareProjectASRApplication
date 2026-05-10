#include "inference_engine.h"
#include <stdlib.h>
#include <stdbool.h>

struct inference_engine_t {
    bool running;
};

inference_engine_status_t inference_engine_create(inference_engine_t **out_engine) {
    if(out_engine == NULL) return IE_ERR_NULL_HANDLE;
    inference_engine_t *engine = calloc(1, sizeof(inference_engine_t));
    if(engine == NULL) return IE_ERR_ALLOC;
    engine->running = 0;
    *out_engine = engine;
    return IE_OK;
}

inference_engine_status_t inference_engine_start(inference_engine_t *engine) {
    if(engine == NULL) return IE_ERR_NULL_HANDLE;
    if(engine->running) return IE_ALREADY_RUNNING;
    engine->running = 1;
    return IE_OK;
}

inference_engine_status_t inference_engine_stop(inference_engine_t *engine) {
    if(engine == NULL) return IE_ERR_NULL_HANDLE;
    if(!engine->running) return IE_NOT_RUNNING;
    engine->running = 0;
    return IE_OK;
}

// handle becomes invalid after this call
void inference_engine_destroy(inference_engine_t *engine) {
    if(engine == NULL) return;
    free(engine);
}