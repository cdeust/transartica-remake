// SPDX-License-Identifier: MIT
// Source spy_report.gd TEXTEK0x27f4..2bf0, including original heading labels.
#include "controller.hpp"
namespace transartica::campaign {
namespace {
void direction(Lines& lines,int heading,const Data& data) {
    constexpr std::array<int,8> offsets{0x2b28,0x2b43,0x2b59,0x2b74,0x2b89,0x2ba4,0x2bba,0x2bd5};
    if(heading>0&&heading<=8) lines.push_back(data.phrase(false,0x2aec)+data.phrase(false,offsets[heading-1]));
}
void mover(Lines& lines,int code,const State& state,const Data& data,const Host& host) {
    int heading=0;
    if(code>39&&code<50) {
        auto info=host.mover_info(code);if(!info) return;
        lines.push_back(data.phrase(false,0x28a5));int quantity=info->quantity<20?info->quantity:info->quantity/10*10;
        int offset=info->quantity<20?0x28de:0x2913;
        lines.push_back(data.phrase(false,offset)+std::to_string(quantity)+data.phrase(false,offset,1));heading=info->heading;
    } else if(code==60||code==70) {
        lines.push_back(data.phrase(false,code==60?0x295e:0x29ac));lines.push_back(data.phrase(false,code==60?0x297e:0x29cc));
        if(code==60) heading=state.fauna.heading;else if(auto info=host.mover_info(code)) heading=info->heading;
    }
    direction(lines,heading,data);
}
}
Lines spy_report(int index,const State& state,const Data& data,const Host& host) {
    Lines lines;if(index<0||index>=20) return lines;const auto& r=state.spies[index];
    auto title=data.report_phrases.find(0x27fe),stamp=data.report_phrases.find(0x283e);
    if(title==data.report_phrases.end()||stamp==data.report_phrases.end()||title->second.size()!=3||stamp->second.size()!=3) return lines;
    const auto& t=title->second;const auto& s=stamp->second;
    lines.push_back(t[0]+std::to_string(index+1)+t[1]+std::to_string(r[1]+40)+t[2]+std::to_string(r[2])+s[0]+std::to_string(r[9])+s[1]+std::to_string(r[10])+s[2]+std::to_string(r[11]));
    if(r[7]>=40) {mover(lines,int(r[7]),state,data,host);return lines;}
    auto enemy=host.enemy_info(int(r[7])-1);if(!enemy) return lines;
    int strength=enemy->strength/20;lines.push_back(data.phrase(false,strength<3?0x2a1a:0x2a41));
    int level=strength%20;lines.push_back(data.phrase(false,level<7?0x2a73:level<14?0x2a9c:0x2ab9));direction(lines,enemy->heading,data);return lines;
}
}
