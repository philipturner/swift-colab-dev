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
  try initReplProcess()
  try initBitWidth()
}

fileprivate func initReplProcess() throws {
  var environment = ProcessInfo.processInfo.environment
  environment.removeValue(forKey: "REPL_SWIFT_PATH")
  
  let os = Python.import("os")
  let sys = Python.import("sys")
  let scriptDir = os.path.dirname(os.path.realpath(sys.argv[0]))
  environment["PYTHONPATH"] = String(scriptDir)!
  
  let cEnvironment = CEnvironment(environment: environment)
  
  let error = KernelContext.init_repl_process(
    nil, cEnvironment.envp, FileManager.default.currentDirectoryPath)
  if error != 0 {
    throw Exception("Got error code \(error) from 'init_repl_process'")
  }
}

fileprivate func initBitWidth() throws {
  let result = execute(code: "Int.bitWidth")
  guard let result = result as? SuccessWithValue else {
    if result is SuccessWithoutValue {
      throw Exception("Got SuccessWithoutValue from Int.bitWidth")
    }
    throw Exception("Expected value from Int.bitWidth, but got: \(String(reflecting: result))")
  }
  precondition(result.description.contains("64"), 
    "Int.bitWidth returned \(result.description) when '64' was expected.")
}
