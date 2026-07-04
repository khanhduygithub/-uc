// obf.h
// Compile-time string obfuscation, v2.
//
// - Each literal is encoded with an LCG-driven keystream (not a flat XOR),
//   so byte-frequency analysis of the binary's .rodata section doesn't
//   trivially reveal structure.
// - The keystream key mixes the call-site source line with a hash of
//   __TIME__/__DATE__, so a fresh build produces different ciphertext for
//   the exact same source — rebuilding without touching a single string
//   changes every encoded blob.
// - Decoding happens at the point of use, at runtime, into a short-lived
//   local; obf.mm additionally provides secureWipe() to scrub that local
//   from memory once you're done with it, shrinking the window a memory
//   dump could catch plaintext in.
//
// Still true, same as before: this raises the cost of static inspection.
// It is not anti-debugging and does not try to detect or evade a debugger,
// hook framework, or jailbreak — real enforcement stays server-side.

#pragma once

#include <string>
#include <cstdint>
#include <cstddef>

namespace xqobf {

constexpr uint32_t fnv1a(const char *s, uint32_t h = 2166136261u) {
    return (*s == 0) ? h : fnv1a(s + 1, (h ^ (uint32_t)(unsigned char)*s) * 16777619u);
}

constexpr uint32_t lcg_next(uint32_t x) {
    return x * 1664525u + 1013904223u;
}

template <unsigned N, uint32_t Key>
struct Enc {
    unsigned char data[N];
    constexpr Enc(const char (&s)[N]) : data{} {
        uint32_t k = Key;
        for (unsigned i = 0; i < N; ++i) {
            k = lcg_next(k);
            unsigned char ks = (unsigned char)((k >> 24) ^ (k >> 8));
            data[i] = (unsigned char)((unsigned char)s[i] ^ ks);
        }
    }
};

template <unsigned N, uint32_t Key>
inline std::string dec(const Enc<N, Key> &e) {
    std::string out(N - 1, '\0');
    uint32_t k = Key;
    for (unsigned i = 0; i < N - 1; ++i) {
        k = lcg_next(k);
        unsigned char ks = (unsigned char)((k >> 24) ^ (k >> 8));
        out[i] = (char)(e.data[i] ^ ks);
    }
    return out;
}

// Overwrites a std::string's buffer in place before it's destroyed, so a
// decoded secret doesn't linger in freed heap memory. Declared here,
// implemented (non-inline, so the compiler can't optimize it away as
// dead-store elimination) in obf.mm.
void secureWipe(std::string &s);

} // namespace xqobf

#define XQ_LINE_SEED_ ((uint32_t)(__LINE__) * 2654435761u)
#define XQ_BUILD_SEED_ (xqobf::fnv1a(__TIME__) ^ (xqobf::fnv1a(__DATE__) << 1))

// XQS("literal") -> std::string, decoded at call time.
// Remember: call xqobf::secureWipe() on the result once you're done with
// it if it's holding onto something sensitive past its immediate use.
#define XQS(str) ([]() -> std::string { \
    constexpr uint32_t _xqk = XQ_LINE_SEED_ ^ XQ_BUILD_SEED_; \
    static constexpr xqobf::Enc<sizeof(str), _xqk> _xqe(str); \
    return xqobf::dec(_xqe); \
}())

// XQNS("literal") -> NSString*, convenience for Objective-C++ call sites.
// (Converts through UTF8; the intermediate std::string is temporary but
// not wiped automatically, since the NSString already owns its own copy.)
#define XQNS(str) ([NSString stringWithUTF8String: XQS(str).c_str()])
