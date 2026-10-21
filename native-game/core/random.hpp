// SPDX-License-Identifier: MIT
#pragma once
#include <cstdint>

namespace transartica {
// Independent PCG-XSH-RR implementation. Algorithm and reference vectors:
// https://www.pcg-random.org/using-pcg-c-basic.html
// Range semantics preserve the existing RandomPCG::random(int,int) call sites.
// No engine headers, object model or runtime dependency.
struct Random {
    static constexpr std::uint64_t default_sequence = 1442695040888963407ULL;
    std::uint64_t state{}, increment = (default_sequence << 1U) | 1U;
    void seed(std::uint64_t value, std::uint64_t sequence = default_sequence);
    std::uint32_t next_u32();
    std::uint32_t bounded(std::uint32_t bound);
    int range(int from, int to);
    // city_trade.gd _rnd: no draw for n<=0; range(0,0) also consumes none.
    int below(int n) { return n > 0 ? range(0,n-1) : 0; }
    bool valid() const { return (increment & 1U) != 0; }
    bool operator==(const Random&) const = default;
};
}
