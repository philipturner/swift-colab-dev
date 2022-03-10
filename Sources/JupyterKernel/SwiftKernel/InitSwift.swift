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
    for i in 0..<envArray.count {
      let strPointer = UnsafeMutablePointer<CChar>.allocate(envArray.count + 1)
      envArray[i].withCString {
        memcpy(strPointer, $0, envArray.count + 1)
      }
      envPointer[i] = strPointer
    }
    envp = OpaquePointer(envPointer)
  }
}

func initSwift() throws {
  KernelContext.initialize_debugger(nil)
}
