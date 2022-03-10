import Foundation

struct KernelContext {
  var debuggerInitialized = false
  
  let validation_test: @convention(c) (UnsafePonter<CChar>) -> Int32 = 
    LLDBProcessLibrary.loadSymbol(name: "validation_test")
}

fileprivate struct LLDBProcessLibrary {
  static var lldb_process: UnsafeMutableRawPointer = {
    _ = dlopen("/opt/swift/toolchain/usr/lib/liblldb.so", RTLD_LAZY | RTLD_GLOBAL)!
    return dlopen("/opt/swift/lib/liblldb_process.so", RTLD_LAZY | RTLD_GLOBAL)!
  }
  
  static func loadSymbol<T>(name: String) -> T {
    let address = dlsym(lldb_process, name)
    return unsafeBitCast(address, to: T.self)
  }
}
