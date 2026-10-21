// SPDX-License-Identifier: MIT
#pragma once
#include "types.hpp"
#include <map>
namespace transartica::campaign {
struct QuizRecord { int page{},line{},word{}; std::string answer; };
struct RegionTile { Cell cell; int code{}; };
// Only private campaign.json supplies historical text and decoded region data.
struct Data {
    std::map<std::string,std::vector<RegionTile>> regions;
    std::map<int,Lines> messages,documents,epitaphs,report_phrases,ambush_phrases;
    std::map<int,std::string> wagon_names;
    std::map<std::string,std::string> mine_bulletin;
    std::array<std::vector<QuizRecord>,2> quizzes;
    bool load(const std::filesystem::path&,std::string& error);
    Lines message(int id,bool document=false) const;
    std::string phrase(bool ambush,int offset,std::size_t index=0) const;
    Lines quiz_lines(const Quiz&) const;
};
}
