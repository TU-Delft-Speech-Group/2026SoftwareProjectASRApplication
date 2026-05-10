/**
 * public C API for the inference engine
*/
#ifndef INFERENCE_ENGINE_H
#define INFERENCE_ENGINE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// engine handle
typedef struct inference_engine_t inference_engine_t;

// status codes 
typedef enum inference_engine_status {
    IE_OK = 0,  // succesful
    IE_ALREADY_RUNNING = 1,  // the engine was already started
    IE_NOT_RUNNING = 2,  // the engine was not running
    IE_ERR_NULL_HANDLE = 3,  // pass NULL handle
    IE_ERR_INVALID_STATE = 4,  //invalid call in current state
    IE_ERR_ALLOC = 5, // allocation of memory failed
    IE_ERR_INTERNAL = 6,  // internal error
} inference_engine_status_t;

// new engine instance
inference_engine_status_t inference_engine_create(inference_engine_t **out_engine);

// starts inference loop
inference_engine_status_t inference_engine_start(inference_engine_t *engine);

// stops inference loop
inference_engine_status_t inference_engine_stop(inference_engine_t *engine);

// new instance of engine requires a new handle after inference_engine_destroy is called
void inference_engine_destroy(inference_engine_t *engine);

// push audio and get trascript to be added

#ifdef __cplusplus
}
#endif

#endif