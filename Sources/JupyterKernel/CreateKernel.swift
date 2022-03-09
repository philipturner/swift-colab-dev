import Foundation

fileprivate let signal = Python.import("signal")
fileprivate let Kernel = Python.import("ipykernel.kernelbase").Kernel

@_cdecl("JupyterKernel_createSwiftKernel")
public func JupyterKernel_createSwiftKernel() {
  print("separator 0")
  PyRun_SimpleString("""
  print("separator 1")
  print(__name__)
  print(__name__ == "__main__")
  class MyClass(object):
      pass
  
  print(MyClass)
  print("separator 2")
  """)
  
  let MyClass2 = PythonClass(
    "MyClass2",
    superclasses: [Python.object],
    members: [
      "implementation": "swift",
    ]
  ).pythonObject
  
  print(MyClass2)
  print("separator 3")
  
//   let __name__ = PythonObject(OwnedPyObjectPointer(__name__Ref))
//   print(__name__)
//   assert(__name__ == "__main__")
//   assert(__name__ == Python.__name__)
  
  // use PyRun_SimpleString to assert what "__name__" is
  
  let fm = FileManager.default
  let runtimePath = "/opt/swift/runtime_type"
  
  let runtimeData = fm.contents(atPath: runtimePath)!
  let currentRuntime = String(data: runtimeData, encoding: .utf8)!.lowercased()
  
  if currentRuntime == "swift" {
    print("Debug checkpoint (Swift) in CreateKernel.swift")
  } else if currentRuntime == "python3" {
    print("Debug checkpoint (Python) in CreateKernel.swift")
  } else {
    print("Debug checkpoint (Unknown) in CreateKernel.swift")
  }
  
  // --- uncomment in development mode
  let nextRuntime = ["python3", "python"].contains(currentRuntime) ? "swift" : "python3"
  // --- uncomment in release mode
//   let nextRuntime = ["python3", "python"].contains(currentRuntime) ? "python3" : "swift"
  fm.createFile(atPath: runtimePath, contents: nextRuntime.data(using: .utf8)!)
  
  print("=== current runtime (begin) ===")
  print(currentRuntime)
  print(currentRuntime == "")
  print(currentRuntime == "swift")
  print(currentRuntime == "python3")
  print("=== current runtime (end) ===")
  
  // Until there is a built-in alternative, switch back into Python mode on the next
  // runtime restart. This makes debugging a lot easier and decreases the chance my
  // main account will be kicked off of Colab for excessive restarts/downloads.
  if ["python3", "python"].contains(currentRuntime) {
    activatePythonKernel()
  } else {
    activateSwiftKernel()
  }
}


fileprivate func activateSwiftKernel() {
  print("=== Activating Swift kernel ===")
  
  // Jupyter sends us SIGINT when the user requests execution interruption.
  // Here, we block all threads from receiving the SIGINT, so that we can
  // handle it in a specific handler thread.
  signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
  
  // Initialize the Swift kernel
  let SwiftKernel = PythonClass(
    "SwiftKernel",
    superclasses: [Kernel],
    members: [
      // How many of these members are actually necessary?
      "implementation": "swift",
      "implementation_version": "2.0",
      "banner": "",

      "language_info": [
        "name": "swift",
        "mimetype": "text/x-swift",
        "file_extension": ".swift",
        "version": ""
      ],
    
//       "__init__": PythonInstanceMethod { (params: [PythonObject]) in
//         let `self` = params[0]
//         let kwargs = params[1]
//         Kernel.__init__(`self`, kwargs)

//         return Python.None
//       }
    ]
  ).pythonObject
  
  // Description happens to be <class 'traitlets.traitlets.SwiftKernel'>
  // instead of <class '__main__.SwiftKernel'> (what is expected)
  var description = String(describing: SwiftKernel)
  description.removeFirst("<class '".count)
  description.removeLast("'>".count)
  print(Python.__name__)
  print(String(Python.__name__))
  print(description)
//   assert(description == "__main__.SwiftKernel")
//   assert(description == "traitlets.traitlets.SwiftKernel")
  
//   description = "__main__.SwiftKernel"
  
  let IPKernelApp = Python.import("ipykernel.kernelapp").IPKernelApp
  // We pass the kernel name as a command-line arg, since Jupyter gives those
  // highest priority (in particular overriding any system-wide config).
//   IPKernelApp.launch_instance(
//     argv: CommandLine.arguments + ["--IPKernelApp.kernel_class=SwiftKernel"])
  
  print(SwiftKernel)
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

