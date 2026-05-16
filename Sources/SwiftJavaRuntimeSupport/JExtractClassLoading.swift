//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJava
import SwiftJavaJNICore

/// Load a generated JExtract Java class using the current JNI context, falling
/// back to the application class loader when called from an attached Swift
/// thread where `FindClass` cannot see application classes.
public func _swiftJavaLoadJExtractClass(_ className: String, environment: JNIEnvironment) -> JavaObjectHolder {
  if let jniClass = environment.interface.FindClass(environment, className) {
    return JavaObjectHolder(object: jniClass, environment: environment)
  }

  environment.interface.ExceptionClear(environment)

  guard let jni = JNI.shared else {
    fatalError("Cannot get JNI.shared, it should have been initialized by JNI_OnLoad when loading the library")
  }

  guard let javaClass = try? jni.applicationClassLoader?.loadClass(className.replacing("/", with: ".")) else {
    fatalError("Class \(className) could not be found!")
  }

  return javaClass.javaHolder
}
