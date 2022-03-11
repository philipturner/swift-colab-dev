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
  ]
).pythonObject
