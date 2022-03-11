import Foundation

fileprivate let threading = Python.import("threading")

let SIGINTHandler = PythonClass(
  "SIGINTHandler",
  superclasses: [threading.Thread],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      self.daemon = true
    }              
  ]
).pythonObject


let StdoutHandler = PythonClass(
  "StdoutHandler",
  superclasses: [threading.Thread],
  members: [
    
  ]
).pythonObject
