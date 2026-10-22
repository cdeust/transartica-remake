// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <utility>

namespace transartica::panels {
// Source: scripts/save_book.gd, save_slots.gd and boudoir_actions.gd.
// Owns text entry only. Application owns the normalized slot's native-format I/O.
class SaveBook {
public:
    SaveBook(Canvas&, std::filesystem::path assets);
    ~SaveBook();
    SaveBook(const SaveBook&)=delete;
    SaveBook& operator=(const SaveBook&)=delete;
    void open(bool loading);
    void draw();
    std::optional<std::string> handle_event(const SDL_Event&);
    bool active() const { return active_; }
    bool loading() const { return loading_; }
    void status(std::string message) { status_=std::move(message); }
    void close();
    static std::string normalize(std::string_view);
private:
    Canvas& canvas_;
    std::filesystem::path assets_;
    std::string name_,status_;
    std::size_t caret_{};
    bool active_{},loading_{},selected_{};
    SDL_FRect frame() const;
    void insert(std::string_view);
};
}
