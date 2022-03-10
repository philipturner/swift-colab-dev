import Foundation

struct KernelContext {
  static var debuggerInitialized = false
  
  static let validation_test: @convention(c) (UnsafePointer<CChar>) -> Int32 = 
    LLDBProcessLibrary.loadSymbol(name: "validation_test")
  
  static let initialize_debugger: @convention(c) () -> Void = 
    LLDBProcessLibrary.loadSymbol(name: "initialize_debugger")
}

fileprivate struct LLDBProcessLibrary {
  static var lldb_process: UnsafeMutableRawPointer = {
    _ = dlopen("/opt/swift/toolchain/usr/lib/liblldb.so", RTLD_LAZY | RTLD_GLOBAL)!
    return dlopen("/opt/swift/lib/liblldb_process.so", RTLD_LAZY | RTLD_GLOBAL)!
  }()
  
  static func loadSymbol<T>(name: String) -> T {
    let address = dlsym(lldb_process, name)
    return unsafeBitCast(address, to: T.self)
  }
}
