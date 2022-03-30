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
    
  ]
).pythonObject
