// SPDX-License-Identifier: MIT
#include "core/random.hpp"
#include <array>
#include <iostream>
#include <limits>

int main() {
    transartica::Random random;
    random.seed(42,54);
    // Published PCG demo vector, pcg-random.org/using-pcg-c-basic.html, Round1.
    constexpr std::array<std::uint32_t,6> reference{
        0xa15c02b7,0x7b47f409,0xba1d3330,0x83d2f293,0xbfa4784b,0xcbed606e};
    for (const auto expected:reference) if(random.next_u32()!=expected) return 1;
    const auto before = random;
    if(random.below(0)!=0 || random.below(-1)!=0 || random.range(7,7)!=7 || random!=before) return 2;
    auto resumed = random;
    // Every value of the source byte-sized bounds, including reversed endpoints.
    for(int n=1;n<=256;++n) {
        const auto value = random.below(n);
        if(value<0 || value>=n || value!=resumed.range(n-1,0)) return 3;
    }
    const auto full = random.range(std::numeric_limits<int>::min(),std::numeric_limits<int>::max());
    const auto expected = std::int64_t(std::numeric_limits<int>::min())+resumed.next_u32();
    if(full!=expected || random!=resumed || !random.valid()) return 4;
    try { random.bounded(0); return 5; } catch(const std::invalid_argument&) {}
    std::cout << "PCG reference vector, source range semantics and resume passed\n";
}
