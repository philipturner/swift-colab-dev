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
  initReplProcess()
  try initBitWidth()
}

fileprivate func initReplProcess() {
  let environment = ProcessInfo.processInfo.environment
  let cEnvironment = CEnvironment(environment: environment)
  
  _ = KernelContext.init_repl_process(
    nil, cEnvironment.envp, FileManager.default.currentDirectoryPath)
}

fileprivate func initBitWidth() throws {
  let result = execute(code: "Int.bitWidth")
  guard let result = result as? SuccessWithValue else {
    throw Exception("Expected value from Int.bitWidth, but got: \(String(reflecting: result))")
  }
  precondition(result.description.contains("64"), 
    "Int.bitWidth returned \(result.description) when '64' was expected.")
}
