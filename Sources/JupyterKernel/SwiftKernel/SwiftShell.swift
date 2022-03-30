import Foundation
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let session = Python.import("jupyter_client.session")
fileprivate let zmqshell = Python.import("ipykernel.zmqshell")

// TODO: Expose `create_shell` to C, so that KernelCommunicator can call into it
// without bloating that file. Also, it lets me validate that this actually
// compiles on a regular basis.

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
  superclasses: [zmqshell.ZMQInteractiveShell],
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
      try zmqshell.ZMQInteractiveShell.enable_matplotlib.throwing
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
      try zmqshell.ZMQInteractiveShell.enable_pylab.throwing
        .dynamicallyCall(withArguments: [`self`, gui])
      return Python.None
    }
  ]
).pythonObject

func create_shell
