package;

import haxe.io.Path;
using StringTools;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#if js
import js.node.ChildProcess;
#end

/**
	Utility for on-demand, programmatic Haxe builds.
	
	- createTempProject(sourceDir, ?injectFiles): copies a project into a unique temp folder and returns the new directory.
	- runBuild(projectDir): runs `haxe build.hxml` in that directory and returns the path to the produced artifact (file or directory depending on target).
	
	Notes:
	- This utility assumes a `build.hxml` exists in the project root.
	- Output path is derived from the first target directive found in `build.hxml` (e.g. -js, -lua, -cpp, -cs, -java, -php, -python, -neko, -hl, -swf, -jvm, -as3, -cppia).
	- For directory-based targets (e.g. -cpp, -cs, -java, -php, -jvm, -as3), the returned path is the output directory.
	- No exceptions are caught by design (fail fast).
*/
class HaxeProgrammaticCompile {
	public static var tempRootOverride:String = null;
	public static function createTempProject(sourceProjectDir:String, ?injectFiles:Map<String, String>):String {
		final normalizedSource = normalizeDir(sourceProjectDir);
		if (!FileSystem.exists(normalizedSource) || !FileSystem.isDirectory(normalizedSource)) {
			throw 'Source project directory not found: ' + normalizedSource;
		}
		
		final tempRoot = getTempRoot();
		final uniqueDir = createUniqueTempDir(tempRoot, baseName(normalizedSource));
		Sys.println("[build] createTempProject: src=" + normalizedSource + " tempRoot=" + tempRoot + " dest=" + uniqueDir);
		copyRecursive(normalizedSource, uniqueDir);
		
		if (injectFiles != null) {
			var keys:Array<String> = [];
			for (relativePath in injectFiles.keys()) {
				final content = injectFiles.get(relativePath);
				final absolutePath = Path.join([uniqueDir, relativePath]);
				ensureParentDirectory(absolutePath);
				File.saveContent(absolutePath, content);
				keys.push(relativePath);
			}
			Sys.println("[build] Injected files: " + keys.join(", "));
		}
		
		
		return uniqueDir;
	}
	
	public static function runBuild(projectDir:String):String {
		final normalizedDir = normalizeDir(projectDir);
		final hxmlPath = Path.join([normalizedDir, "build.hxml"]);
		if (!FileSystem.exists(hxmlPath)) {
			throw 'build.hxml not found in: ' + normalizedDir;
		}
		
		Sys.println("[build] runBuild: dir=" + normalizedDir + " hxml=" + hxmlPath);
		final target = parseFirstOutputTarget(hxmlPath);
		Sys.println("[build] Target detected: kind=" + target.kind + " path=" + target.path);
		final result = runHaxeBuildInDir(normalizedDir);
		Sys.println("[build] Haxe finished with code=" + result.code + " stdoutLen=" + (result.stdout != null ? result.stdout.length : 0) + " stderrLen=" + (result.stderr != null ? result.stderr.length : 0));
		if (result.code != 0) {
			final message = [
				'Haxe build failed (exit ' + result.code + ')',
				'--- stdout ---',
				result.stdout,
				'--- stderr ---',
				result.stderr
			].join("\n");
			throw message;
		}
		
		final outPath = Path.isAbsolute(target.path) ? target.path : Path.join([normalizedDir, target.path]);
		Sys.println("[build] Output path: " + outPath);
		return outPath;
	}
	
