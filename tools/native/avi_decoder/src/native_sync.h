#pragma once
#include <mutex>
#include <condition_variable>
using NativeMutex = std::recursive_mutex;
using NativeMutexLock = std::lock_guard<NativeMutex>;
class NativeSemaphore {
    std::mutex mutex;
    std::condition_variable condition;
    unsigned count = 0;
public:
    void post() { { std::lock_guard<std::mutex> lock(mutex); ++count; } condition.notify_one(); }
    void wait() { std::unique_lock<std::mutex> lock(mutex); condition.wait(lock,[this]{return count>0;}); --count; }
};
