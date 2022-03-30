import Foundation
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let session = Python.import("jupyter_client.session")
fileprivate let zmqshell = Python.import("ipykernel.zmqshell")
================================================================================
// Simulates a ZMQ socket, saving messages instead of sending them. We use this 
// to capture display messages.
fileprivate let CapturingSocket = PythonClass(
  "CapturingSocket",
  superclasses: [session.Session],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      `self`.messages = []
      return Python.None
    },
    
    "send_multipart": PythonInstanceMethod { (params: [PythonObject]) in
      let `self` = params[0]
      let msg = params[1]
      `self`.messages.append(msg)
      return Python.None
    }
  ]
).pythonObject
