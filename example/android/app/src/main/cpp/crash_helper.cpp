// Example-only JNI helpers that raise real POSIX signals so
// ApplicationExitInfo records REASON_CRASH_NATIVE with a tombstone.
// Lives in the example app so the Rivium Trace plugin stays NDK-free
// for consumers on pub.dev / Maven Central.
#include <jni.h>
#include <cstdlib>

extern "C" {

JNIEXPORT void JNICALL
Java_com_example_example_CrashHelper_nativeSigsegv(JNIEnv*, jclass) {
    volatile int* p = nullptr;
    *p = 42;
}

JNIEXPORT void JNICALL
Java_com_example_example_CrashHelper_nativeAbort(JNIEnv*, jclass) {
    abort();
}

}
