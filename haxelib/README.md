## haxe-programmatic-compile

Small utility for running Haxe builds programmatically.

It copies an existing Haxe project into a unique temporary directory, optionally injects extra files, runs `haxe build.hxml` there, and returns the path to the produced artifact.

### Installation

```
haxelib install haxe-programmatic-compile
```

### Usage

```haxe
import haxe.io.Path;
import hpc.HaxeProgrammaticCompile;

class Example {
    static function main() {
        // 1) Optionally override where temp projects are created (defaults to OS temp dir)
        HaxeProgrammaticCompile.tempRootOverride = Path.join([Sys.getCwd(), ".tmp-builds"]);

        // 2) Point at an existing Haxe project that contains a `.hxml`
        final srcProjectDir = Path.join([Sys.getCwd(), "my-project"]);

        // 3) Create a unique temp copy of that project
        final tempDir = HaxeProgrammaticCompile.createTempProject(srcProjectDir);

        // 4) Run the build and receive the output path (file or directory, depending on target)
        final outPath = HaxeProgrammaticCompile.runBuild(tempDir);

        Sys.println("Build output: " + outPath);
    }
}
```

### Injecting files into the temp project

You can inject or override files when creating the temp project using the optional `injectFiles` map:

```haxe
import haxe.ds.StringMap;

var injectFiles = new StringMap<String>();
injectFiles.set("src/GeneratedConfig.hx", "class GeneratedConfig { public static inline var value = 42; }");

var tempDir = HaxeProgrammaticCompile.createTempProject(srcProjectDir, injectFiles);
var outPath = HaxeProgrammaticCompile.runBuild(tempDir);
```

Relative paths in `injectFiles` are resolved against the created temp directory.


