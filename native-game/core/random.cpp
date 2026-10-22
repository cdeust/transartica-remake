// SPDX-License-Identifier: MIT
#include "random.hpp"
#include <algorithm>
#include <bit>
#include <limits>
#include <stdexcept>

namespace transartica {
void Random::seed(std::uint64_t value, std::uint64_t sequence) {
    // PCG two-step initialization, pcg-random.org/using-pcg-c-basic.html.
    state = 0;
    increment = (sequence << 1U) | 1U;
    next_u32();
    state += value;
    next_u32();
}
std::uint32_t Random::next_u32() {
    // O'Neill PCG-XSH-RR 64/32 recurrence and output permutation, pcg_basic.c.
    const auto previous = state;
    state = previous * 6364136223846793005ULL + increment;
    const auto word = static_cast<std::uint32_t>((previous ^ (previous >> 18U)) >> 27U);
    return std::rotr(word, static_cast<int>(previous >> 59U));
}
std::uint32_t Random::bounded(std::uint32_t bound) {
    if (!bound) throw std::invalid_argument("Random bound must be positive");
    // PCG rejection sampling drops 2^32 mod bound values, avoiding modulo bias.
    const auto rejected = (std::uint32_t(0) - bound) % bound;
    for (;;) {
        const auto value = next_u32();
        if (value >= rejected) return value % bound;
    }
}
int Random::range(int from, int to) {
    // Existing source: core/math/random_pcg.cpp RandomPCG::random(int,int).
    if (from == to) return from;
    const std::int64_t low = std::min(from,to), high = std::max(from,to);
    const auto difference = static_cast<std::uint32_t>(high-low);
    const auto draw = difference == std::numeric_limits<std::uint32_t>::max()
        ? next_u32() : bounded(difference+1U);
    return static_cast<int>(low + draw);
}
}
