import Foundation

fileprivate struct CEnvironment {
  var envp: OpaquePointer
  
  init() {
    var environmentArray: [String] = []
    for (key, value) in ProcessInfo.processInfo.environment {
      
    }
    
    envp = OpaquePointer(malloc(8))
  }
}

func initSwift() throws {
  KernelContext.initialize_debugger(nil)
}
