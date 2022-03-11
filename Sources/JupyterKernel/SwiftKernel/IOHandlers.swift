import Foundation

fileprivate let signal = Python.import("signal")
fileprivate let threading = Python.import("threading")

let SIGINTHandler = PythonClass(
  "SIGINTHandler",
  superclasses: [threading.Thread],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      threading.Thread.__init__(`self`)
      `self`.daemon = true
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
      while true {
        signal.sigwait([signal.SIGINT])
        KernelContext.kernel.process.SendAsyncInterrupt()
      }
      // Do not need to return anything because this is an infinite loop
    }
  ]
).pythonObject

let StdoutHandler = PythonClass(
  "StdoutHandler",
  superclasses: [threading.Thread],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      threading.Thread.__init__(`self`)
      `self`.stop_event = threading.Event()
      `self`.had_stdout = false
      return Python.None
    },
    
    "run": PythonInstanceMethod { (`self`: PythonObject) in
       while true {
         if Bool(`self`.stop_event.wait(0.1)) == true {
           break
         }
         getAndSendStdout(handler: `self`)
       }
       getAndSendStdout(handler: `self`)
       return Python.None
    }
  ]
).pythonObject

var cachedScratchBuffer: UnsafeMutablePointer<CChar>?

fileprivate func getStdout() -> String {
  var stdout = ""
  let bufferSize = 1 << 16
  let scratchBuffer = cachedScratchBuffer ?? .allocate(capacity: bufferSize + 1)
  scratchBuffer[bufferSize] = 0
  while true {
    _ = KernelContext.get_stdout(scratchBuffer, Int32(bufferSize))
    let stringSegment = String(cString: UnsafePointer(scratchBuffer))
    if stringSegment.count == 0 {
      break
    } else {
      stdout.append(stringSegment)
    }
  }
  return stdout
}

fileprivate func sendStdout() {
  let clearSequenceIndex = stdout.firstIndex(of: "\033[2J")
}

fileprivate func getAndSendStdout(handler: PythonObject) {
  let stdout = getStdout()
  if stdout.count > 0 {
    handler.had_stdout = true
  }
}
