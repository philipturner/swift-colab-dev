import Foundation

fileprivate struct CEnvironment {
  var envp: OpaquePointer
  
  init(environment: [String: String]) {
    var envArray: [String] = []
    for (key, value) in environment {
      envArray.append("\(key)=\(value)")
    }
    typealias EnvPointerType = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    let envPointer = EnvPointerType.allocate(capacity: envArray.count + 1)
    envPointer[envArray.count] = nil
    for i in 0..<envArray.count {
      let originalStr = envArray[i]
      let strPointer = UnsafeMutablePointer<CChar>.allocate(capacity: originalStr.count + 1)
      _ = originalStr.withCString {
        memcpy(strPointer, $0, originalStr.count + 1)
      }
      envPointer[i] = strPointer
    }
    envp = OpaquePointer(envPointer)
  }
}

func initSwift() throws {
  let environment = ProcessInfo.processInfo.environment
  let cEnvironment = CEnvironment(environment: environment)
  
  let err = KernelContext.init_repl_process(
    nil, cEnvironment.envp, FileManager.default.currentDirectoryPath)
}
