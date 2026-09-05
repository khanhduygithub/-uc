//
//  espkrw.h
//  DarkSword
//
//  Kernel R/W bridge for the Free Fire ESP (remake of CrackTeam's
//  TrollStore task_for_pid path on top of the darksword kernel exploit).
//
//  TrollStore version (CrackTeam/esp/Core/pid.mm):
//      task_for_pid(pid)               -> mach task port of the game
//  DarkSword version:
//      proc_find_by_name("FreeFire")   -> kernel proc
//      proc_task(proc)                 -> kernel task address
//      port transplant                 -> mach port in OUR task whose
//                                         ip_kobject points at the game task
//  After the transplant, mach_vm_read_overwrite / mach_vm_write /
//  task_info(TASK_DYLD_INFO) work exactly like the TrollStore build, so the
//  rest of pid.mm / GameLogic / esp.mm stays byte-for-byte the same.
//

#ifndef espkrw_h
#define espkrw_h

#include <stdint.h>
#include <stdbool.h>
#include <mach/mach.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Step-by-step init (each step is idempotent and logged with [ESPKRW]):
//   1. kernel R/W available? (kexploit_krw_ready / persistence recovered)
//   2. best-effort sandbox escape + elevate to root (kernel ucred copy)
//   3. find the game pid (sysctl KERN_PROC_ALL — same as TrollStore build;
//      kernel proc_find_by_name fallback)
//   4. transplant a task port for the game into this process
//   5. verify by reading the port kobject back
//
// Returns 0 on success, negative error code otherwise.
int esp_krw_init(void);

// Re-runs init when the game process was restarted (stale port detection).
int esp_krw_reinit(void);

// Tears the bridge down: restores the transplanted port to a plain
// IKOT_NONE port so process exit can never underflow the game task
// reference count. Safe to call at any state.
void esp_krw_stop(void);

// Transplanted game task port (valid only while esp_krw_ready()).
mach_port_t esp_krw_task_port(void);

// Game pid as found by the sysctl/kernel scan (-1 when unknown).
pid_t esp_krw_game_pid(void);

// Kernel addresses of interest (0 when unknown) — for the status UI.
uint64_t esp_krw_game_task_kaddr(void);
uint64_t esp_krw_game_proc_kaddr(void);

// True when the bridge holds a transplanted port AND the game process
// is still alive (kill(pid, 0) style probe done without signals).
bool esp_krw_ready(void);

// Kernel-side liveness check of the game proc (does not touch the port).
bool esp_krw_game_alive(void);

// Sysctl probe: is a FreeFire process running right now (regardless of the
// bridge state)? Used by the auto-heal loop when the game relaunches.
bool esp_krw_game_process_exists(void);

// Sysctl-ONLY variant — guaranteed not to touch kernel R/W (safe before
// Start Darksword). Used by the ESP status snapshot drawn when the tab
// appears, so the panel reflects reality without any kernel access.
bool esp_krw_game_process_exists_sysctl(void);

#ifdef __cplusplus
}
#endif

#endif /* espkrw_h */
