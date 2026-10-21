// SPDX-License-Identifier: MIT
#pragma once
#include "core/random.hpp"
#include "core/session.hpp"
#include <bit>
#include <cmath>
#include <string_view>
namespace transartica::panels::art {
// Independent typed visual identity matching the existing authored emitter seed.
// Algorithms: MurmurHash3 public domain; Thomas Wang integer mix; djb2.
// Reference implementation verified in godotengine/godot 4.5:
// core/{templates/hashfuncs.h,variant/array.cpp,string/ustring.cpp,math/random_pcg.h}.
// No engine types or dynamic value compatibility layer.
inline std::uint32_t mix(std::uint32_t n,std::uint32_t seed=0x07f07c65U){n*=0xcc9e2d51U;n=std::rotl(n,15);n*=0x1b873593U;seed^=n;seed=std::rotl(seed,13);return seed*5+0xe6546b64U;}
inline std::uint32_t finish(std::uint32_t n){n^=n>>16;n*=0x85ebca6bU;n^=n>>13;n*=0xc2b2ae35U;return n^(n>>16);}
inline std::uint32_t serial_hash(std::uint64_t v){v=(~v)+(v<<18);v^=v>>31;v*=21;v^=v>>11;v+=v<<6;v^=v>>22;return std::uint32_t(v);}
inline std::uint32_t visual_seed(std::string_view kind,Point p,std::uint64_t serial){std::uint32_t text=5381;for(unsigned char c:kind)text=text*33+c;const float x=p.x==0?0:float(p.x),y=p.y==0?0:float(p.y);const auto point=finish(mix(std::bit_cast<std::uint32_t>(y),mix(std::bit_cast<std::uint32_t>(x))));return finish(mix(serial_hash(serial),mix(point,mix(text,mix(28)))));}
inline float unit_float(Random&r){const auto exp=r.next_u32();if(!exp)return 0;const auto bits=r.next_u32()|0x80000001U;return std::ldexp(float(bits),-32-std::countl_zero(exp));}
inline double uniform(Random&r,double lo,double hi){return double(float(unit_float(r)*float(hi-lo)+float(lo)));}
}
