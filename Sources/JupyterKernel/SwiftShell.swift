import Foundation
fileprivate let ctypes = 
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let interactiveshell = Python.import("IPython.core.interactiveshell")
fileprivate let session = Python.import("jupyter_client.session")
fileprivate let zmqshell = Python.import("ipykernel.zmqshell")

fileprivate let InteractiveShellABC = interactiveshell.InteractiveShellABC
fileprivate let ZMQInteractiveShell = zmqshell.ZMQInteractiveShell
================================================================================
// Caller side: use `ctypes` to convert return value, which is the address of a
// Python object, into an actual Python object. This Swift file stores a
// reference to the return value's object so that it doesn't deallocate.
@_cdecl("create_shell")
public func create_shell(
  _ username_id: Int64,
  _ sessionID_id: Int64, 
  _ key_id: Int64,
) {
  let (cast, py_object) = (ctypes.cast, ctypes.py_object)
  let username = cast(username_id, py_object).value
  let sessionID = cast(sessionID_id
  
  InteractiveShellABC.register(SwiftShell)
}

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

// An IPython shell, modified to work within Swift.
fileprivate let SwiftShell = PythonClass(
  "SwiftShell",
  superclasses: [ZMQInteractiveShell],
  members: [
    "kernel": Python.import("ipykernel.inprocess.ipkernel").InProcessKernel()
    
    // -------------------------------------------------------------------------
    // InteractiveShell interface
    // -------------------------------------------------------------------------
    
    // Enable GUI integration for the kernel.
    "enable_gui": PythonInstanceMethod {
      (params: [PythonObject]) in
      let `self` = params[0]
      var gui = params[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      `self`.active_eventloop = gui
      return Python.None
    }
    
    // Enable matplotlib integration for the kernel.
    "enable_matplotlib": PythonInstanceMethod {
      (params: [PythonObject]) in
      let `self` = params[0]
      var gui = params[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      try ZMQInteractiveShell.enable_matplotlib.throwing
        .dynamicallyCall(withArguments: [`self`, gui])
      return Python.None
    }
    
    // Enable pylab support at runtime.
    "enable_pylab": PythonInstanceMethod {
      (params: [PythonObject]) in
      let `self` = params[0]
      var gui = params[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      try ZMQInteractiveShell.enable_pylab.throwing
        .dynamicallyCall(withArguments: [`self`, gui])
      return Python.None
    }
  ]
).pythonObject
