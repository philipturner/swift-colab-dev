import Foundation

fileprivate struct CEnvironment {
  var envp: OpaquePointer
  
  init() {
    var envArray: [String] = []
    for (key, value) in ProcessInfo.processInfo.environment {
      environmentArray.append("\(key)=\(value)")
    }
    typealias EnvPointerType = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    let envPointer = EnvPointer.allocate(capacity: envArray.count + 1)
    envPointer[envArray.count] = nil
    envp = OpaquePointer(malloc(8))
  }
}

func initSwift() throws {
  KernelContext.initialize_debugger(nil)
}
