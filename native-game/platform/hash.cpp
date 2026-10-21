// SPDX-License-Identifier: MIT
// Source: OpenSSL EVP_DigestInit_ex/EVP_DigestUpdate/EVP_DigestFinal_ex API.
// Compare content identity with decoded/selected project data, not an inferred map.
#include "hash.h"
#include <openssl/evp.h>
#include <array>
#include <fstream>
#include <memory>
#include <stdexcept>
#include <string>
namespace transartica {
void verify_sha256(const std::filesystem::path& path, std::string_view expected) {
    std::ifstream input(path, std::ios::binary);
    if (!input) throw std::runtime_error("Missing authenticated asset: " + path.string());
    std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)> context(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!context || EVP_DigestInit_ex(context.get(), EVP_sha256(), nullptr) != 1) throw std::runtime_error("Cannot initialize asset digest");
    // Bounded streaming I/O; buffer size is not a simulation parameter.
    std::array<char, 8192> buffer{};
    while (input) {
        input.read(buffer.data(), buffer.size());
        if (EVP_DigestUpdate(context.get(), buffer.data(), static_cast<std::size_t>(input.gcount())) != 1)
            throw std::runtime_error("Cannot hash asset: " + path.string());
    }
    if (!input.eof()) throw std::runtime_error("Cannot read asset: " + path.string());
    std::array<unsigned char, EVP_MAX_MD_SIZE> bytes{};
    unsigned count{};
    if (EVP_DigestFinal_ex(context.get(), bytes.data(), &count) != 1) throw std::runtime_error("Cannot finish asset digest");
    const char hex[] = "0123456789abcdef";
    std::string digest;
    for (unsigned i = 0; i < count; ++i) { digest += hex[bytes[i] >> 4]; digest += hex[bytes[i] & 15]; }
    if (digest != expected) throw std::runtime_error("Asset SHA256 mismatch: " + path.string());
}
}
