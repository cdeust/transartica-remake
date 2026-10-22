// SPDX-License-Identifier: MIT
#pragma once
#include <filesystem>
#include <map>
#include <string>

namespace transartica {
// Native envelope. Component payloads are typed and validated by their owners;
// the file is replaced once only after every component has been serialized.
using SaveSections=std::map<std::string,std::string>;
bool write_archive(const std::filesystem::path&,const SaveSections&,std::string& error);
bool read_archive(const std::filesystem::path&,SaveSections&,std::string& error);
}