	static function parseFirstOutputTarget(hxmlPath:String):{ kind:String, path:String } {
		final content = File.getContent(hxmlPath);
		final lines = content.split("\n");
		
		for (rawLine in lines) {
			final line = rawLine.trim();
			if (line.length == 0) continue;
			if (StringTools.startsWith(line, "#")) continue;
			
			// Accept tokens of the form: -flag <value>
			final spaceIdx = line.indexOf(" ");
			final flag = spaceIdx == -1 ? line : line.substr(0, spaceIdx);
			final value = spaceIdx == -1 ? "" : line.substr(spaceIdx + 1).trim();
			
			// File-based outputs
			if (flag == "-js" || flag == "-lua" || flag == "-swf" || flag == "-hl" || flag == "-neko" || flag == "-python" || flag == "-cppia") {
				if (value == "") throw 'Missing output path for ' + flag + ' in ' + hxmlPath;
				Sys.println("[build] parse target: " + flag + " -> " + value);
				return { kind: "file", path: value };
			}
			
			// Directory-based outputs
			if (flag == "-cpp" || flag == "-cs" || flag == "-java" || flag == "-php" || flag == "-jvm" || flag == "-as3") {
				if (value == "") throw 'Missing output path for ' + flag + ' in ' + hxmlPath;
				Sys.println("[build] parse target: " + flag + " -> " + value);
				return { kind: "dir", path: value };
			}
		}
		
		throw 'No output target found in ' + hxmlPath;
	}
	
	static function runHaxeBuildInDir(projectDir:String):{ code:Int, stdout:String, stderr:String } {
		final prevCwd = Sys.getCwd();
		Sys.setCwd(projectDir);
		#if js
		final res:Dynamic = ChildProcess.spawnSync("haxe", ["build.hxml"], { encoding: "utf8" });
		Sys.setCwd(prevCwd);
		final code = res.status == null ? (res.error != null ? 1 : 0) : res.status;
		Sys.println("[build] Exit code: " + code);
		return { code: code, stdout: Std.string(res.stdout), stderr: Std.string(res.stderr) };
		#else
		final p = new Process("haxe", ["build.hxml"]);
		final out = p.stdout.readAll().toString();
		final err = p.stderr.readAll().toString();
		final code = p.exitCode();
		p.close();
		Sys.setCwd(prevCwd);
		Sys.println("[build] Exit code: " + code);
		return { code: code, stdout: out, stderr: err };
		#end
	}
	
	static function copyRecursive(source:String, destination:String):Void {
		if (!FileSystem.exists(destination)) {
			FileSystem.createDirectory(destination);
		}
		for (entry in FileSystem.readDirectory(source)) {
			final from = Path.join([source, entry]);
			final to = Path.join([destination, entry]);
			if (FileSystem.isDirectory(from)) {
				copyRecursive(from, to);
			} else {
				ensureParentDirectory(to);
				File.copy(from, to);
			}
		}
	}
	
	static function ensureParentDirectory(filePath:String):Void {
		final parent = Path.directory(filePath);
		if (parent != "" && !FileSystem.exists(parent)) {
			FileSystem.createDirectory(parent);
		}
	}
	
	static function getTempRoot():String {
		if (tempRootOverride != null && tempRootOverride != "") {
			final o = normalizeDir(tempRootOverride);
			if (!FileSystem.exists(o)) {
				FileSystem.createDirectory(o);
			}
			return o;
		}
		final isWindows = Sys.systemName() == "Windows";
		if (isWindows) {
			final t = Sys.getEnv("TEMP");
			if (t != null && t != "") return normalizeDir(t);
			final tmp = "C:\\\\Windows\\\\Temp";
			return normalizeDir(tmp);
		} else {
			final t = Sys.getEnv("TMPDIR");
			if (t != null && t != "") return normalizeDir(t);
			return normalizeDir("/tmp");
		}
	}
	
	static function createUniqueTempDir(tempRoot:String, base:String):String {
		final stamp = Std.int(Std.int(Sys.time() * 1000)) + "-" + Std.random(1000000);
		final safeBase = base == "" ? "project" : base;
		final name = safeBase + "-" + stamp;
		final dir = Path.join([tempRoot, name]);
		FileSystem.createDirectory(dir);
		return dir;
	}
	
	static function normalizeDir(path:String):String {
		final p = Path.addTrailingSlash(Path.normalize(path));
		return p;
	}
	
	static function baseName(dir:String):String {
		final withoutSlash = dir.charAt(dir.length - 1) == "/" || dir.charAt(dir.length - 1) == "\\" ? dir.substr(0, dir.length - 1) : dir;
		return Path.withoutDirectory(withoutSlash);
	}
}


