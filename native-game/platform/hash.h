// SPDX-License-Identifier: MIT
#pragma once
#include <filesystem>
#include <string_view>
namespace transartica {
void verify_sha256(const std::filesystem::path&, std::string_view expected);
}
