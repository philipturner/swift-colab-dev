import Foundation

fileprivate let threading = Python.import("threading")

let SIGINTHandler = PythonClass(
  "SIGINTHandler",
  superclasses: [threading.Thread],
  members: [
    
  ]
).pythonObject


let StdoutHandler = PythonClass(
  "StdoutHandler",
  superclasses: [threading.Thread],
  members: [
    
  ]
).pythonObject
