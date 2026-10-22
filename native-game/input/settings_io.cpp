// SPDX-License-Identifier: MIT
#include "settings_io.h"
#include <fstream>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
namespace transartica::input {
bool replace_preferences(const std::filesystem::path& file,const std::string& text,std::string& error) {
    std::error_code ec;std::filesystem::create_directories(file.parent_path(),ec);
    if(ec) {error="Cannot create keyboard preferences directory: "+ec.message();return false;}
    auto pending=file;pending+=".pending";
    if(!std::filesystem::create_directory(pending,ec)) {error="Keyboard preferences are already claimed: "+pending.string();return false;}
    const auto temporary=pending/"settings.tmp";bool committed=false;
    {
        std::ofstream out(temporary,std::ios::binary);out<<text;out.flush();
        if(!out) error="Cannot write complete keyboard preferences";
        else {
            out.close();
            if(out.fail()) error="Cannot close keyboard preferences";
            else {
#ifdef _WIN32
                committed=MoveFileExW(temporary.c_str(),file.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)!=0;
                if(!committed) error="Cannot replace keyboard preferences: Windows error "+std::to_string(GetLastError());
#else
                std::filesystem::rename(temporary,file,ec);committed=!ec;
                if(ec) error="Cannot replace keyboard preferences: "+ec.message();
#endif
            }
        }
    }
    std::filesystem::remove(temporary,ec);std::filesystem::remove(pending,ec);
    if(committed) error.clear();
    return committed;
}
}
