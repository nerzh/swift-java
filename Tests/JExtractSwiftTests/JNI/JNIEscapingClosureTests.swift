//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JExtractSwiftLib
import Testing

@Suite
struct JNIEscapingClosureTests {
  let source =
    """
    public class CallbackManager {
      private var callback: (() -> Void)?
      
      public init() {}
      
      public func setCallback(callback: @escaping () -> Void) {
        self.callback = callback
      }
      
      public func triggerCallback() {
        callback?()
      }
      
      public func clearCallback() {
        callback = nil
      }
    }

    public func delayedExecution(closure: @escaping (Int64) -> Int64, input: Int64) -> Int64 {
      // Simplified for testing - would normally be async
      return closure(input)
    }
    """

  @Test
  func escapingEmptyClosure_javaBindings() throws {
    let simpleSource =
      """
      public func setCallback(callback: @escaping () -> Void) {}
      """

    try assertOutput(
      input: simpleSource,
      .jni,
      .java,
      expectedChunks: [
        """
        public static class setCallback {
          @FunctionalInterface
          public interface callback {
            void apply();
          }
        }
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func setCallback(callback: @escaping () -> Void)
         * }
         */
        public static void setCallback(com.example.swift.SwiftModule.setCallback.callback callback) {
          SwiftModule.$setCallback(callback);
        }
        """,
      ]
    )
  }

  @Test
  func escapingClosureWithParameters_javaBindings() throws {
    let source =
      """
      public func delayedExecution(closure: @escaping (Int64) -> Int64) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        public static class delayedExecution {
          @FunctionalInterface
          public interface closure {
            long apply(long _0);
          }
        }
        """
      ]
    )
  }

  @Test
  func escapingClosure_swiftThunks() throws {
    let source =
      """
      public func setCallback(callback: @escaping () -> Void) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let closureContext_callback$ = JavaObjectHolder(object: callback, environment: environment)
        """
      ]
    )
  }

  @Test
  func escapingClosureWithStringResult_swiftThunks() throws {
    let source =
      """
      public func setCallback(callback: @escaping (String) -> String) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let closureContext_callback$ = JavaObjectHolder(object: callback, environment: environment)
        """,
        """
        let methodID$ = environment.interface.GetMethodID(environment, class$, "apply", "(Ljava/lang/String;)Ljava/lang/String;")!
        """,
        """
        return String(fromJNI: environment.interface.CallObjectMethodA(environment, closureObject$, methodID$, arguments$), in: environment)
        """,
      ]
    )
  }

  @Test
  func escapingClosureWithCustomStruct_swiftThunks() throws {
    let source =
      """
      public struct Fee {
        public var value: Int64

        public init(value: Int64) {
          self.value = value
        }
      }

      public func setCallback(callback: @escaping (Fee) -> Fee) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let _0Pointer$ = UnsafeMutablePointer<Fee>.allocate(capacity: 1)
        """,
        """
        let _0ClassHolder$ = _swiftJavaLoadJExtractClass("com/example/swift/Fee", environment: environment)
        """,
        """
        let arguments$: [jvalue] = [jvalue(l: _0Object$)]
        """,
        """
        let closureResultMemoryAddress$ = environment.interface.CallLongMethodA(environment, closureResultObject$, _JNIMethodIDCache.JNISwiftInstance.memoryAddress, [])
        """,
        """
        return closureResultMemoryAddress$$.pointee
        """,
      ]
    )
  }

  @Test
  func escapingClosureWithOptionalCustomStructResult_swiftThunks() throws {
    let source =
      """
      public struct Fee {
        public var value: Int64

        public init(value: Int64) {
          self.value = value
        }
      }

      public func setCallback(callback: @escaping () -> Fee?) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let methodID$ = environment.interface.GetMethodID(environment, class$, "apply", "()Ljava/util/Optional;")!
        """,
        """
        let closureResultOptional$ = environment.interface.CallObjectMethodA(environment, closureObject$, methodID$, arguments$)
        """,
        """
        let closureResultValue$: Fee?
        """,
        """
        let closureResultOptionalIsPresentValue$ = Bool(fromJNI: environment.interface.CallBooleanMethodA(environment, closureResultOptional$, closureResultOptionalIsPresent$, []), in: environment)
        """,
        """
        let closureResultObject$ = environment.interface.CallObjectMethodA(environment, closureResultOptional$, closureResultOptionalGet$, [])
        """,
        """
        closureResultValue$ = closureResultPointer$.pointee
        """,
        """
        return closureResultValue$
        """,
      ]
    )
  }

  @Test
  func escapingClosureWithOptionalCustomStructResult_javaBindings() throws {
    let source =
      """
      public struct Fee {
        public var value: Int64

        public init(value: Int64) {
          self.value = value
        }
      }

      public func setCallback(callback: @escaping () -> Fee?) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public interface callback {
          java.util.Optional<Fee> apply();
        }
        """,
      ]
    )
  }

  @Test
  func escapingThrowingClosureWithOptionalCustomStructResult_javaBindings() throws {
    let source =
      """
      public struct Fee {
        public var value: Int64

        public init(value: Int64) {
          self.value = value
        }
      }

      public func setCallback(callback: @escaping (Fee) throws -> Fee?) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public interface callback {
          java.util.Optional<Fee> apply(Fee _0) throws Exception;
        }
        """,
      ]
    )
  }

  @Test
  func escapingThrowingClosureWithOptionalCustomStructResult_swiftThunks() throws {
    let source =
      """
      public struct Fee {
        public var value: Int64

        public init(value: Int64) {
          self.value = value
        }
      }

      public func setCallback(callback: @escaping (Fee) throws -> Fee?) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public func Java_com_example_swift_SwiftModule__00024setCallback__Lcom_example_swift_SwiftModule_00024setCallback_00024callback_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, callback: jobject?) {
        """,
        """
        return { _0 in
          let environment = try JavaVirtualMachine.shared().environment()
        """,
        """
        let closureResultOptional$ = try environment.translatingJNIExceptions { environment.interface.CallObjectMethodA(environment, closureObject$, methodID$, arguments$) }
        """,
        """
        return closureResultValue$
        """,
      ]
    )
  }

  @Test
  func nonEscapingClosure_stillWorks() throws {
    let source =
      """
      public func call(closure: () -> Void) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        @FunctionalInterface
        public interface closure {
          void apply();
        }
        """
      ]
    )
  }
}
