//
//  Exception.h
//  Cyanide
//
//  Created by seo on 4/4/26.
//

#import <mach/mach.h>
#import "RemoteCall.h"

// from pe_main.js
typedef struct {
    mach_msg_header_t       Head;
    uint64_t                NDR;
    uint32_t                exception;
    uint32_t                codeCnt;
    uint64_t                codeFirst;
    uint64_t                codeSecond;
    uint32_t                flavor;
    uint32_t                old_stateCnt;
    arm_thread_state64_internal    threadState;
    uint64_t                padding[2];
    // Parsed by wait_exception from the kernel-processed descriptor area that
    // the kernel sends right after the header on every exception_raise*
    // message (thread first, task second). Zero when parsing could not be
    // done confidently — callers must fail open in that case.
    mach_port_t             threadPort;   // send right to the trapped thread
    mach_port_t             taskPort;     // send right to the trapped task
    uint32_t                msgId;        // Head.msgh_id (2401..2407 family)
    uint32_t                msgSize;      // Head.msgh_size
} ExceptionMessage;

typedef struct {
    mach_msg_header_t   Head;
    uint64_t            NDR;
    uint32_t            RetCode;
    uint32_t            flavor;
    uint32_t            new_stateCnt;
    arm_thread_state64_internal threadState;
} __attribute__((packed)) ExceptionReply;

mach_port_t create_exception_port(void);
void destroy_exception_port(mach_port_t exceptionPort);
bool wait_exception(mach_port_t exceptionPort, ExceptionMessage *excBuffer, int timeout, bool debug);
bool reply_with_state(ExceptionMessage *exc, arm_thread_state64_internal *state);
