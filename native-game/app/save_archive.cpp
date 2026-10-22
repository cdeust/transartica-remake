// SPDX-License-Identifier: MIT
// Transaction contract: session_saves.gd stages extensions before committing.
// Native file replacement follows core/save.cpp, with no cross-file transaction.
#include "save_archive.h"
#include <fstream>
#include <locale>
#include <sstream>
#include <system_error>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#endif

namespace transartica {
namespace {
// Existing native save resource policy (core/save.cpp): 1/64 of task's 1-GiB cap.
constexpr std::uintmax_t maximum_bytes=(1024ULL*1024*1024)/64;
bool name_valid(const std::string& name) {
    return !name.empty() && name.find_first_not_of("abcdefghijklmnopqrstuvwxyz_")==std::string::npos;
}
bool replace(const std::filesystem::path& from,const std::filesystem::path& to,std::string& error) {
#ifdef _WIN32
    if(!MoveFileExW(from.c_str(),to.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)) {
        error="Save replacement failed: Windows error "+std::to_string(GetLastError());return false;
    }
#else
    std::error_code ec;std::filesystem::rename(from,to,ec);
    if(ec) {error="Save replacement failed: "+ec.message();return false;}
#endif
    return true;
}
bool parse(std::istream& input,std::uintmax_t file_bytes,SaveSections& sections) {
    std::string line;
    if(!std::getline(input,line) || input.eof() || line!="TRANSARTICA_NATIVE_GAME 1") return false;
    std::uintmax_t consumed=line.size()+1;
    while(std::getline(input,line)) {
        if(input.eof()) return false; // Every envelope record has its written newline.
        consumed+=line.size()+1;
        if(line=="END") {input>>std::ws;return input.eof() && !sections.empty();}
        std::istringstream header(line);header.imbue(std::locale::classic());
        std::string marker,name,extra;std::uintmax_t size{};
        if(!(header>>marker>>name>>size) || marker!="SECTION" || !name_valid(name) || (header>>extra)) return false;
        if(sections.contains(name) || consumed>file_bytes || size>file_bytes-consumed) return false;
        std::string payload(static_cast<std::size_t>(size),'\0');
        if(!input.read(payload.data(),static_cast<std::streamsize>(size)) || input.get()!='\n') return false;
        consumed+=size+1;sections.emplace(std::move(name),std::move(payload));
    }
    return false;
}
}
bool write_archive(const std::filesystem::path& path,const SaveSections& sections,std::string& error) {
    std::ostringstream text;text.imbue(std::locale::classic());
    text<<"TRANSARTICA_NATIVE_GAME 1\n";
    for(const auto& [name,payload]:sections) {
        if(!name_valid(name) || payload.size()>maximum_bytes) {error="Invalid save section";return false;}
        text<<"SECTION "<<name<<' '<<payload.size()<<'\n'<<payload<<'\n';
        if(static_cast<std::uintmax_t>(text.tellp())>maximum_bytes) {error="Save exceeds native input budget";return false;}
    }
    text<<"END\n";
    if(sections.empty() || static_cast<std::uintmax_t>(text.tellp())>maximum_bytes) {error="Invalid save size";return false;}
    auto pending=path;pending+=".pending";std::error_code ec;
    if(!std::filesystem::create_directory(pending,ec)) {error="Cannot claim save directory: "+pending.string();return false;}
    const auto staged=pending/"game.tmp";bool committed=false;
    {
        std::ofstream out(staged,std::ios::binary);out<<text.str();out.flush();
        if(!out) error="Cannot write complete game save";
        else {out.close();if(out.fail()) error="Cannot close game save";else committed=replace(staged,path,error);}
    }
    std::filesystem::remove(staged,ec);std::filesystem::remove(pending,ec);
    if(committed) error.clear();
    return committed;
}
bool read_archive(const std::filesystem::path& path,SaveSections& sections,std::string& error) {
    std::error_code ec;const auto size=std::filesystem::file_size(path,ec);
    if(ec || size>maximum_bytes) {error="Missing or oversized native game save";return false;}
    std::ifstream input(path,std::ios::binary);SaveSections staged;
    if(!input || !parse(input,size,staged)) {error="Invalid or truncated native game save; current state preserved";return false;}
    sections=std::move(staged);error.clear();return true;
}
}
