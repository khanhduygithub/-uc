//
//  Exception.m
//  Cyanide
//
//  Created by seo on 4/4/26.
//

#import "../kexploit/kexploit_opa334.h"
#import "Exception.h"
#import "RemoteCall.h"
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <stddef.h>

// xnu-10002.81.5/osfmk/mach/port.h
#define MPO_PROVISIONAL_ID_PROT_OPTOUT     0x8000  /* Opted out of EXCEPTION_IDENTITY_PROTECTED violation for now */

// from pe_main.js
#define EXCEPTION_MSG_SIZE              0x160
#define EXCEPTION_REPLY_SIZE            0x13c

mach_port_t create_exception_port(void)
{
    mach_port_options_t options = {
        .flags = MPO_INSERT_SEND_RIGHT | MPO_PROVISIONAL_ID_PROT_OPTOUT,
        .mpl   = { .mpl_qlimit = 0 }
    };

    mach_port_t exceptionPort = MACH_PORT_NULL;

    kern_return_t kr = mach_port_construct(mach_task_self_, &options, 0, &exceptionPort);
    if (kr != KERN_SUCCESS)
    {
        printf("[%s:%d] Failed to create exception port: %s (kr=%d)", __FUNCTION__, __LINE__, mach_error_string(kr), kr);
        return MACH_PORT_NULL;
    }

    return exceptionPort;
}

void destroy_exception_port(mach_port_t exceptionPort)
{
    if (!MACH_PORT_VALID(exceptionPort)) return;

    mach_port_type_t type = 0;
    kern_return_t kr = mach_port_type(mach_task_self_, exceptionPort, &type);
    if (kr == KERN_SUCCESS && (type & MACH_PORT_TYPE_SEND)) {
        kr = mach_port_mod_refs(mach_task_self_, exceptionPort, MACH_PORT_RIGHT_SEND, -1);
        if (kr != KERN_SUCCESS &&
            kr != KERN_INVALID_NAME &&
            kr != KERN_INVALID_RIGHT &&
            kr != KERN_INVALID_VALUE) {
            printf("[%s:%d] Failed to drop exception port send right 0x%x: %s (kr=%d)\n",
                   __FUNCTION__, __LINE__, exceptionPort, mach_error_string(kr), kr);
        }
    }

    kr = mach_port_destruct(mach_task_self_, exceptionPort, 0, 0);
    if (kr != KERN_SUCCESS && kr != KERN_INVALID_NAME)
        printf("[%s:%d] Failed to destroy exception port 0x%x: %s (kr=%d)\n",
               __FUNCTION__, __LINE__, exceptionPort, mach_error_string(kr), kr);
}

bool wait_exception(mach_port_t exceptionPort, ExceptionMessage *excBuffer, int timeout, bool debug) {
    if (!excBuffer)
        return false;

    memset(((uint8_t *)excBuffer) + offsetof(ExceptionMessage, threadPort), 0,
           sizeof(*excBuffer) - offsetof(ExceptionMessage, threadPort));

    kern_return_t kr = mach_msg(&excBuffer->Head, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, EXCEPTION_MSG_SIZE, exceptionPort, timeout, MACH_PORT_NULL);
    
    if(kr != KERN_SUCCESS)  return false;

    excBuffer->msgId = excBuffer->Head.msgh_id;
    excBuffer->msgSize = excBuffer->Head.msgh_size;

    // The kernel prefixes every exception_raise* message with a descriptor
    // body: mach_msg_body_t (count) followed by one port descriptor per sent
    // right — thread first, task second (exc.defs). Parse them defensively:
    // any surprise (bad count / wrong type / null name) leaves the fields at
    // zero so callers fail open instead of acting on garbage.
    do {
        if (excBuffer->Head.msgh_size < sizeof(mach_msg_header_t) + sizeof(mach_msg_body_t) + 2 * sizeof(mach_msg_port_descriptor_t))
            break;

        uint8_t *raw = (uint8_t *)excBuffer;
        mach_msg_body_t *body = (mach_msg_body_t *)(raw + sizeof(mach_msg_header_t));
        if (body->msgh_descriptor_count < 1 || body->msgh_descriptor_count > 2)
            break;

        mach_msg_port_descriptor_t *threadDesc = (mach_msg_port_descriptor_t *)(body + 1);
        if (threadDesc->type != MACH_MSG_PORT_DESCRIPTOR || !threadDesc->name)
            break;

        excBuffer->threadPort = threadDesc->name;

        if (body->msgh_descriptor_count == 2) {
            mach_msg_port_descriptor_t *taskDesc = threadDesc + 1;
            if (taskDesc->type == MACH_MSG_PORT_DESCRIPTOR && taskDesc->name)
                excBuffer->taskPort = taskDesc->name;
        }
    } while (0);

    if (debug)
        printf("[Exception] received id=%u size=%u threadPort=0x%x taskPort=0x%x\n",
               excBuffer->msgId, excBuffer->msgSize, excBuffer->threadPort, excBuffer->taskPort);

    return true;
}

bool reply_with_state(ExceptionMessage *exc, arm_thread_state64_internal *state)
{
    uint8_t replyBuf[EXCEPTION_REPLY_SIZE];
    memset(replyBuf, 0, sizeof(replyBuf));
    ExceptionReply *reply = (ExceptionReply *)replyBuf;

    reply->Head.msgh_bits        = MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND_ONCE, 0);
    reply->Head.msgh_size        = EXCEPTION_REPLY_SIZE;
    reply->Head.msgh_remote_port = exc->Head.msgh_remote_port;
    reply->Head.msgh_local_port  = MACH_PORT_NULL;
    reply->Head.msgh_id          = exc->Head.msgh_id + 100;
    reply->NDR                   = exc->NDR;
    reply->RetCode               = 0;
    reply->flavor                = ARM_THREAD_STATE64;
    reply->new_stateCnt          = ARM_THREAD_STATE64_COUNT;
    memcpy(&reply->threadState, state, sizeof(arm_thread_state64_t));

    kern_return_t kr = mach_msg((mach_msg_header_t *)replyBuf,
                                MACH_SEND_MSG,
                                EXCEPTION_REPLY_SIZE, 0,
                                MACH_PORT_NULL,
                                MACH_MSG_TIMEOUT_NONE,
                                MACH_PORT_NULL);
    if (kr != KERN_SUCCESS) {
        printf("[%s:%d] reply_with_state failed: %s (id=%u)\n", __FUNCTION__, __LINE__, mach_error_string(kr), exc ? exc->msgId : 0);
        return false;
    }
    return true;
}
