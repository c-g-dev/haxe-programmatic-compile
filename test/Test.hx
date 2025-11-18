
import haxe.io.Path;
import sys.FileSystem;
import hpc.HaxeProgrammaticCompile;

class Test {
	static function main() {
		testCreateTempProjectAndRunBuild();
	}

	static function assertTrue(condition:Bool, ?message:String):Void {
		if (!condition) {
			var msg = message != null ? message : "assertTrue failed";
			throw msg;
		}
	}

	static function testCreateTempProjectAndRunBuild() {
		var cwd = Sys.getCwd();
		var tempRoot = Path.join([cwd,  ".tmp-builds"]);
		HaxeProgrammaticCompile.tempRootOverride = tempRoot;

		var srcProjectDir = Path.join([cwd,  "test-project"]);
		var tempDir = HaxeProgrammaticCompile.createTempProject(srcProjectDir);

		assertTrue(FileSystem.exists(tempDir));
		assertTrue(FileSystem.isDirectory(tempDir));
		assertTrue(FileSystem.exists(Path.join([tempDir, "build.hxml"])));
		assertTrue(FileSystem.exists(Path.join([tempDir, "src"])));

		var outPath = HaxeProgrammaticCompile.runBuild(tempDir);
		assertTrue(outPath != null && outPath.length > 0, "Output path should not be empty");
		assertTrue(FileSystem.exists(outPath), "Output path should exist: " + outPath);
	}
}
