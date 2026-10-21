// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "core/random.hpp"
#include <array>
#include <map>
#include <optional>
#include <utility>

namespace transartica::economy {
// Sources: city_trade.gd; GLIEU transactions documented in city-scripts.md.
inline constexpr int Buy=50, Sell=51, Town=1, Commercial=2, Garrison=4, MammothFair=5, SlaveMarket=6;
inline constexpr int NoRoom=51, NothingToSell=18, NoMoney=50, NotEnoughLoad=52, NoCoalRoom=54,
    StockLimit=1, WagonsFull=17, TenderLimit=2;
struct Offer {
    int buy{}, sell{}, wagon_a{}, cap_a{}, wagon_b{}, cap_b{};
    int city{}, kind{}, mode{}, goods{};
    bool spy{};
    bool operator==(const Offer&) const = default;
};
struct Capacity { int room{}, loaded{}; };
struct Entry { int type{}, price{}; bool operator==(const Entry&) const = default; };
struct GoodsRow { int goods{}, quantity{}; bool operator==(const GoodsRow&) const = default; };
struct TradeState {
    std::array<std::array<int,16>,22> stock{};
    std::array<int,20> spy_slots{};
    bool valid() const;
    bool operator==(const TradeState&) const = default;
};
class Trade {
public:
    // Atomic parse. directory is game/data, never a generated asset path.
    bool load(const std::filesystem::path& directory, std::string& error);
    bool loaded() const { return loaded_; }
    void reset(Random&);
    void visit(int city, Random&);
    const TradeState& snapshot() const { return state_; }
    bool restore(const TradeState&);
    // Campaign spy transitions share these slots with commerce; restore validates.
    bool set_spy_slot(int slot, int state);
    bool offers_spies(int city) const;
    std::string goods_name(int goods) const;
    std::string wagon_name(int type) const;
    std::optional<Offer> offer(int city,int kind,int mode,int goods=0) const;
    static int price(const Offer&);
    static int total(const Offer&,int quantity);
    std::vector<GoodsRow> goods_list(int city,int mode,const std::vector<Wagon>&) const;
    Capacity capacity(const Offer&,const std::vector<Wagon>&) const;
    int entry_refusal(const Offer&,const std::vector<Wagon>&) const;
    int increment_refusal(const Offer&,int quantity,const std::vector<Wagon>&,const EngineState&) const;
    // Revalidate at commit to prevent stale modal choices from mutating resources.
    // Returns refusal code, or zero. Zero quantity is a no-op.
    int commit(const Offer&,int quantity,std::vector<Wagon>&,EngineState&);
    std::vector<Entry> workshop_list(int city) const;
    static int intact_tenders(const std::vector<Wagon>&);
    static int workshop_refusal(Entry,int quantity,const std::vector<Wagon>&,const EngineState&);
    static int buy_wagons(Entry,int quantity,std::vector<Wagon>&,EngineState&);
private:
    bool loaded_{};
    TradeState state_;
    std::array<std::array<std::pair<int,int>,16>,22> stock_init_{};
    std::array<std::string,16> goods_names_;
    std::array<std::string,25> wagon_names_;
    std::map<int,std::array<Offer,16>> goods_;
    std::map<int,Offer> mammoths_,slaves_,soldiers_,spies_;
    std::map<int,std::vector<Entry>> workshop_;
    static bool accepts(const Offer&,const Wagon&,int type);
};
}
