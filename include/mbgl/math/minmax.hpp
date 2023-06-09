#pragma once

#include <type_traits>
#include <algorithm>
#include <cmath>

namespace mbgl {
namespace util {

template <typename T>
typename std::enable_if_t<std::is_integral_v<T>, T> max(T a, T b) {
    return std::max(a, b);
}

template <typename T>
typename std::enable_if_t<std::is_floating_point_v<T>, T> max(T a, T b) {
    return ::fmax(a, b);
}

template <typename T, typename... Ts>
typename std::enable_if_t<std::is_arithmetic_v<T>, T> max(T a, T b, Ts... args) {
    return max(a, max(b, args...));
}

template <typename T>
typename std::enable_if_t<std::is_integral_v<T>, T> min(T a, T b) {
    return std::min(a, b);
}

template <typename T>
typename std::enable_if_t<std::is_floating_point_v<T>, T> min(T a, T b) {
    return ::fmin(a, b);
}

template <typename T, typename... Ts>
typename std::enable_if_t<std::is_arithmetic_v<T>, T> min(T a, T b, Ts... args) {
    return min(a, min(b, args...));
}

} // namespace util
} // namespace mbgl
