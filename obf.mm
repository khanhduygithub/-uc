// obf.mm
// Implementation counterpart to obf.h.
//
// Add this file to the same build target as DuyKeyAuth.mm (and obf.h to
// your header search path / project). Nothing here needs editing per
// project — the per-build variation comes from __TIME__/__DATE__ picked
// up automatically by obf.h at each compile.

#import "obf.h"
#include <cstring>
#include <cstdint>

namespace xqobf {

// Deliberately out-of-line (not in the header) and touching the buffer
// through a volatile pointer, so the compiler can't prove the writes are
// dead and strip them out — a plain `memset` right before a string's
// destructor runs is a classic case optimizers remove entirely.
void secureWipe(std::string &s) {
    if (s.empty()) return;
    volatile char *p = const_cast<volatile char *>(s.data());
    for (size_t i = 0; i < s.size(); ++i) {
        p[i] = 0;
    }
    s.clear();
    s.shrink_to_fit();
}

} // namespace xqobf
