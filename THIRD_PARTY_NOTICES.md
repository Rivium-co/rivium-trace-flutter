# Third-Party Notices

`rivium_trace_flutter_sdk` incorporates the following third-party components.
Their licenses are reproduced in full below.

---

## PLCrashReporter (iOS)

Used to capture native iOS crashes (POSIX signals + Mach exceptions).
Vendored as a static xcframework at `ios/Vendor/CrashReporter.xcframework/`.

- Homepage: https://github.com/microsoft/plcrashreporter
- Version: 1.12.0
- License: MIT

```
Copyright (c) 2008-2014 Plausible Labs Cooperative, Inc.
Copyright (c) 2020 Microsoft Corporation
All rights reserved.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
```

---

## AOSP `tombstone.proto` (Android)

Used to parse the binary tombstone protobuf produced by
`ApplicationExitInfo.getTraceInputStream()` on Android API 30+.
Vendored at `android/src/main/proto/tombstone.proto`.

- Source: https://android.googlesource.com/platform/system/core/+/refs/heads/main/debuggerd/proto/tombstone.proto
- License: Apache License 2.0
- Local modifications: `java_package` overridden to avoid a classloader
  collision with the framework's built-in `com.android.server.os.TombstoneProtos`
  stub. All schema definitions unchanged.

```
Copyright (C) 2020 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## Google Protobuf (Android)

Runtime library used to parse the vendored `tombstone.proto`.
Depended on via Gradle: `com.google.protobuf:protobuf-javalite:3.25.5`.

- Homepage: https://github.com/protocolbuffers/protobuf
- License: BSD-3-Clause

The library is not vendored; consumers pull it transitively from Maven Central.
See the upstream repository for the full license text.
