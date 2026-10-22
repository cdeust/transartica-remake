// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include <optional>
namespace transartica::economy {
struct City { std::string name; Cell anchor; std::string type; int kind{}; };
// Source world_data.gd; exact neutral-extension CSV and CARTE bytes.
class WorldData {
public:
    bool load(const std::filesystem::path& private_data,std::string& error);
    const std::vector<City>& cities() const { return cities_; }
    const City* city(int index) const;
    std::optional<int> city_at(Cell) const;
    int map_code(Cell) const;
    std::vector<Cell> city_anchors() const;
private:
    std::vector<City> cities_;
    std::vector<unsigned char> map_;
};
}
