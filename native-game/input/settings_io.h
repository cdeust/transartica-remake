// SPDX-License-Identifier: MIT
#pragma once
#include <filesystem>
#include <string>
namespace transartica::input {
// Transaction pattern matches core/save.cpp: claim an exclusive staging directory,
// flush/close the complete file, then atomically replace the one preferences file.
bool replace_preferences(const std::filesystem::path&,const std::string&,std::string& error);
}
