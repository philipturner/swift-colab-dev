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

fileprivate let SwiftKernel = PythonClass(
  "SwiftKernel",
  superclasses: [Kernel],
  members: [
    
  ]
)

fileprivate func activateSwiftKernel() {
  print("=== Activating Swift kernel ===")
  
  // Jupyter sends us SIGINT when the user requests execution interruption.
  // Here, we block all threads from receiving the SIGINT, so that we can
  // handle it in a specific handler thread.
  signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
  
  // Initialize the Swift kernel
  _ = SwiftKernel
  
  let IPKernelApp = Python.import("ipykernel.kernelapp").IPKernelApp
  // We pass the kernel name as a command-line arg, since Jupyter gives those
  // highest priority (in particular overriding any system-wide config).
  IPKernelApp.launch_instance(
    argv: CommandLine.arguments + ["--IPKernelApp.kernel_class=__main__.SwiftKernel"])
}

// The original Python kernel. There is no way to get it run besides
// passing a string into the Python interpreter. No component of the
// string can be extracted into Swift.
fileprivate func activatePythonKernel() {
  print("=== Activating Python kernel ===")
  
  // Remove the CWD from sys.path while we load stuff.
  // This is added back by InteractiveShellApp.init_path()
  PyRun_SimpleString("""
  import sys
  if sys.path[0] == '':
    del sys.path[0]
  
  from ipykernel import kernelapp as app
  app.launch_new_instance()          
  """)
}

