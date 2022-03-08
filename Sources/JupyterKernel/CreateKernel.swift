import Foundation

fileprivate let signal = Python.import("signal")
fileprivate let ipykernel = Python.import("ipykernel")

@_cdecl("JupyterKernel_createSwiftKernel")
public func JupyterKernel_createSwiftKernel() {
  let fm = FileManager.default
  let runtimePath = "/opt/swift/progress/runtime_type"
  
  var currentRuntime = "python"
  if let runtimeData = fm.contents(atPath: runtimePath) {
    currentRuntime = String(data: runtimeData, encoding: .utf8)!
  }
  
  let nextRuntime = (currentRuntime == "python") ? "swift" : "python"
  fm.createFile(atPath: runtimePath, contents: nextRuntime.data(using: .utf8)!)
  
  // Until there is a built-in alternative, switch back into Python mode on the next
  // runtime restart. This makes debugging a lot easier and decreases the chance my
  // main account will be kicked off of Colab for excessive restarts/downloads.
  if nextRuntime == "swift" {
    activateSwiftKernel()
  } else {
    activatePythonKernel()
  }
}

fileprivate func activateSwiftKernel() {
  print("=== Activating Swift kernel ===")
  
  // Jupyter sends us SIGINT when the user requests execution interruption.
  // Here, we block all threads from receiving the SIGINT, so that we can
  // handle it in a specific handler thread.
  signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
  
  // TODO: launch kernel
}

fileprivate func activatePythonKernel() {
  print("=== Activating Python kernel ===")
  
  // Original Python script:
  /*
  """Entry point for launching an IPython kernel.

  This is separate from the ipykernel package so we can avoid doing imports until
  after removing the cwd from sys.path.
  """

  import sys

  if __name__ == '__main__':
      # Remove the CWD from sys.path while we load stuff.
      # This is added back by InteractiveShellApp.init_path()
      if sys.path[0] == '':
          del sys.path[0]
          # changing to:
          sys.path[0] = None

      from ipykernel import kernelapp as app
      app.launch_new_instance()
  */
  
//   let sys = Python.import("sys")
  
//   if sys.path[0] == PythonObject("") {
//     sys.path[0] = Python.None
//   }
  
//   let app = Python.import("ipykernel.kernelapp")
//   app.launch_new_instance()
}

