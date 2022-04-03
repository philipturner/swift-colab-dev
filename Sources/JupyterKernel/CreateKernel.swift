import Foundation

@_cdecl("JupyterKernel_createSwiftKernel")
public func JupyterKernel_createSwiftKernel() {
  let fm = FileManager.default
  let runtimePath = "/opt/swift/runtime_type"
  
  let runtimeData = fm.contents(atPath: runtimePath)!
  let currentRuntime = String(data: runtimeData, encoding: .utf8)!.lowercased()
  
  // Whether to automatically alternate between runtimes
  // Written as a closure call to suppress compiler warnings
  let isDevelopment = { true }()
  let runtime1 = isDevelopment ? "swift" : "python3" // Python in release mode
  let runtime2 = isDevelopment ? "python3" : "swift" // Swift in release mode
  
  let nextRuntime = ["python3", "python"].contains(currentRuntime) ? runtime1 : runtime2
  fm.createFile(atPath: runtimePath, contents: nextRuntime.data(using: .utf8)!)
  
  // Until there is a built-in alternative, switch back into Python mode on the next
  // runtime restart. This makes debugging a lot easier and decreases the chance my
  // main account will be kicked off of Colab for excessive restarts/downloads.
  if ["python3", "python"].contains(currentRuntime) {
    activatePythonKernel()
  } else {
    activateSwiftKernel()
  }
}

// A stored reference to the SwiftKernel type object, used as a workaround
// for the fact that it must be initialized in Python code.
fileprivate var preservedSwiftKernelRef: PythonObject!

@_cdecl("JupyterKernel_constructSwiftKernelClass")
public func JupyterKernel_constructSwiftKernelClass(_ classObj: OpaquePointer) {
  let SwiftKernel = PythonObject(OwnedPyObjectPointer(classObj))
  preservedSwiftKernelRef = SwiftKernel
  
  SwiftKernel.implementation = "swift"
  SwiftKernel.implementation_version = "0.1"
  SwiftKernel.banner = ""
  
  SwiftKernel.language_info = [
    "name": "swift",
    "mimetype": "text/x-swift",
    "file_extension": ".swift",
    "version": ""
  ]
  
  SwiftKernel.do_execute = PythonInstanceMethod { (args: [PythonObject]) in
    KernelContext.kernel = args[0]
    let code = args[1]
    var response: PythonObject?
    
    if Python.len(code) > 0 && 
       Bool(code.isspace()) == false {
      response = try doExecute(code: String(code)!)
    }
    
    return response ?? [
      "status": "ok",
      "execution_count": KernelContext.kernel.execution_count,
      "payload": [],
      "user_expressions": [:],
    ]
  }.pythonObject
}

fileprivate func activateSwiftKernel() {
  print("=== Activating Swift kernel ===")
  
  // Jupyter sends us SIGINT when the user requests execution interruption.
  // Here, we block all threads from receiving the SIGINT, so that we can
  // handle it in a specific handler thread.
  let signal = Python.import("signal")
  signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
  
  // Must create this from a Python script declaration. Using the built-in
  // `type(_:_:_:)` method makes it `traitlets.traitlets.SwiftKernel`
  // instead of `__main__.SwiftKernel`.
  PyRun_SimpleString("""
  from ctypes import *; from ipykernel.kernelbase import Kernel
  class SwiftKernel(Kernel):
      def __init__(self, **kwargs):
          super().__init__(**kwargs)
   
  func = PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_constructSwiftKernelClass
  func.argtypes = [c_void_p]; func(c_void_p(id(SwiftKernel)))
  """)
  
  let IPKernelApp = Python.import("ipykernel.kernelapp").IPKernelApp
  // We pass the kernel name as a command-line arg, since Jupyter gives those
  // highest priority (in particular overriding any system-wide config).
  IPKernelApp.launch_instance(
    argv: CommandLine.arguments + ["--IPKernelApp.kernel_class=__main__.SwiftKernel"])
}

// The original Python kernel. There is no way to get it run besides
// passing a string into the Python interpreter. No component of this
// string can be extracted into Swift.
fileprivate func activatePythonKernel() {
  print("=== Activating Python kernel ===")
  
  // Remove the CWD from sys.path while we load stuff.
  // This is added back by InteractiveShellApp.init_path()
  PyRun_SimpleString("""
  import sys; from ipykernel import kernelapp as app
  if sys.path[0] == '':
    del sys.path[0]
  
  app.launch_new_instance()          
  """)
}

