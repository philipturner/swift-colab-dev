import Foundation
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let session = Python.import("jupyter_client.session")
fileprivate let zmqshell = Python.import("ipykernel.zmqshell")

// TODO: Move this module out of JupyterKernel package and into 
// KernelCommunicator

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

fileprivate func realEnableGUI(_ gui: PythonObject) {
  
}

================================================================================
// An IPython shell, modified to work within Swift.
fileprivate let SwiftShell = PythonClass(
  "SwiftShell",
  superclasses: [zmqshell.ZMQInteractiveShell],
  members: [
    "enable_gui": PythonInstanceMethod {
      (params: [PythonObject]) in
      let `self` = params[0]
      let gui = params[1]
      realEnableGUI(gui)
      `self`.active_eventloop = gui
    }
  ]
).pythonObject
